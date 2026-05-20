FROM mcr.microsoft.com/dotnet/core/aspnet:2.1-stretch-slim AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/core/sdk:2.1-stretch AS build
WORKDIR /src
# Attention à la casse (Majuscules) pour Identity.Api selon tes dossiers
COPY ["Services/Identity.Api/Identity.Api.csproj", "Services/Identity.Api/"]
COPY ["Foundation/Events/Events.csproj", "Foundation/Events/"]

RUN dotnet restore "Services/Identity.Api/Identity.Api.csproj"
COPY . .
WORKDIR "/src/Services/Identity.Api"
RUN dotnet build "Identity.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Identity.Api.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Identity.Api.dll"]