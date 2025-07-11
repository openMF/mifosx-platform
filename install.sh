#!/bin/bash

echo "🔧 Checking dependencies..."
if ! command -v docker &>/dev/null; then
  echo -e "\t❌ Docker is not installed or not in PATH. Please install Docker first.\n\t\tSee https://docs.docker.com/get-docker/"
  exit 1
fi
# Check if docker compose plugin is installed
if ! docker compose version &>/dev/null; then
  echo -e "\t❌ Docker Compose is not installed or not in PATH (n.b. docker-compose is deprecated)\n\t\tUpdate docker or install docker-compose-plugin\n\t\tOn Linux: sudo apt-get install docker-compose-plugin\n\t\tSee https://docs.docker.com/compose/install/"
  exit 1
fi
# Check if docker is started
if ! docker info &>/dev/null; then
  echo -e "\t❌ Docker is not running.\n\t\tPlease start Docker Desktop, Docker or check documentation at https://docs.docker.com/config/daemon/start/"
  exit 1
fi
if ! command -v curl &>/dev/null; then
  echo -e "\t❌ Curl is not installed or not in PATH.\n\t\tOn macOS: brew install curl\n\t\tOn Linux: sudo apt install curl"
  exit 1
fi

# Check if docker compose version is >= 2
if [ "$(docker compose version --short | cut -d' ' -f3 | cut -d'.' -f1)" -lt 2 ]; then
  echo -e "\t❌ Docker Compose is outdated. Please update Docker Compose to version 2 or higher.\n\t\tSee https://docs.docker.com/compose/install/linux/"
  exit 1
fi
# Check if docker-compose is installed, if so issue a warning if version is < 2
if command -v docker-compose &>/dev/null; then
  if [ "$(docker-compose version --short | cut -d' ' -f3 | cut -d'.' -f1)" -lt 2 ]; then
    echo -e "\n\t⚠️ 'docker-compose' is installed but outdated. Make sure to use 'docker compose' or to upgrade 'docker-compose' to version 2.\n\t\tSee https://docs.docker.com/compose/install/standalone/\n"
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
  # Tail logs of the server until it's ready
  # Start logs with timeout (will automatically stop after N seconds)
  #docker compose logs -f fineract-server &
  timeout 110 docker compose logs -f fineract-server &
  pid=$!
  
  # Fixed: Use correct container name based on directory
  container_name=$(docker compose ps -q fineract-server)
  if [ -z "$container_name" ]; then
    echo "❌ Could not find fineract-server container"
    exit 1
  fi
  
  while [ "$(docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null)" != "healthy" ]; do
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