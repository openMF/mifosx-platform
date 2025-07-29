#!/bin/bash

# Function to install curl
install_curl() {
  echo "➡️ Installing curl..."
  if [[ $(uname) == "Darwin" ]]; then
    # Running on macOS
    if ! command -v brew &>/dev/null; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)"
    fi
    brew install curl
  else
    # Assuming Linux
    sudo apt-get update
    sudo apt-get install curl -y
  fi
}

# Function to install docker
install_docker(){
  echo "➡️ Installing docker..."
  # Uninstall conflicting packages
  echo "🧹 Removing conflicting Docker-related packages..."
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" 2>/dev/null || true
  done
  if [[ $(uname) == "Darwin" ]]; then
    # Running on macOS
    echo "❗ Docker Engine cannot run natively on macOS without a VM."
    echo "💡 Docker Desktop provides a full environment (Docker Engine, CLI, Compose, etc.) via a lightweight VM."
    echo "➡️ Official download page: https://docs.docker.com/desktop/install/mac/"
    
    read -p "❓ Would you like to download Docker Desktop automatically now? (Y/n) " answer
    if [ "$answer" != "n" ]; then
      echo "⬇️ Downloading Docker Desktop installer..."

      ARCH=$(uname -m)
        if [[ "$ARCH" == "arm64" ]]; then
        # Mac with Apple Silicon (M1, M2, M3)
        DMG_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-mac-arm64"
        else
        # Mac with Intel chip (x86_64 = amd64)
        DMG_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-mac-amd64"
        fi

      curl -L -o Docker.dmg "$DMG_URL" || {
        echo "❌ Failed to download Docker.dmg"
        exit 1
      }
      echo "✅ Docker.dmg has been downloaded successfully."

      echo "📦 Mounting the DMG file..."
      sudo hdiutil attach Docker.dmg || {
        echo "❌ Failed to mount Docker.dmg"
        exit 1
      }

      echo "⚙️ Installing Docker Desktop into /Applications..."
      sudo /Volumes/Docker/Docker.app/Contents/MacOS/install || {
        echo "❌ Docker installation failed"
        sudo hdiutil detach /Volumes/Docker
        exit 1
      }

      echo "🔌 Unmounting the DMG..."
      sudo hdiutil detach /Volumes/Docker || {
        echo "⚠️ Failed to unmount the volume"
      }

      echo "🚀 Launching Docker Desktop..."
      open -a Docker || {
        echo "⚠️ Could not launch Docker Desktop"
      }
      echo "🚀 Docker Desktop has been launched. If this is your first time, please authorize it manually in the pop-up or in System Preferences > Security & Privacy."

      echo "⏳ Waiting for Docker to become available..."
      while ! docker info >/dev/null 2>&1; do
        echo "⏳ Waiting for Docker to start..."
        sleep 2
      done

      echo "✅ Docker is running and ready to use."
    else
      echo "🔁 Once installed manually, start Docker Desktop and use the CLI as usual."
      exit 1
    fi
  else
    # Assuming Linux
    echo "📦 Installing Docker from official Docker repo..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates
    # Add Docker’s official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings 2>/dev/null || true
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # Set up the repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    # Install Docker packages
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    # Add user to docker group
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER" || true

    # Apply group change in current shell
    newgrp docker <<EONG
echo "✅ Docker is installed and group membership applied in this session."
EONG
  fi
}

# Funtion to install docker compose plugin
install_docker_compose(){
  echo "➡️ Installing Docker Compose plugin..."

  if [[ $(uname) == "Darwin" ]]; then
    # macOS
    if docker compose version &>/dev/null; then
      echo "✅ Docker Compose is already available on macOS (via Docker Desktop)."
    else
      echo "❌ 'docker compose' is not available. Make sure Docker Desktop is installed and running."
      exit 1
    fi
  else
    # Assuming Linux
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    echo "✅ Docker Compose plugin installed on Linux."
  fi
}

# Function to start Docker
start_docker() {
  if [[ $(uname) == "Darwin" ]]; then
    echo "🚀 Launching Docker Desktop..."
    open -a Docker || {
      echo "⚠️ Could not launch Docker Desktop"
    }
  else
    echo "🚀 Starting Docker service..."
    sudo systemctl start docker
  fi
}

# Function to Install/Update docker-compose
install_docker_stand_alone(){
  echo "⬇️ Downloading latest docker-compose version..."
  if sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
    sudo chmod +x /usr/local/bin/docker-compose
  else
    echo "❌ Failed to download docker-compose binary."
    exit 1
  fi
}

