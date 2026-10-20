namespace Voltera.Contracts.Events;

public sealed record MatchEnergeticoRechazado(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    Guid OfertaId,
    Guid DemandaId,
    string Motivo) : IEventoIntegracion;
