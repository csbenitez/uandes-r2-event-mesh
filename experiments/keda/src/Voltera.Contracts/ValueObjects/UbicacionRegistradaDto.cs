namespace Voltera.Contracts.ValueObjects;

/// <summary>
/// Ubicación jerárquica registrada para el medidor, complementada con coordenadas
/// para cálculos posteriores de proximidad en el bounded context de matching.
/// </summary>
public sealed record UbicacionRegistradaDto(
    string PaisCodigo,
    string DepartamentoCodigo,
    string MunicipioCodigo,
    string ZonaCodigo,
    string CodigoZona,
    decimal Latitud,
    decimal Longitud);