echo "🔧 Checking dependencies..."
if ! command -v curl &>/dev/null; then
  echo -e "\t❌ Curl is not installed or not in PATH.\n\t\tOn macOS: brew install curl\n\t\tOn Linux: sudo apt install curl"
  read -p "❓ Would you like to install it automatically? (Y/n) " answer
  if [ "$answer" != "n" ]; then
    install_curl
    if command -v curl &>/dev/null; then
      curl_version=$(curl --version | head -n 1 | awk '{print $2}')
      echo "✅ curl is already installed (version $curl_version)"
    else
      echo "❌ curl installation failed or still not available in PATH."
      exit 1
    fi
  else
    echo "❌ curl is required to continue. Exiting..."
    exit 1
  fi
fi
if ! command -v docker &>/dev/null; then
  echo -e "\t❌ Docker is not installed or not in PATH. Please install Docker first.\n\t\tSee https://docs.docker.com/get-docker/"
  read -p "❓ Would you like to install it automatically? (Y/n) " answer
  if [ "$answer" != "n" ]; then
    install_docker
    if command -v docker &>/dev/null; then
      docker_version=$(docker --version | head -n 1 | awk '{print $3}')
      echo "✅ Docker is now installed (version $docker_version)."
    else
      echo "❌ Docker installation failed or still not available in PATH."
      exit 1
    fi
  else
    echo "❌ Docker is required to continue. Exiting..."
    exit 1
  fi
fi


# Check if docker is started
if ! systemctl is-active --quiet docker; then
  echo -e "\t❌ Docker is not running.\n\t\tPlease start Docker Desktop, Docker or check documentation at https://docs.docker.com/config/daemon/start/"
  read -p "❓ Would you like to try starting Docker automatically? (Y/n) " answer
  if [ "$answer" != "n" ]; then
    start_docker
    
    timeout=60
    elapsed=0

    echo "⏳ Waiting for Docker to start (timeout: ${timeout}s)..."

    until docker info &>/dev/null; do
      sleep 2
      elapsed=$((elapsed + 2))
      if [ "$elapsed" -ge "$timeout" ]; then
        echo "❌ Timeout reached. Docker did not start within $timeout seconds."
        exit 1
      fi
    done
    echo "✅ Docker is now running."
  else
    echo "❌ Docker must be running to continue. Exiting..."
    exit 1
  fi
fi

# Check if docker compose plugin is installed
if ! docker compose version &>/dev/null; then
  echo -e "\t❌ Docker Compose is not installed or not in PATH (n.b. docker-compose is deprecated)\n\t\tUpdate docker or install docker-compose-plugin\n\t\tOn Linux: sudo apt-get install docker-compose-plugin\n\t\tSee https://docs.docker.com/compose/install/"
  read -p "❓ Would you like to install it automatically? (Y/n) " answer
  if [ "$answer" != "n" ]; then
    install_docker_compose
    if docker compose version &>/dev/null; then
      docker_compose_version=$(docker compose version --short 2>/dev/null || docker compose --version | awk '{print $3}')
      echo "✅ docker compose plugin is already installed (version $docker_compose_version)"
    else
      echo "❌ docker compose plugin installation failed or still not available in PATH."
      exit 1
    fi
  else
    echo "❌ docker compose plugin is required to continue. Exiting..."
    exit 1
  fi
fi

# Check if docker compose version is >= 2
compose_major_version=$(docker compose version --short | cut -d'.' -f1)
if [ "$compose_major_version" -lt 2 ]; then
  echo -e "\t❌ Docker Compose is outdated. Please update to version 2 or higher.\n\t\tSee https://docs.docker.com/compose/install/"
  read -p "❓ Would you like to update it automatically? (Y/n) " answer
  if [ "$answer" != "n" ]; then
    install_docker_compose
    compose_major_version=$(docker compose version --short | cut -d'.' -f1)
    if [ "$compose_major_version" -ge 2 ]; then
      docker_compose_version=$(docker compose version --short 2>/dev/null || docker compose --version | awk '{print $3}')
      echo "✅ Docker Compose plugin has been updated (version $docker_compose_version)."
    else
      echo "❌ Docker Compose plugin update failed or the required version is still not available."
      exit 1
    fi
  else
    echo "❌ A compatible version of Docker Compose (2.x or higher) is required to continue. Exiting..."
    exit 1
  fi
