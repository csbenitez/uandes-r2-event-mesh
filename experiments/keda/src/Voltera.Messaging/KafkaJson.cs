using System.Text.Json;
using System.Text.Json.Serialization;

namespace Voltera.Messaging;

public static class KafkaJson
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false,
        Converters = { new JsonStringEnumConverter() }
    };

    public static string Serialize<T>(T value) => JsonSerializer.Serialize(value, Options);
    public static T? Deserialize<T>(string value) => JsonSerializer.Deserialize<T>(value, Options);
}
