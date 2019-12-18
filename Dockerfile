FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-buster-slim AS base
WORKDIR /app

# copy csproj and restore as distinct layers
FROM mcr.microsoft.com/dotnet/core/sdk:3.1-buster AS build
WORKDIR /src
COPY ./src ./
RUN dotnet publish testapp.csproj -c Release -o /app/publish

FROM base AS final
WORKDIR /app
#ENV MYSQL_CONNECTION="Server=siaabr-dev-dbsvr.mariadb.database.azure.com;Port=3306;Uid=typo3@siaabr-dev-dbsvr;Pwd=rYqs1JDoVCZrbeeQ;Database=typo3;SslMode=None";
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "testapp.dll"]