fi

# Check if docker-compose is installed, if so issue a warning if version is < 2
if ! command -v docker-compose &>/dev/null; then
  echo "⬇️ 'docker-compose' not found."
  read -p "❓ Would you like to install it automatically? (Y/n) " answer
  if [ "$answer" != "n" ]; then
    install_docker_stand_alone
    if command -v docker-compose &>/dev/null; then
      version=$(docker-compose version --short)
      echo "✅ 'docker-compose' installed successfully (version $version)."
    else
      echo "❌ Failed to install 'docker-compose'."
      exit 1
    fi
  else
    echo -e "\n\t⚠️  'docker-compose' is not installed. Some optional features may not be available."
  fi
else
  compose_legacy_version=$(docker-compose version --short)
  compose_legacy_major=$(echo "$compose_legacy_version" | cut -d'.' -f1)

  if [ "$compose_legacy_major" -lt 2 ]; then
    echo -e "\n\t⚠️  'docker-compose' is installed but outdated (version $compose_legacy_version)."
    echo -e "\t📚 See: https://docs.docker.com/compose/install/standalone/\n"

    read -p "❓ Would you like to update 'docker-compose' now? (Y/n) " answer
    if [ "$answer" != "n" ]; then
      install_docker_stand_alone
      if command -v docker-compose &>/dev/null; then
        new_version=$(docker-compose version --short)
        echo "✅ 'docker-compose' has been updated to version $new_version."
      else
        echo "❌ Failed to update 'docker-compose'."
        exit 1
      fi
    else
      echo "🔁 You can update or remove 'docker-compose' manually later."
    fi
  else
    echo "✅ 'docker-compose' standalone is already installed and up to date (version $compose_legacy_version)."
  fi
fi


# Catch errors
set -e
function on_exit {
  # $? is the exit status of the last command executed
  local exit_status=$?
  if [ $exit_status -ne 0 ]; then
    echo "❌ Something went wrong, exiting: $exit_status"
  fi
}
trap on_exit EXIT

# Use environment variables VERSION and BRANCH, with defaults if not set
version=${VERSION:-$(curl -s "https://hub.docker.com/v2/repositories/openmf/fineract/tags" | grep -o '"name":"[^"]*"' | grep -v 'latest' | cut -d'"' -f4 | sort -V | tail -n1)}
#branch=${BRANCH:-$(curl -s https://api.github.com/repos/openMF/fineract/tags | grep '"name":' | head -n 1 | cut -d '"' -f 4)}
branch="main"
echo "🚀 Using docker version $version and Github branch $branch"

dir_name="mifosx"
function ask_directory {
  read -p "📁 Enter the directory name to setup the project (default: $dir_name): " answer
  if [ -n "$answer" ]; then
    dir_name=$answer
  fi
}

ask_directory

while [ -d "$dir_name" ]; do
  read -p "🚫 Directory '$dir_name' already exists. Do you want to overwrite it? (y/N) " answer
  if [ "$answer" = "y" ]; then
    break
  else
    ask_directory
  fi
done

# Create a directory named mifosx
echo "📁 Creating directory '$dir_name'"
mkdir -p "$dir_name" && cd "$dir_name" || { echo "❌ Failed to create/access directory '$dir_name'"; exit 1; }

# Define Mifos X DB type
while true; do
  echo -e "❓ Select database type to use: \n\t1.MariaDB \n\t2.PostgreSQL"
  read -p "> " answer
  if [[ "$answer" == "1" ]]; then
    dbtype="mariadb"
    break
  elif [[ "$answer" == "2" ]]; then 
    dbtype="postgresql"
    break
  else
    echo "🚫 Invalid input. Please enter 1 or 2."
  fi
done

# Copy mifosx/packages/mifosx-docker/docker-compose.yml in it
echo -e "\t• Copying docker-compose.yml for use with $dbtype"
curl -sfLo docker-compose.yml https://raw.githubusercontent.com/openMF/mifosx-platform/$branch/$dbtype/docker-compose.yml || {
  echo "❌ Failed to download docker-compose.yml for $dbtype from branch $branch"
  exit 1
}

# Copy mifosx/packages/twenty-docker/.env.example to .env
echo -e "\t• Setting up .env file"
curl -sfLo .env https://raw.githubusercontent.com/openMF/mifosx-platform/$branch/$dbtype/fineract-db/docker/$dbtype.env || {
  echo "❌ Failed to download .env for $dbtype"
  exit 1
}

