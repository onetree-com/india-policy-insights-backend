#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/azure-functions/dotnet:3.0 AS base
WORKDIR /home/site/wwwroot
EXPOSE 80
RUN apt-get update
RUN apt-get install nginx -yy

FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build
WORKDIR /src
COPY ["IPI.Functions/IPI.Functions.csproj", "IPI.Functions/"]
COPY ["IPI.Core/IPI.Core.csproj", "IPI.Core/"]
COPY ["IPI.Dto/IPI.Dto.csproj", "IPI.Dto/"]
COPY ["IPI.SharedKernel/IPI.SharedKernel.csproj", "IPI.SharedKernel/"]
COPY ["IPI.Infrastructure/IPI.Infrastructure.csproj", "IPI.Infrastructure/"]
RUN dotnet restore "IPI.Functions/IPI.Functions.csproj"
COPY . .
WORKDIR "/src/IPI.Functions"
RUN dotnet build "IPI.Functions.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "IPI.Functions.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /home/site/wwwroot
COPY --from=publish /app/publish .
COPY default.conf /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/nginx.conf
ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    ASPNETCORE_URLS=http://+:5000 \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true
CMD service nginx start;/azure-functions-host/Microsoft.Azure.WebJobs.Script.WebHost