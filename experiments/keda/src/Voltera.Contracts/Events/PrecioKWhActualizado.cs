namespace Voltera.Contracts.Events;

public sealed record PrecioKWhActualizado(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    decimal PrecioKWh,
    string Moneda,
    DateTimeOffset VigenteDesde,
    DateTimeOffset VigenteHasta) : IEventoIntegracion;
