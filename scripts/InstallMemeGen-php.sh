#!/bin/bash
# Installs MemeGen. Make sure you've got privileges with the user you execute this as.

# Print each command and exit as soon as something fails.
set -e

# Make sure it's run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root! use 'sudo su -'." 
   exit 1
fi
  
  PHP_VERSION=7.4

# Set a settings for non interactive mode
  export DEBIAN_FRONTEND=noninteractive
	
# Update the server
  apt-get update -y && apt-get upgrade -y

# Install latest mongodb repo
  wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
  apt-get update -y 

# Install packages (apache, mongo, php, python and other useful packages)
  apt-get install -y apache2 composer mongodb-org mongodb-org-server php$PHP_VERSION php$PHP_VERSION-dev libapache2-mod-php$PHP_VERSION php-pear pkg-config libssl-dev libssl-dev python3-pip imagemagick wget unzip

  # Mongodb config
  pecl install mongodb
  echo "extension=mongodb.so" >> /etc/php/$PHP_VERSION/apache2/php.ini && echo "extension=mongodb.so" >> /etc/php/$PHP_VERSION/cli/php.ini

# Pip install meme creation packages and awscli for syncing s3 to local fs
	pip3 install wand awscli
	
# Enable and start services  
  # Enable
  systemctl enable mongod apache2
  # Start
  systemctl start mongod apache2
  # Wait for mongod start
  until nc -z localhost 27017
  do
      sleep 1
      echo "Waiting for MongoDB to be available..."
  done

# Configure Mongodb
  # Create mongo student root user for memegen db
  echo '
    use memegen
    db.createUser(
       {
         user: "student",
         pwd: "Cloud247",
         roles: [ { role: "root", db: "admin" } ]
       }
    )
  ' | mongo
  # Enable user credentials security
  echo "security:" >> /etc/mongod.conf && echo "  authorization: enabled" >> /etc/mongod.conf
  # Restart the mongodb service
  systemctl restart mongod
    
# Download and install MemeGen
  # Git clone the repository in your home directory (already done by student to run the script)
  # git clone https://github.com/gluobe/memegen-webapp-aws.git ~/memegen-webapp
  # Clone the application out of the repo to the web folder.
  cp -r ~/memegen-webapp/* /var/www/html/
  # Set permissions for apache
  chown -R www-data:www-data /var/www/html/meme-generator/
  
# Install aws sdk for DynamoDB
  until [ -f /var/www/html/vendor/autoload.php ]
  do
      echo "Installing AWS SDK into /var/www/html..."
      export HOME=/root
      export COMPOSER_HOME=/var/www/html
      composer -d "/var/www/html" require aws/aws-sdk-php
      sleep 2
  done
  
# Configure httpd and restart
  # Remove index.html
  rm -f /var/www/html/index.html
  # Restart httpd
  systemctl restart apache2

# Please go to http://
  echo -e "Local MemeGen installation complete."
  echo 'Local MemeGen installation complete.' | systemd-cat

