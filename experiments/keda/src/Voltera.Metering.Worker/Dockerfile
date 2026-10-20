FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore src/Voltera.Metering.Worker/Voltera.Metering.Worker.csproj
RUN dotnet publish src/Voltera.Metering.Worker/Voltera.Metering.Worker.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/runtime:8.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Voltera.Metering.Worker.dll"]
