using Voltera.Contracts.Events;
using Voltera.Contracts.ValueObjects;
using Voltera.Messaging;

var bootstrap = Environment.GetEnvironmentVariable("KAFKA_BOOTSTRAP_SERVERS") ?? "localhost:29092";
var total = args.Length > 0 && int.TryParse(args[0], out var parsedTotal) ? parsedTotal : 20;
var delayMs = args.Length > 1 && int.TryParse(args[1], out var parsedDelay) ? parsedDelay : 250;
var random = new Random();

using var publisher = new KafkaPublisher(bootstrap);
Console.WriteLine($"AMI Simulator -> {KafkaTopics.MeterDeclarations} | total={total} delay={delayMs}ms");

for (var i = 1; i <= total; i++)
{
    var meterNumber = ((i - 1) % 20) + 1;
    var zoneNumber = ((meterNumber - 1) % 4) + 1;

    const string pais = "CO";
    const string departamento = "11";
    const string municipio = "001";
    var zona = $"Z{zoneNumber:00}";
    var consecutivo = $"{meterNumber:000000}";
    var codigoZona = $"{pais}-{departamento}-{municipio}-{zona}";
    var codigoMedidor = $"{codigoZona}-{consecutivo}";

    var medidor = new MedidorLectura(
        codigoMedidor,
        pais,
        departamento,
        municipio,
        zona,
        consecutivo,
        $"PART-{consecutivo}");

    // Coordenadas simuladas cercanas entre sí para permitir luego pruebas de proximidad.
    var ubicacion = new UbicacionRegistradaDto(
        pais,
        departamento,
        municipio,
        zona,
        codigoZona,
        4.60m + zoneNumber / 100m + meterNumber / 10000m,
        -74.08m - zoneNumber / 100m - meterNumber / 10000m);

    var consumo = Math.Round((decimal)(random.NextDouble() * 8 + 1), 3);
    var generacion = Math.Round((decimal)(random.NextDouble() * 10), 3);
    var ahora = DateTimeOffset.UtcNow;

    var evt = new LecturaMedidorRecibida(
        Guid.NewGuid(),
        Guid.NewGuid(),
        ahora,
        1,
        medidor,
        ahora,
        "kWh",
        ubicacion,
        consumo,
        generacion);

    // Key = Medidor.Codigo para preservar orden por medidor dentro de Kafka.
    await publisher.PublishAsync(KafkaTopics.MeterDeclarations, evt.Medidor.Codigo, evt);
    Console.WriteLine($"[{i}/{total}] {evt.Medidor.Codigo} consumo={consumo} generación={generacion} zona={evt.UbicacionRegistrada.CodigoZona}");

    if (delayMs > 0)
        await Task.Delay(delayMs);
}