if [[ "$dbtype" == "mariadb" ]]; then
  mkdir -p fineract-db || { echo "❌ Failed to create directory fineract-db"; exit 1; }
  mkdir -p fineract-db/docker || { echo "❌ Failed to create directory fineract-db/docker"; exit 1; }
  
  # Copy mifosx/mariadb/max_connections.cnf to fineract-db/max_connections.cnf
  echo -e "\t• Copying max_connections.cnf file"
  curl -sfLo fineract-db/max_connections.cnf https://raw.githubusercontent.com/openMF/mifosx-platform/$branch/$dbtype/fineract-db/max_connections.cnf || {
    echo "❌ Failed to download max_connections.cnf for $dbtype"
    exit 1
  }

  # Copy mifosx/mariadb/server_collation.cnf to fineract-db/server_collation.cnf
  echo -e "\t• Copying server_collation.cnf file"
  curl -sfLo fineract-db/server_collation.cnf https://raw.githubusercontent.com/openMF/mifosx-platform/$branch/$dbtype/fineract-db/server_collation.cnf || {
    echo "❌ Failed to download server_collation.cnf for $dbtype"
    exit 1
  }

  # Copy mifosx/mariadb/01-databases.sql to fineract-db/docker/01-databases.sql
  echo -e "\t• Copying 01-databases.sql file"
  curl -sfLo fineract-db/docker/01-databases.sql https://raw.githubusercontent.com/openMF/mifosx-platform/$branch/$dbtype/fineract-db/docker/01-databases.sql || {
    echo "❌ Failed to download max_connections.cnf for $dbtype"
    exit 1
  }
elif [[ $dbtype == "postgresql" ]]; then
  # Copy mifosx/packages/fineract-db/docker/01-init.sh
  echo -e "\t• Setting up initialization files"
  curl -sfLo 01-init.sh https://raw.githubusercontent.com/openMF/mifosx-platform/$branch/$dbtype/fineract-db/docker/01-init.sh || {
    echo "❌ Failed to download 01-init.sh for $dbtype"
    exit 1
  }
fi

# Replace TAG=latest by TAG=<latest_release or version input>
if [[ $(uname) == "Darwin" ]]; then
  # Running on macOS
  sed -i '' "s/^TAG=.*/TAG=$version/g" .env
else
  # Assuming Linux || f the TAG variable does not exist, it will be added
  if grep -q "^TAG=" .env; then
    sed -i'' "s/^TAG=.*/TAG=$version/g" .env
  else
    echo "TAG=$version" >> .env
  fi
fi

# Generate random strings for secrets
echo "" >> .env
echo "# === Randomly generated secret ===" >> .env
echo "APP_SECRET=$(openssl rand -base64 32)" >> .env

# echo "" >> .env
# echo "PG_DATABASE_PASSWORD=$(openssl rand -hex 32)" >> .env
dbpassword=$(openssl rand -hex 32)

if [[ $(uname) == "Darwin" ]]; then
  # Running on macOS
  if [[ $dbtype == "mariadb" ]]; then
    sed -i '' "s/^MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$dbpassword/g" .env
  elif [[ $dbtype == "postgresql" ]]; then 
    sed -i '' "s/^PG_PASSWORD=.*/PG_PASSWORD=$dbpassword/g" .env
    sed -i '' "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$dbpassword/g" .env
  else
    echo "❌ Unknown database type: $dbtype"
    exit 1
  fi
  sed -i '' "s/^FINERACT_DB_PASS=.*/FINERACT_DB_PASS=$dbpassword/g" .env
else
  # Assuming Linux
  if [[ $dbtype == "mariadb" ]]; then
    sed -i'' "s/^MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$dbpassword/g" .env
    
  elif [[ $dbtype == "postgresql" ]]; then 
    sed -i'' "s/^PG_PASSWORD=.*/PG_PASSWORD=$dbpassword/g" .env
    sed -i'' "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$dbpassword/g" .env
  else
    echo "❌ Unknown database type: $dbtype"
    exit 1
  fi
  sed -i'' "s/^FINERACT_DB_PASS=.*/FINERACT_DB_PASS=$dbpassword/g" .env
fi

