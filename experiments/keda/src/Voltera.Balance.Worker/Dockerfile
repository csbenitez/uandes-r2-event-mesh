FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore src/Voltera.Balance.Worker/Voltera.Balance.Worker.csproj
RUN dotnet publish src/Voltera.Balance.Worker/Voltera.Balance.Worker.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/runtime:8.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Voltera.Balance.Worker.dll"]
