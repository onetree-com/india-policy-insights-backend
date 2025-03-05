# Setup

Follow this step-by-step guide to set up and run the solution using docker. This guide assumes you are using Docker Desktop on either Windows or Linux.

---

## Prerequisites

1. **Install Docker Desktop**:
   - [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
   - [Docker Desktop for Linux](https://docs.docker.com/desktop/setup/install/linux/)
2. Ensure Docker Desktop is running and that you have sufficient permissions to execute Docker commands.
3.  **Install PostgreSQL tools**:
   - [PostgreSQL Tools](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads)

---

## Setup and Run

### Step 1: Clone the Repository

Clone the repository containing the Docker Compose file and related configurations:

```bash
git clone clone https://github.com/onetree-com/india-policy-insights-backend.git
cd src
```

### Step 2: Run the Docker Compose File

Run the `docker-compose.yml` file to start all services:

```bash
docker-compose up -d
```
This will start all the required services defined in the `docker-compose.yml` file.

### Step 3: Import PostgreSQL Dump

1. Copy the PostgreSQL dump file to your local machine.
2. When the services in docker compose are running PostgreSQL is accesible in default port 5432
3. Execute the following command to restore the dump file into the PostgreSQL database (password is defined in compose file):

   ```bash
   pg_restore -Fc  --host=localhost  --port=5432 --dbname=ipidb --username=postgres --clean {path to dump file}
   ```

   Replace:
   - `<path-to-dump-file>` with the path to the dump file.

### Step 4: Copy MBTiles to the Map Service Volume

1. Locate the MBTiles file on your local machine.
2. Identify the directory mounted as a volume for the map service in the `docker-compose.yml` file (`tiles` by default).
3. Copy the MBTiles file into the mounted volume:

   ```bash
   docker cp <path-to-mbtiles> <map-service-container-name>:/data/
   ```

   Replace:
   - `<path-to-mbtiles>` with the local path to the MBTiles file.
   - `<map-service-container-name>` with the name or ID of the map service container.

---

## Verify Setup

1. Check that all containers are running:
   ```bash
   docker ps
   ```
2. Verify the PostgreSQL database and map service are operational.
   - For PostgreSQL, connect using a database client.
   - For the map service, access the configured endpoint at http://localhost:8080. 
3. The dataexplorer should be accesible at the url: http://localhost/

---

## Troubleshooting

- **If a container fails to start, check its logs:**
  ```bash
  docker logs <container-name>
  ```
- **If requests from the frontend to the API are blocked:** Configure CORS in the docker host or add the CORS headers in default.conf file in src folder
- **Database connection failures:** Ensure that the connection string defined in environment variable **ConnectionStrings__PgsqlConnectionString** has the correct values and that the database is reachable from within docker
- **Tiles not rendering:** Ensure the volumes are correctly mounted and accessible, if the map is not displayed verify the Tileserver at http://localhost:8080, the different geographies should be included, in case there aren't verify the .mbtiles are copied to the mounted volume and are accesible
- **No indicators data:** If no data is displayed ensure the dump was correctly restored and the database contains all the tables and data required
- **Unhandled exceptions:** If API crashes or returns 500 errors check the logs with the docker logs command using the API container name
- **Slow performance:** A low performance would be mostly caused by the database, review CPU and Memory usage of the PostgreSQL instance and increase it's resources if possible


---

## Stop Services

To stop all running containers:

```bash
docker-compose down
```

