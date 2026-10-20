using Confluent.Kafka;
using Voltera.Balance.Worker.Domain;
using Voltera.Contracts.Events;
using Voltera.Messaging;

namespace Voltera.Balance.Worker;

public sealed class Worker(ILogger<Worker> logger, IConfiguration configuration) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var bootstrap = configuration["Kafka:BootstrapServers"] ?? Environment.GetEnvironmentVariable("KAFKA_BOOTSTRAP_SERVERS") ?? "localhost:29092";
        using var publisher = new KafkaPublisher(bootstrap);
        using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
        {
            BootstrapServers = bootstrap,
            GroupId = configuration["Kafka:GroupId"] ?? "energy-balance-service",
            AutoOffsetReset = AutoOffsetReset.Earliest,
            EnableAutoCommit = false
        }).Build();

        consumer.Subscribe(KafkaTopics.EnergyMeasurements);
        logger.LogInformation("Balance escuchando {Topic}", KafkaTopics.EnergyMeasurements);

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var result = consumer.Consume(stoppingToken);
                var input = KafkaJson.Deserialize<MedicionEnergeticaRegistrada>(result.Message.Value);
                if (input is null) continue;

                var balance = BalanceEnergetico.Calcular(input.ParticipanteId, input.MedidorId, input.Zona,
                    input.ConsumoKWh, input.GeneracionKWh, input.TimestampLectura);
                var positionId = DeterministicGuid.Create("position", input.MedicionId.ToString());

                if (balance.BalanceKWh > 0)
                {
                    var evt = new ExcedenteEnergeticoDetectado(
                        DeterministicGuid.Create("surplus", input.EventId.ToString()), input.CorrelationId,
                        DateTimeOffset.UtcNow, 1, positionId, input.ParticipanteId, input.MedidorId,
                        balance.BalanceKWh, input.Zona, input.Latitud, input.Longitud,
                        balance.PeriodoDesde, balance.PeriodoHasta);
                    await publisher.PublishAsync(KafkaTopics.EnergyPositions, input.ParticipanteId, evt, stoppingToken);
                    logger.LogInformation("Excedente {Kwh} kWh detectado para {Participant}", evt.ExcedenteKWh, evt.ParticipanteId);
                }
                else if (balance.BalanceKWh < 0)
                {
                    var evt = new DemandaEnergeticaDetectada(
                        DeterministicGuid.Create("demand", input.EventId.ToString()), input.CorrelationId,
                        DateTimeOffset.UtcNow, 1, positionId, input.ParticipanteId, input.MedidorId,
                        Math.Abs(balance.BalanceKWh), input.Zona, input.Latitud, input.Longitud,
                        balance.PeriodoDesde, balance.PeriodoHasta);
                    await publisher.PublishAsync(KafkaTopics.EnergyPositions, input.ParticipanteId, evt, stoppingToken);
                    logger.LogInformation("Demanda {Kwh} kWh detectada para {Participant}", evt.DemandaKWh, evt.ParticipanteId);
                }
                else
                {
                    logger.LogInformation("Balance 0 para {Participant}; no se publica posición", input.ParticipanteId);
                }

                consumer.Commit(result);
            }
        }
        catch (OperationCanceledException) { }
        finally { consumer.Close(); }
    }
}
