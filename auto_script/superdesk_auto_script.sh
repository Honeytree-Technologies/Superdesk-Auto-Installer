cat <<start_content
########################################################################
#                                                                      #
#               Superdesk Installation and Hardening Script            #
#                                                                      #
#                  Created by Honeytree Technologies, LLC              #
#                            www.honeytreetech.com                     #
#                                                                      #
#                      Superdesk: honeytree.social                     #
#                      Email : info@honeytreetech.com                  #
#                                                                      #
########################################################################
start_content

sleep 3

cat <<startup_warning
########################################################################
#####  THIS IS IMPORTANT, PLEASE READ CAREFULLY BEFORE SELECTING   #####
#####                                                              #####
#####   This will install Superdesk on fresh server                #####
#####                                                              #####
#####  Installing on an operating Superdesk server will wipe data  #####
#####                                                              #####
########################################################################
startup_warning

sleep 3


# Function to validate if the port number is within the specified range
validate_port() {
    local port=$1
    local excluded_ports=("80" "443" "8080", "9200", "9300" , "27017", "6379")

    if [[ $port =~ ^[0-9]+$ && $port -ge 0 && $port -le 65536 ]]; then
        for excluded_port in "${excluded_ports[@]}"; do
            if [ "$port" -eq "$excluded_port" ]; then
                return 2  # Excluded port
            fi
        done
        return 0  # Valid port number
    else
        return 1  # Invalid port number
    fi
}

while true; do
  read -p "Enter admin user name: " admin_user
  if [ -n "$admin_user" ]; then
    break
  else
    echo "Admin name cannot be empty. Please enter admin name."
  fi
done

while true; do
  read -p "Enter admin email: " admin_email
  if [ -n "$admin_email" ]; then
    break
  else
    echo "Admin email cannot be empty. Please enter admin email."
  fi
done

while true; do
  read -p "Enter admin password: " admin_password
  if [ -n "$admin_password" ]; then
    break
  else
    echo "Admin email cannot be empty. Please enter admin email."
  fi
done

while true; do
  read -p "Enter application name: " app_name
  if [ -n "$app_name" ]; then
    break
  else
    echo "Application name cannot be empty. Please enter application name."
  fi
done

while true; do
  read -p "Enter valid domain name: " domain_name
  if [ -n "$domain_name" ]; then
    break
  else
    echo "Domain cannot be empty. Please enter domain."
  fi
done


while true; do
  read -p "Enter SMTP SERVER: " smtp_server
  if [ -n "$smtp_server" ]; then
    break
  else
    echo "SMTP SERVER cannot be empty. Please enter smtp server."
  fi
done

while true; do
  read -p "Enter SMTP PORT: " smtp_port
  if [ -n "$smtp_port" ]; then

    break
  else
    echo "SMTP PORT cannot be empty. Please enter smtp port."
  fi
done

while true; do
  read -p "Enter SMTP USERNAME: " smtp_username
  if [ -n "$smtp_username" ]; then

    break
  else
    echo "SMTP USERNAME cannot be empty. Please enter smtp username."
  fi
done


while true; do
  read -p "Enter SMTP_PASSWORD: " smtp_password
  if [ -n "$smtp_password" ]; then
    break
  else
    echo "SMTP_PASSWORD cannot be empty. Please enter smtp password."
  fi
done

while true; do
  read -p "Enter SMTP FROM ADDRESS: " smtp_from_address
  if [ -n "$smtp_from_address" ]; then
    break
  else
    echo "SMTP FROM ADDRESS cannot be empty. Please enter smtp from address."
  fi
done

# Prompt the user until a valid port is entered
while true; do
  read -p "Enter a port number (1-65535, excluding 80, 443, 8080, 9200, 9300, 27017, 6379): " port
  # Validate the input
  validate_port "$port"
  case $? in
    0)
      echo "SSH  port will be: $port"
      ssh_port=$port
      break  # Exit the loop as a valid port has been entered
      ;;
    1)
      echo "Invalid port number. Please enter a valid port number between 1 and 65535."
      ;;
    2)
      echo "Invalid port number. Port $port is excluded. Please choose a different port."
      ;;
  esac
