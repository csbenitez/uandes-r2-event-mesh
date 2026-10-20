using Confluent.Kafka;
using Voltera.Contracts.Events;
using Voltera.Messaging;
using Voltera.Metering.Worker.Domain;

namespace Voltera.Metering.Worker;

public sealed class Worker(
    ILogger<Worker> logger,
    IConfiguration configuration) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var bootstrap =
            configuration["Kafka:BootstrapServers"]
            ?? Environment.GetEnvironmentVariable("KAFKA_BOOTSTRAP_SERVERS")
            ?? "localhost:29092";

        var groupId =
            configuration["Kafka:GroupId"]
            ?? "metering-service";

        var processingDelayMs =
            int.TryParse(
                Environment.GetEnvironmentVariable("PROCESSING_DELAY_MS"),
                out var delay)
                ? delay
                : 0;

        logger.LogInformation(
            "Processing delay configurado: {Delay} ms",
            processingDelayMs);

        using var publisher = new KafkaPublisher(bootstrap);

        using var consumer =
            new ConsumerBuilder<string, string>(
                new ConsumerConfig
                {
                    BootstrapServers = bootstrap,
                    GroupId = groupId,
                    AutoOffsetReset = AutoOffsetReset.Earliest,
                    EnableAutoCommit = false
                })
                .Build();

        consumer.Subscribe(KafkaTopics.MeterDeclarations);

        logger.LogInformation(
            "Metering escuchando {Topic} con group {Group}",
            KafkaTopics.MeterDeclarations,
            groupId);

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var result = consumer.Consume(stoppingToken);

                var input =
                    KafkaJson.Deserialize<LecturaMedidorRecibida>(
                        result.Message.Value);

                if (input is null)
                {
                    continue;
                }

                try
                {
                    var measurementId =
                        DeterministicGuid.Create(
                            "measurement",
                            input.EventId.ToString());

                    var medidor = new Medidor(
                        input.Medidor.Codigo,
                        input.Medidor.PaisCodigo,
                        input.Medidor.DepartamentoCodigo,
                        input.Medidor.MunicipioCodigo,
                        input.Medidor.ZonaCodigo,
                        input.Medidor.Consecutivo,
                        input.Medidor.ParticipanteId);

                    var ubicacion = new UbicacionRegistrada(
                        input.UbicacionRegistrada.PaisCodigo,
                        input.UbicacionRegistrada.DepartamentoCodigo,
                        input.UbicacionRegistrada.MunicipioCodigo,
                        input.UbicacionRegistrada.ZonaCodigo,
                        input.UbicacionRegistrada.CodigoZona,
                        input.UbicacionRegistrada.Latitud,
                        input.UbicacionRegistrada.Longitud);

                    var aggregate = MedicionEnergetica.Registrar(
                        measurementId,
                        medidor,
                        input.ConsumoKWh,
                        input.GeneracionKWh,
                        input.UnidadMedida,
                        input.TimestampLectura,
                        ubicacion);

                    var output = new MedicionEnergeticaRegistrada(
                        DeterministicGuid.Create(
                            "measurement-registered",
                            input.EventId.ToString()),
                        input.CorrelationId,
                        DateTimeOffset.UtcNow,
                        1,
                        aggregate.MedicionId,
                        aggregate.Medidor.Codigo,
                        aggregate.Medidor.ParticipanteId,
                        aggregate.ConsumoKWh,
                        aggregate.GeneracionKWh,
                        aggregate.UnidadMedida,
                        aggregate.Ubicacion.CodigoZona,
                        aggregate.Ubicacion.Latitud,
                        aggregate.Ubicacion.Longitud,
                        aggregate.Timestamp);

                    await publisher.PublishAsync(
                        KafkaTopics.EnergyMeasurements,
                        output.MedidorId,
                        output,
                        stoppingToken);

                    // Delay controlado únicamente para el experimento KEDA.
                    // Permite generar backlog suficiente para observar
                    // el escalamiento horizontal de Metering.Worker.
                    if (processingDelayMs > 0)
                    {
                        await Task.Delay(
                            processingDelayMs,
                            stoppingToken);
                    }

                    consumer.Commit(result);

                    logger.LogInformation(
                        "Medición {MeasurementId} registrada para {Meter} en {Zone}",
                        output.MedicionId,
                        output.MedidorId,
                        output.Zona);
                }
                catch (Exception ex)
                {
                    // Para el MVP no hacemos commit si el agregado
                    // rechaza el mensaje.
                    // Más adelante añadiremos DLQ/retry policy.
                    logger.LogError(
                        ex,
                        "Lectura inválida. Offset {Offset} no confirmado.",
                        result.Offset);

                    await Task.Delay(
                        1000,
                        stoppingToken);
                }
            }
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            consumer.Close();
        }
    }
}