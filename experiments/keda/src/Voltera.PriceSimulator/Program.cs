using Voltera.Contracts.Events;
using Voltera.Messaging;

var bootstrap = Environment.GetEnvironmentVariable("KAFKA_BOOTSTRAP_SERVERS") ?? "localhost:29092";
var count = args.Length > 0 && int.TryParse(args[0], out var parsed) ? parsed : 10;
var delayMs = args.Length > 1 && int.TryParse(args[1], out var parsedDelay) ? parsedDelay : 5000;
var random = new Random();
using var publisher = new KafkaPublisher(bootstrap);

for (var i = 1; i <= count; i++)
{
    var now = DateTimeOffset.UtcNow;
    var price = Math.Round(450m + (decimal)random.NextDouble() * 250m, 2);
    var evt = new PrecioKWhActualizado(Guid.NewGuid(), Guid.NewGuid(), now, 1, price, "COP", now, now.AddMinutes(10));
    await publisher.PublishAsync(KafkaTopics.KwhPrices, "current", evt);
    Console.WriteLine($"Precio actualizado: {price} COP/kWh");
    await Task.Delay(delayMs);
}
