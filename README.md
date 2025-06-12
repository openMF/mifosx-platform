# Mifos X Platform Develop (LATEST) version on Docker Compose

This setup is not for production environments!

This has been tested on Linux Ubuntu 24.04 LTS. Make sure you have Docker and Docker Compose plugin installed

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

For using MariaDB:

```console
cd mariadb
docker compose pull && docker compose down && docker compose up -d && docker compose logs -d
```


For using Postgresql;

```console
cd postgresql
docker compose pull && docker compose down && docker compose up -d && docker compose logs -d
```

After the services are up and running, it could take some minutes to start for the first time, open a Web Browser and go to


https://localhost


Use the default credentials for login:

User: mifos
Password: password
