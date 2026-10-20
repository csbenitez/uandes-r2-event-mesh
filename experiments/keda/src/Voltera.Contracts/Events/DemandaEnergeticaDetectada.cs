namespace Voltera.Contracts.Events;

public sealed record DemandaEnergeticaDetectada(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    Guid PosicionId,
    string ParticipanteId,
    string MedidorId,
    decimal DemandaKWh,
    string Zona,
    decimal Latitud,
    decimal Longitud,
    DateTimeOffset PeriodoDesde,
    DateTimeOffset PeriodoHasta) : IEventoIntegracion;
