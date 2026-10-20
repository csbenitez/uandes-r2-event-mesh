namespace Voltera.Contracts.ValueObjects;

/// <summary>
/// Datos del medidor que acompañan una lectura AMI.
/// El código sigue la convención: PAIS-DEPARTAMENTO-MUNICIPIO-ZONA-CONSECUTIVO.
/// Ejemplo: CO-11-001-Z03-000001.
/// </summary>
public sealed record MedidorLectura(
    string Codigo,
    string PaisCodigo,
    string DepartamentoCodigo,
    string MunicipioCodigo,
    string ZonaCodigo,
    string Consecutivo,
    string ParticipanteId);
