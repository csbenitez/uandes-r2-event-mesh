using System.Text.Json;
using Npgsql;
using StackExchange.Redis;
using Voltera.Contracts.Events;
using Voltera.Matching.Worker.Domain;
using Voltera.Messaging;

namespace Voltera.Matching.Worker;

public sealed class Worker(ILogger<Worker> logger, IConfiguration configuration) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var bootstrap = configuration["Kafka:BootstrapServers"] ?? Environment.GetEnvironmentVariable("KAFKA_BOOTSTRAP_SERVERS") ?? "localhost:29092";
        var redisConnection = configuration["Redis:Connection"] ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION") ?? "localhost:6379";
        var postgres = configuration.GetConnectionString("Postgres") ?? Environment.GetEnvironmentVariable("POSTGRES_CONNECTION") ?? "Host=localhost;Port=5432;Database=voltera;Username=voltera;Password=voltera";

        await EnsureSchemaAsync(postgres, stoppingToken);
        using var redis = await ConnectionMultiplexer.ConnectAsync(redisConnection);
        var db = redis.GetDatabase();
        using var publisher = new KafkaPublisher(bootstrap);

        logger.LogInformation("Matching engine iniciado; ventana cada 2 segundos");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await MatchOnceAsync(db, postgres, logger, stoppingToken);
                await PublishOutboxAsync(postgres, publisher, logger, stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error en ciclo de matching");
            }

            await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
        }
    }

    private static async Task MatchOnceAsync(IDatabase redis, string postgres, ILogger logger, CancellationToken ct)
    {
        var priceJson = await redis.StringGetAsync("voltera:price:current");
        if (priceJson.IsNullOrEmpty) return;
        var price = KafkaJson.Deserialize<PrecioKWhActualizado>(priceJson!)!;

        var offers = await redis.HashGetAllAsync("voltera:offers");
        var demands = await redis.HashGetAllAsync("voltera:demands");
        if (offers.Length == 0 || demands.Length == 0) return;

        foreach (var offerEntry in offers)
        {
            var offer = KafkaJson.Deserialize<ExcedenteEnergeticoDetectado>(offerEntry.Value!)!;
            var demandEntry = demands.FirstOrDefault(d =>
            {
                var demand = KafkaJson.Deserialize<DemandaEnergeticaDetectada>(d.Value!)!;
                return demand.Zona == offer.Zona && demand.ParticipanteId != offer.ParticipanteId;
            });
            if (demandEntry.Name.IsNullOrEmpty) continue;

            var demand = KafkaJson.Deserialize<DemandaEnergeticaDetectada>(demandEntry.Value!)!;
            var assigned = Math.Min(offer.ExcedenteKWh, demand.DemandaKWh);
            var proximity = HaversineKm(offer.Latitud, offer.Longitud, demand.Latitud, demand.Longitud);
            var matchId = DeterministicGuid.Create("match", offer.PosicionId.ToString(), demand.PosicionId.ToString());
            var match = MatchEnergetico.Confirmar(matchId, offer.PosicionId, demand.PosicionId, assigned,
                price.PrecioKWh, proximity, DateTimeOffset.UtcNow.AddMinutes(5));

            var inserted = await PersistMatchAndOutboxAsync(postgres, match, offer.CorrelationId, ct);
            if (!inserted)
            {
                await redis.HashDeleteAsync("voltera:offers", offerEntry.Name);
                await redis.HashDeleteAsync("voltera:demands", demandEntry.Name);
                return;
            }

            var offerRemaining = offer.ExcedenteKWh - assigned;
            var demandRemaining = demand.DemandaKWh - assigned;

            if (offerRemaining <= 0)
                await redis.HashDeleteAsync("voltera:offers", offerEntry.Name);
            else
            {
                var updated = offer with { ExcedenteKWh = offerRemaining };
                await redis.HashSetAsync("voltera:offers", offerEntry.Name, KafkaJson.Serialize(updated));
            }

            if (demandRemaining <= 0)
                await redis.HashDeleteAsync("voltera:demands", demandEntry.Name);
            else
            {
                var updated = demand with { DemandaKWh = demandRemaining };
                await redis.HashSetAsync("voltera:demands", demandEntry.Name, KafkaJson.Serialize(updated));
            }

            logger.LogInformation("Match {MatchId}: {Kwh} kWh, zona {Zone}, proximidad {Km:F2} km",
                match.MatchId, assigned, offer.Zona, proximity);
            return;
        }
    }

    private static async Task<bool> PersistMatchAndOutboxAsync(string connectionString, MatchEnergetico match, Guid correlationId, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var tx = await connection.BeginTransactionAsync(ct);

        await using var matchCmd = new NpgsqlCommand(@"
INSERT INTO matches(match_id, offer_id, demand_id, kwh_assigned, tariff_p2p, proximity_km, valid_until, status)
VALUES (@match_id, @offer_id, @demand_id, @kwh, @tariff, @proximity, @valid_until, @status)
ON CONFLICT (match_id) DO NOTHING;", connection, tx);
        matchCmd.Parameters.AddWithValue("match_id", match.MatchId);
        matchCmd.Parameters.AddWithValue("offer_id", match.OfertaId);
        matchCmd.Parameters.AddWithValue("demand_id", match.DemandaId);
        matchCmd.Parameters.AddWithValue("kwh", match.KWhAsignados);
        matchCmd.Parameters.AddWithValue("tariff", match.TarifaP2P);
        matchCmd.Parameters.AddWithValue("proximity", match.ProximidadKm);
        matchCmd.Parameters.AddWithValue("valid_until", match.VigenciaHasta.UtcDateTime);
        matchCmd.Parameters.AddWithValue("status", match.Estado);
        var rows = await matchCmd.ExecuteNonQueryAsync(ct);
        if (rows == 0)
        {
            await tx.RollbackAsync(ct);
            return false;
        }

        var evt = new MatchEnergeticoConfirmado(
            DeterministicGuid.Create("match-confirmed", match.MatchId.ToString()), correlationId,
            DateTimeOffset.UtcNow, 1, match.MatchId, match.OfertaId, match.DemandaId, match.KWhAsignados,
            match.TarifaP2P, match.ProximidadKm, match.VigenciaHasta, match.Estado);

        await using var outboxCmd = new NpgsqlCommand(@"
INSERT INTO outbox(event_id, event_type, aggregate_id, payload, created_at)
VALUES (@event_id, @event_type, @aggregate_id, CAST(@payload AS jsonb), now())
ON CONFLICT (event_id) DO NOTHING;", connection, tx);
        outboxCmd.Parameters.AddWithValue("event_id", evt.EventId);
        outboxCmd.Parameters.AddWithValue("event_type", nameof(MatchEnergeticoConfirmado));
        outboxCmd.Parameters.AddWithValue("aggregate_id", match.MatchId);
        outboxCmd.Parameters.AddWithValue("payload", KafkaJson.Serialize(evt));
        await outboxCmd.ExecuteNonQueryAsync(ct);

        await tx.CommitAsync(ct);
        return true;
    }

    private static async Task PublishOutboxAsync(string connectionString, KafkaPublisher publisher, ILogger logger, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(@"
SELECT event_id, aggregate_id, payload FROM outbox
WHERE published_at IS NULL ORDER BY created_at LIMIT 100;", connection);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        var rows = new List<(Guid EventId, Guid AggregateId, string Payload)>();
        while (await reader.ReadAsync(ct))
            rows.Add((reader.GetGuid(0), reader.GetGuid(1), reader.GetString(2)));
        await reader.CloseAsync();

        foreach (var row in rows)
        {
            var evt = KafkaJson.Deserialize<MatchEnergeticoConfirmado>(row.Payload)!;
            await publisher.PublishAsync(KafkaTopics.EnergyMatched, row.AggregateId.ToString(), evt, ct);
            await using var update = new NpgsqlCommand("UPDATE outbox SET published_at = now() WHERE event_id = @id", connection);
            update.Parameters.AddWithValue("id", row.EventId);
            await update.ExecuteNonQueryAsync(ct);
            logger.LogInformation("Outbox publicado {EventId}", row.EventId);
        }
    }

    private static async Task EnsureSchemaAsync(string connectionString, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(@"
CREATE TABLE IF NOT EXISTS matches(
    match_id uuid PRIMARY KEY,
    offer_id uuid NOT NULL,
    demand_id uuid NOT NULL,
    kwh_assigned numeric(18,6) NOT NULL,
    tariff_p2p numeric(18,6) NOT NULL,
    proximity_km numeric(18,6) NOT NULL,
    valid_until timestamptz NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS outbox(
    event_id uuid PRIMARY KEY,
    event_type varchar(200) NOT NULL,
    aggregate_id uuid NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz NULL
);", connection);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static decimal HaversineKm(decimal lat1, decimal lon1, decimal lat2, decimal lon2)
    {
        const double earthRadiusKm = 6371.0;
        var dLat = DegreesToRadians((double)(lat2 - lat1));
        var dLon = DegreesToRadians((double)(lon2 - lon1));
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(DegreesToRadians((double)lat1)) * Math.Cos(DegreesToRadians((double)lat2)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return Math.Round((decimal)(earthRadiusKm * c), 3);
    }

    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180.0;
}
