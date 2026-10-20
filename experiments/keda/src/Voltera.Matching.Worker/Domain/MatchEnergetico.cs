namespace Voltera.Matching.Worker.Domain;

public sealed class MatchEnergetico
{
    public Guid MatchId { get; }
    public Guid OfertaId { get; }
    public Guid DemandaId { get; }
    public decimal KWhAsignados { get; }
    public decimal TarifaP2P { get; }
    public decimal ProximidadKm { get; }
    public DateTimeOffset VigenciaHasta { get; }
    public string Estado { get; private set; }

    private MatchEnergetico(Guid matchId, Guid ofertaId, Guid demandaId, decimal kwh, decimal tarifa,
        decimal proximidad, DateTimeOffset vigencia)
    {
        if (kwh <= 0) throw new InvalidOperationException("Un match debe asignar energía positiva.");
        MatchId = matchId;
        OfertaId = ofertaId;
        DemandaId = demandaId;
        KWhAsignados = kwh;
        TarifaP2P = tarifa;
        ProximidadKm = proximidad;
        VigenciaHasta = vigencia;
        Estado = "CONFIRMADO";
    }

    public static MatchEnergetico Confirmar(Guid matchId, Guid ofertaId, Guid demandaId, decimal kwh,
        decimal tarifa, decimal proximidad, DateTimeOffset vigencia)
        => new(matchId, ofertaId, demandaId, kwh, tarifa, proximidad, vigencia);
}
