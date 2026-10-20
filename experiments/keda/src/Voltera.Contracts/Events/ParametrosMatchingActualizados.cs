namespace Voltera.Contracts.Events;

public sealed record ParametrosMatchingActualizados(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    decimal DistanciaMaximaKm,
    decimal FactorProximidad,
    decimal MargenTarifa,
    int VentanaMatchingSegundos) : IEventoIntegracion;
