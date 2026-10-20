namespace Voltera.Balance.Worker.Domain;

public sealed class BalanceEnergetico
{
    public string ParticipanteId { get; }
    public string MedidorId { get; }
    public string Zona { get; }
    public decimal BalanceKWh { get; }
    public DateTimeOffset PeriodoDesde { get; }
    public DateTimeOffset PeriodoHasta { get; }

    private BalanceEnergetico(string participanteId, string medidorId, string zona, decimal balance,
        DateTimeOffset desde, DateTimeOffset hasta)
    {
        ParticipanteId = participanteId;
        MedidorId = medidorId;
        Zona = zona;
        BalanceKWh = balance;
        PeriodoDesde = desde;
        PeriodoHasta = hasta;
    }

    public static BalanceEnergetico Calcular(string participanteId, string medidorId, string zona,
        decimal consumoKWh, decimal generacionKWh, DateTimeOffset timestamp)
        => new(participanteId, medidorId, zona, generacionKWh - consumoKWh, timestamp, timestamp);
}
