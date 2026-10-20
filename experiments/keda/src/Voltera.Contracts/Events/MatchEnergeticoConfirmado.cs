namespace Voltera.Contracts.Events;

public sealed record MatchEnergeticoConfirmado(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    Guid MatchId,
    Guid OfertaId,
    Guid DemandaId,
    decimal KWhAsignados,
    decimal TarifaP2P,
    decimal ProximidadKm,
    DateTimeOffset VigenciaHasta,
    string Estado) : IEventoIntegracion;
