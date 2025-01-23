# India Policy Insights

## Overview
India Policy Insights is a .NET Core 3.1-based project that leverages Azure Functions to provide scalable and efficient backend services. The application is containerized using Docker, enabling seamless deployment across various environments. The repository also includes a Docker Compose configuration to orchestrate the application and its dependent services.

## Table of Contents
- [Features](#features)
- [Technologies Used](#technologies-used)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
  - [Running the Application](#running-the-application)
- [Project Structure](#project-structure)
- [License](#license)

## Features
- Scalable backend services with Azure Functions.
- Containerized application for consistent deployment.
- Multi-service orchestration using Docker Compose.
- Built using .NET Core 3.1 for cross-platform compatibility.

## Technologies Used
- **.NET Core 3.1**
- **C#**
- **Azure Functions**
- **Docker**
- **Docker Compose**
- **Azure Cloud Services** (Optional)

## Setup instructions 
- [Setup](setup.md)

## Quick start

### Prerequisites
Before running the application, ensure you have the following installed on your system:
- [.NET Core SDK 3.1](https://dotnet.microsoft.com/download/dotnet/3.1)
- [Docker](https://www.docker.com/get-started)
- [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local)
- MBTiles files used by the map service
- Dump with the indicators data

### Setup
1. **Clone the repository:**
   ```bash
   git clone https://github.com/onetree-com/india-policy-insights-backend.git
   cd src
   ```

### Running the Application

#### Running with Docker Compose
1. **Start the services:**
   ```bash
   docker-compose up
   ```
2. Docker Compose will set up the application and the dependent services defined in the `docker-compose.yml` file.

## Project Structure
```plaintext
india-policy-insights/
├── src/                # Application source code
  ├── Dockerfile          # Dockerfile for building the container
  ├── docker-compose.yml  # Docker Compose configuration
├── README.md           # Project documentation
```

## License
This project is licensed under the MIT License. See the [LICENSE](https://github.com/onetree-com/india-policy-insights-backend/blob/main/LICENSE) file for details.

