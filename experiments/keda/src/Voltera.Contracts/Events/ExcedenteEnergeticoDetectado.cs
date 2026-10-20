namespace Voltera.Contracts.Events;

public sealed record ExcedenteEnergeticoDetectado(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    Guid PosicionId,
    string ParticipanteId,
    string MedidorId,
    decimal ExcedenteKWh,
    string Zona,
    decimal Latitud,
    decimal Longitud,
    DateTimeOffset PeriodoDesde,
    DateTimeOffset PeriodoHasta) : IEventoIntegracion;
