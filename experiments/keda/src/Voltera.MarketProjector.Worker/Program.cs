using Voltera.MarketProjector.Worker;
var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddHostedService<Worker>();
await builder.Build().RunAsync();