port=3000
webAppPort=80
# Check if command nc is available
if command -v nc &> /dev/null; then
  # Check if port 3000 is already in use, propose to change it
  while nc -zv localhost $port &>/dev/null; do
    read -p $'\n🚫 Port '"$port"' for the backend service is already in use. \nDo you want to use a different port? (Y/n) ' answer
    if [ "$answer" = "n" ]; then
      continue
    fi
    read -p "Enter a new port number: " new_port
        port=$new_port
  done
  # Check if port 80 is already in use, propose to change it
  while nc -zv localhost $webAppPort &>/dev/null; do
    read -p $'\n🚫 Port '"$webAppPort"' for the Web App service is already in use. \nDo you want to use a different port? (Y/n) ' answer
    if [ "$answer" = "n" ]; then
      continue
    fi
    read -p "Enter a new port number: " new_port
        webAppPort=$new_port
  done
fi

# Define Fineract Backend Port and Mifos Web App Port
if [[ $(uname) == "Darwin" ]]; then
  sed -i '' "s/^FINERACT_PORT=.*/FINERACT_PORT=$port/g" .env
  sed -E -i '' "s|^SERVER_URL=http://localhost:[0-9]+|SERVER_URL=http://localhost:$port|g" .env
  sed -i '' "s/^WEB_APP_PORT=.*/WEB_APP_PORT=$webAppPort/g" .env
  sed -E -i '' "s|^WEB_APP_URL=http://localhost:[0-9]+|WEB_APP_URL=http://localhost:$webAppPort|g" .env
else
  sed -i'' "s/^FINERACT_PORT=.*/FINERACT_PORT=$port/g" .env
  sed -E -i'' "s|^SERVER_URL=http://localhost:[0-9]+|SERVER_URL=http://localhost:$port|g" .env
  sed -i "s/^WEB_APP_PORT=.*/WEB_APP_PORT=$webAppPort/g" .env
  sed -E -i'' "s|^WEB_APP_URL=http://localhost:[0-9]+|WEB_APP_URL=http://localhost:$webAppPort|g" .env
fi

echo -e "\t• .env configuration completed"

# Ask user if they want to start the project
read -p "🚀 Do you want to start the project now? (Y/n) " answer
if [ "$answer" = "n" ]; then
  echo "✅ Project setup completed. Run 'docker compose up -d' to start."
  exit 0
else
  echo "🐳 Starting Docker containers..."
  docker compose up -d
  # Check if port is listening
  echo "Waiting for server to be healthy, it might take a few minutes while we initialize the database..."
  
  # Fixed: Use correct container name based on directory
  container_id=$(docker compose ps -q fineract-server)
  if [ -z "$container_id" ]; then
    echo "❌ Could not find fineract-server container"
    exit 1
  fi
  
  # Tail logs of the server until it's ready
  # Start logs with timeout (will automatically stop after N seconds)
  #docker compose logs -f fineract-server &
  docker compose logs -f fineract-server &
  log_pid=$!
  
  while [ "$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null)" != "healthy" ]; do
    sleep 1
  done
  # Kill the logs process if still running
  kill $log_pid 2>/dev/null || true
  echo ""
  echo "✅ Server is up and running"
fi

echo "✅ Setup completed successfully!"
echo "📝 Default credentials:"
echo "   User: mifos"
echo "   Password: password"

function ask_open_browser {
  read -p "🌐 Do you want to open the project in your browser? (Y/n) " answer
  if [ "$answer" = "n" ]; then
    echo "🌐 You can access the project at http://localhost:$webAppPort"
    exit 0
  fi
}

# Ask user if they want to open the project
# Running on macOS
if [[ $(uname) == "Darwin" ]]; then
  ask_open_browser
  if [ "$answer" != "n" ]; then
    open "http://localhost:$webAppPort"
  fi
# Running on Linux
elif [[ $(uname) == "Linux" ]]; then
  ask_open_browser
  if [ "$answer" != "n" ]; then
    if command -v xdg-open &> /dev/null; then
      xdg-open "http://localhost:$webAppPort"
    elif command -v gnome-open &> /dev/null; then
      gnome-open "http://localhost:$webAppPort"
    else
      echo "🌐 Please open your browser and go to http://localhost:$webAppPort"
    fi
  fi
# Running on Windows
elif [[ $(uname) == "MINGW"* ]] || [[ $(uname) == "MSYS"* ]]; then
  ask_open_browser
  if [ "$answer" != "n" ]; then
    start "http://localhost:$webAppPort"
  fi
else
  echo "🌐 Please open your browser and go to http://localhost:$webAppPort"
fi