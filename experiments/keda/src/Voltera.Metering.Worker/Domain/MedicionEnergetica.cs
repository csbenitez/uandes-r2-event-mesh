namespace Voltera.Metering.Worker.Domain;

public sealed record Medidor(
    string Codigo,
    string PaisCodigo,
    string DepartamentoCodigo,
    string MunicipioCodigo,
    string ZonaCodigo,
    string Consecutivo,
    string ParticipanteId);

public sealed record UbicacionRegistrada(
    string PaisCodigo,
    string DepartamentoCodigo,
    string MunicipioCodigo,
    string ZonaCodigo,
    string CodigoZona,
    decimal Latitud,
    decimal Longitud);

public sealed class MedicionEnergetica
{
    public Guid MedicionId { get; }
    public Medidor Medidor { get; }
    public decimal ConsumoKWh { get; }
    public decimal GeneracionKWh { get; }
    public string UnidadMedida { get; }
    public DateTimeOffset Timestamp { get; }
    public UbicacionRegistrada Ubicacion { get; }

    private MedicionEnergetica(Guid id, Medidor medidor, decimal consumo, decimal generacion,
        string unidad, DateTimeOffset timestamp, UbicacionRegistrada ubicacion)
    {
        MedicionId = id;
        Medidor = medidor;
        ConsumoKWh = consumo;
        GeneracionKWh = generacion;
        UnidadMedida = unidad;
        Timestamp = timestamp;
        Ubicacion = ubicacion;
    }

    public static MedicionEnergetica Registrar(
        Guid id,
        Medidor medidor,
        decimal consumo,
        decimal generacion,
        string unidad,
        DateTimeOffset timestamp,
        UbicacionRegistrada ubicacion)
    {
        if (string.IsNullOrWhiteSpace(medidor.Codigo))
            throw new ArgumentException("El código del medidor es obligatorio.");

        if (consumo < 0 || generacion < 0)
            throw new ArgumentOutOfRangeException(nameof(consumo), "Consumo y generación no pueden ser negativos.");

        if (!string.Equals(unidad, "kWh", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("La unidad soportada en el MVP es kWh.");

        if (ubicacion.Latitud is < -90 or > 90 || ubicacion.Longitud is < -180 or > 180)
            throw new ArgumentException("Las coordenadas de ubicación son inválidas.");

        var codigoZonaEsperado = $"{medidor.PaisCodigo}-{medidor.DepartamentoCodigo}-{medidor.MunicipioCodigo}-{medidor.ZonaCodigo}";
        if (!string.Equals(codigoZonaEsperado, ubicacion.CodigoZona, StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException($"La zona del medidor ({codigoZonaEsperado}) no coincide con la ubicación ({ubicacion.CodigoZona}).");

        return new MedicionEnergetica(id, medidor, consumo, generacion, unidad, timestamp, ubicacion);
    }
}