done


if docker -v &>/dev/null;then
  sudo docker rm -f $(docker ps -a -q)
fi
 
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release
if test -f /usr/share/keyrings/docker-archive-keyring.gpg; then
 sudo rm /usr/share/keyrings/docker-archive-keyring.gpg
fi
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y  docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo apt  install docker-compose -y


work_dir=~/superdesk
sudo rm -rf ${work_dir}
mkdir ${work_dir}
touch ${work_dir}/docker-compose.yml
touch ${work_dir}/.env.docker
sudo mkdir -p ${work_dir}/data/elasticsearch
sudo chown 1000:1000 ${work_dir}/data/elasticsearch


cat <<docker_content >>${work_dir}/docker-compose.yml
version: "3.2"
services:
  mongodb:
    image: mongo:4
    # env_file:
    #   - .env.docker
    networks:
      - superdesk
    volumes:
      - ./data/mongodb:/data/db
    
  redis:
    image: redis:3
    networks:
      - superdesk
    volumes:
      - ./data/redis:/data

  elastic:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.10.1
    environment:
      - discovery.type=single-node
    networks:
      - superdesk
    volumes:
      - ./data/elasticsearch:/usr/share/elasticsearch/data

  superdesk-server:
    image: sourcefabricoss/superdesk-server:latest
    depends_on:
      - redis
      - mongodb
      - elastic
    env_file:
      - .env.docker
   
    networks:
      - superdesk

  superdesk-client:
    image: sourcefabricoss/superdesk-client:latest
    environment:
      # If not hosting on localhost, change these lines
      - SUPERDESK_URL=http://localhost:8080/api
      - SUPERDESK_WS_URL=ws:http://localhost:8080/ws
      - IFRAMELY_KEY

    depends_on:
      - superdesk-server
    ports:
      - "8080:80"
    networks:
      - superdesk
networks:
    superdesk:
        driver: bridge

docker_content


cat <<docker_env >> ${work_dir}/.env.docker

APPLICATION_NAME=${app_name}
SUPERDESK_URL=http://localhost:8080/api
DEMO_DATA=1 # install demo data, set to 0 if you want clean install
WEB_CONCURRENCY=2
SUPERDESK_CLIENT_URL=http://localhost:8080
CONTENTAPI_URL=http://localhost:8080/capi
MONGO_URI=mongodb://mongodb/superdesk
CONTENTAPI_MONGO_URI=mongodb://mongodb/superdesk_capi
PUBLICAPI_MONGO_URI=mongodb://mongodb/superdesk_papi
LEGAL_ARCHIVE_URI=mongodb://mongodb/superdesk_legal
ARCHIVED_URI=mongodb://mongodb/superdesk_archive
ELASTICSEARCH_URL=http://elastic:9200
ELASTICSEARCH_INDEX=superdesk
CELERY_BROKER_URL=redis://redis:6379/1
REDIS_URL=redis://redis:6379/1
DEFAULT_TIMEZONE=Europe/Prague
SECRET_KEY=*k^&9)byk=8en9n1sg7-xj4f8wr2mh^x#t%_2=1=z@69oxt50!
MAIL_SERVER=${smtp_server}
MAIL_PORT=587
MAIL_USE_TLS=true
MAIL_USE_SSL=False
MAIL_USERNAME=${smtp_username}
MAIL_PASSWORD=${smtp_password}
MAIL_DEFAULT_SENDER=${smtp_from}
AUTH_SERVER_SHARED_SECRET=1f1d7e4dbf0c77fa6f0cadc94d06f905e08a64463853e1407ef4f6c19747c96c4816856f6866a7898cadf89d7d899af1973799c79df23b347f4fb9e4bee03053

docker_env

docker compose -f ${work_dir}/docker-compose.yml up -d
docker compose -f ${work_dir}/docker-compose.yml exec superdesk-server python manage.py users:create -u "${admin_user}" -p "${admin_password}" -e "${admin_email}" --admin
echo "Admin username:  ${admin_user}  and  password: ${admin_password}"

