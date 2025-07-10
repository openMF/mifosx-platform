# Mifos X Platform Develop (LATEST) version on Docker Compose

This setup is not for production environments!

This has been tested on Linux Ubuntu 24.04 LTS. Make sure you have Docker and Docker Compose plugin installed

## Quick Start

### Automated Installation (Recommended)
```console
bash <(curl -sL https://raw.githubusercontent.com/openMF/mifosx-platform/main/install.sh)
```

### Manual Installation

#### For MariaDB:
```console
cd mariadb
docker compose pull && docker compose down && docker compose up -d && docker compose logs -d
```

#### For PostgreSQL:
```console
cd postgresql
docker compose pull && docker compose down && docker compose up -d && docker compose logs -d
```

## Access

After the services are up and running (it could take some minutes for the first time), open a Web Browser and go to:

**https://localhost**

### Default Credentials:
- **User**: `mifos`
- **Password**: `password`

## Platform-Specific Notes

**Note for Mac Users with ARM Processor:**  
If you are using a Mac with an Apple Silicon (ARM) processor, you will need to add the following line to your `docker-compose.yml` file. 
Add the following line under the `fineract-server` and `web-app` services.

Example:
```yaml
services:
  web-app:
    image: openmf/web-app:dev
    platform: linux/x86_64/v8
    ...

  fineract-server:
    image: openmf/fineract:develop
    platform: linux/x86_64/v8
    ...
```
