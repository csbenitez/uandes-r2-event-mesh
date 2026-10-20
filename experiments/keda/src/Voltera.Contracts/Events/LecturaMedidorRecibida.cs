using Voltera.Contracts.ValueObjects;

namespace Voltera.Contracts.Events;

/// <summary>
/// Evento de integración de entrada desde el AMI.
/// Los metadatos técnicos están separados de los 6 datos de negocio del BC Medición.
/// </summary>
public sealed record LecturaMedidorRecibida(
    Guid EventId,
    Guid CorrelationId,
    DateTimeOffset OcurridoEnUtc,
    int SchemaVersion,
    MedidorLectura Medidor,
    DateTimeOffset TimestampLectura,
    string UnidadMedida,
    UbicacionRegistradaDto UbicacionRegistrada,
    decimal ConsumoKWh,
    decimal GeneracionKWh) : IEventoIntegracion;
