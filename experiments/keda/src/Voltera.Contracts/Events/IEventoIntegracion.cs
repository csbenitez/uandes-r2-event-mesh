namespace Voltera.Contracts.Events;

public interface IEventoIntegracion
{
    Guid EventId { get; }
    Guid CorrelationId { get; }
    DateTimeOffset OcurridoEnUtc { get; }
    int SchemaVersion { get; }
}
