# Mifos X Platform Develop (LATEST) version on Kubernetes

This setup is not for production environments! It doesn't have data persistence.

This has been tested on Linux Ubuntu 24.04 LTS. Make sure you have MicroK8s installed

## Quick Start

### Manual Installation

#### For starting the Mifos X with MariaDB:
```console
git clone https://github.com/openMF/mifosx-platform.git
cd mifosx-platform/kubernetes/mariadb
./startup.sh
```

#### For stopping the Mifos X with MariaDB:
```console
cd mifosx-platform/kubernetes/mariadb
./shutdown.sh
```

#### For starting the Mifos X with Postgresql:
```console
git clone https://github.com/openMF/mifosx-platform.git
cd mifosx-platform/kubernetes/postgresql
./startup.sh
```

#### For stopping the Mifos X with Postgresql:
```console
cd mifosx-platform/kubernetes/postgresql
./shutdown.sh
```

## Access
Before accesing the Mifos X admin UI you have to add the following records on your /etc/hosts file
```console
<YOUR_KUBERNETES_SERVER_IP>   webapp.mifos.local fineract.mifos.local
```

After the services are up and running (it could take some minutes for the first time), open a Web Browser and go to:

**https://webapp.mifos.local** For the front end Mifos X application
**https://fineract.mifos.local** for the back end service 

Important note!: Because it uses self signed certificates, you must ignore the "non secure" warning and accept the "unsecure" navigation.

### Default Credentials:
- **User**: `mifos`
- **Password**: `password`

