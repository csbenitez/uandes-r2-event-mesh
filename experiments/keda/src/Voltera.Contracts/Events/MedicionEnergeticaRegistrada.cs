namespace Voltera.Contracts.Events;

public sealed record MedicionEnergeticaRegistrada(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    Guid MedicionId,
    string MedidorId,
    string ParticipanteId,
    decimal ConsumoKWh,
    decimal GeneracionKWh,
    string UnidadMedida,
    string Zona,
    decimal Latitud,
    decimal Longitud,
    DateTimeOffset TimestampLectura) : IEventoIntegracion;
