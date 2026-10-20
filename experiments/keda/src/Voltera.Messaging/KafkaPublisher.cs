using Confluent.Kafka;

namespace Voltera.Messaging;

public sealed class KafkaPublisher : IDisposable
{
    private readonly IProducer<string, string> _producer;

    public KafkaPublisher(string bootstrapServers)
    {
        _producer = new ProducerBuilder<string, string>(new ProducerConfig
        {
            BootstrapServers = bootstrapServers,
            Acks = Acks.All,
            EnableIdempotence = true,
            MessageSendMaxRetries = 10,
            RetryBackoffMs = 250
        }).Build();
    }

    public async Task PublishAsync<T>(string topic, string key, T payload, CancellationToken cancellationToken = default)
    {
        var message = new Message<string, string>
        {
            Key = key,
            Value = KafkaJson.Serialize(payload)
        };

        await _producer.ProduceAsync(topic, message, cancellationToken);
    }

    public void Dispose() => _producer.Dispose();
}
