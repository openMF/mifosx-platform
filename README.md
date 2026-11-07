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

## Install on Kubernetes with an AI agent

[`.agents/skills/mifosx-kubernetes/SKILL.md`](.agents/skills/mifosx-kubernetes/SKILL.md) is an
[Agent Skill](https://agentskills.io) that installs Mifos X on a Kubernetes cluster with the manifests in
[`kubernetes/`](kubernetes/README.md), waits until it is ready, and checks the install with API calls.
It also covers uninstalling and common failures. You need `kubectl` (or `microk8s kubectl`) pointed at
a running cluster.

Clone the repository and run your agent from its root directory:

```console
git clone https://github.com/openMF/mifosx-platform.git
cd mifosx-platform
```

| Agent | Setup |
|---|---|
| OpenCode | None. OpenCode loads skills from `.agents/skills/` |
| Codex | None. Codex loads skills from `.agents/skills/` |
| Pi Agent | None. Pi loads skills from `.agents/skills/` once you trust the project |
| Claude Code | `mkdir -p .claude/skills && ln -s ../../.agents/skills/mifosx-kubernetes .claude/skills/` |
| Hermes Agent | `mkdir -p ~/.hermes/skills/devops && cp -r .agents/skills/mifosx-kubernetes ~/.hermes/skills/devops/` |

Then ask the agent, for example: *"Install Mifos X on my Kubernetes cluster with PostgreSQL"*, or
*"Uninstall Mifos X from Kubernetes"*.

The agent runs `kubectl` and two scripts from the skill's `scripts/` directory:
`create-db-secret.sh`, which creates the database password without showing it, and
`verify-install.sh`, which runs the checks. Approve those when the agent asks. If the agent can't
run `create-db-secret.sh`, it should stop; don't let it create the password another way.
