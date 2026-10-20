using Confluent.Kafka;
using StackExchange.Redis;
using Voltera.Contracts.Events;
using Voltera.Messaging;

namespace Voltera.MarketProjector.Worker;

public sealed class Worker(ILogger<Worker> logger, IConfiguration configuration) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var bootstrap = configuration["Kafka:BootstrapServers"] ?? Environment.GetEnvironmentVariable("KAFKA_BOOTSTRAP_SERVERS") ?? "localhost:29092";
        var redisConnection = configuration["Redis:Connection"] ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION") ?? "localhost:6379";
        using var redis = await ConnectionMultiplexer.ConnectAsync(redisConnection);
        var db = redis.GetDatabase();

        using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
        {
            BootstrapServers = bootstrap,
            GroupId = configuration["Kafka:GroupId"] ?? "market-projector",
            AutoOffsetReset = AutoOffsetReset.Earliest,
            EnableAutoCommit = false
        }).Build();

        consumer.Subscribe([KafkaTopics.EnergyPositions, KafkaTopics.KwhPrices]);
        logger.LogInformation("Projector escuchando energy-positions y kwh-prices");

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var result = consumer.Consume(stoppingToken);

                if (result.Topic == KafkaTopics.KwhPrices)
                {
                    var price = KafkaJson.Deserialize<PrecioKWhActualizado>(result.Message.Value);
                    if (price is not null)
                    {
                        await db.StringSetAsync("voltera:price:current", KafkaJson.Serialize(price), price.VigenteHasta - DateTimeOffset.UtcNow);
                        logger.LogInformation("Read model precio = {Price}", price.PrecioKWh);
                    }
                }
                else
                {
                    using var doc = System.Text.Json.JsonDocument.Parse(result.Message.Value);
                    var root = doc.RootElement;
                    if (!root.TryGetProperty("eventId", out var eventIdProp)) { consumer.Commit(result); continue; }
                    var eventId = eventIdProp.GetGuid();
                    if (!await db.SetAddAsync("voltera:processed-events", eventId.ToString()))
                    {
                        consumer.Commit(result);
                        continue;
                    }

                    if (root.TryGetProperty("excedenteKWh", out _))
                    {
                        var evt = KafkaJson.Deserialize<ExcedenteEnergeticoDetectado>(result.Message.Value)!;
                        await db.HashSetAsync("voltera:offers", evt.PosicionId.ToString(), result.Message.Value);
                        logger.LogInformation("Oferta proyectada {Id} {Kwh} kWh", evt.PosicionId, evt.ExcedenteKWh);
                    }
                    else if (root.TryGetProperty("demandaKWh", out _))
                    {
                        var evt = KafkaJson.Deserialize<DemandaEnergeticaDetectada>(result.Message.Value)!;
                        await db.HashSetAsync("voltera:demands", evt.PosicionId.ToString(), result.Message.Value);
                        logger.LogInformation("Demanda proyectada {Id} {Kwh} kWh", evt.PosicionId, evt.DemandaKWh);
                    }
                }

                consumer.Commit(result);
            }
        }
        catch (OperationCanceledException) { }
        finally { consumer.Close(); }
    }
}
