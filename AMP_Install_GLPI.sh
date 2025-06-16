#!/bin/bash

# Set your own values here
MYSQL_ROOT_PASSWORD='Admin@121'
DB_NAME="fhlp"

# Flags for which components to install
INSTALL_APACHE=false
INSTALL_PHP=false
INSTALL_MARIADB=false
ALL=false
PHP_VERSION="8.1"  # default version

# Check input arguments
for arg in "$@"; do
    case "$arg" in
        all) 
            ALL=true 
            ;;
        apache) 
            INSTALL_APACHE=true 
            ;;
        mariadb) 
            INSTALL_MARIADB=true 
            ;;
        php) 
            INSTALL_PHP=true 
            ;;
        php-*) 
            INSTALL_PHP=true
            PHP_VERSION="${arg#php-}"  # extract version after php-
            ;;
        *) 
            echo "❌ Invalid option: $arg"
            echo "Usage: $0 [all|apache|php|php-8.1|php-7.4|mariadb]"
            exit 1
            ;;
    esac
done

# If no specific argument is passed, install all
if [ "$ALL" = true ] || (! $INSTALL_APACHE && ! $INSTALL_PHP && ! $INSTALL_MARIADB); then
    INSTALL_APACHE=true
    INSTALL_PHP=true
    INSTALL_MARIADB=true
fi

install_apache() {
    echo "=== Installing Apache ==="
    if ! rpm -q httpd > /dev/null 2>&1; then
        yum install -y httpd
        systemctl start httpd
        systemctl enable httpd
    else
        echo "✅ Apache is already installed. Skipping."
    fi
}

configure_firewall() {
    echo "=== Configuring Firewall ==="
    firewall-cmd --permanent --zone=public --add-port=80/tcp
    firewall-cmd --permanent --zone=public --add-port=3306/tcp
    firewall-cmd --reload
}

install_php() {
    local version="${1:-8.1}"
    echo "=== Installing PHP $version and Required Modules ==="

    CURRENT_PHP=$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo "none")

    if [[ "$CURRENT_PHP" != "$version"* ]]; then
        echo "Removing old PHP packages if any..."
        dnf remove -y php\*

        echo "Installing Remi repo..."
        dnf install -y epel-release
        dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm

        echo "Resetting and enabling PHP $version module..."
        dnf module reset -y php
        dnf module enable -y php:remi-${version}

        echo "Installing PHP $version and extensions..."
        dnf install -y php php-cli php-fileinfo php-gd php-json php-mbstring \
            php-ldap php-mysqli php-mysqlnd php-session php-zlib php-simplexml \
            php-xml php-intl php-xmlrpc php-imap php-bcmath php-gmp

        echo "✅ PHP $version installation completed."
    else
        echo "✅ PHP $version is already installed. Skipping."
    fi
}

install_mariadb() {
    echo "=== Installing MariaDB Server ==="
    if ! rpm -q mariadb-server > /dev/null 2>&1; then
        yum install -y mariadb-server
        systemctl start mariadb
        systemctl enable mariadb
    else
        echo "✅ MariaDB Server is already installed. Skipping."
    fi

    echo "=== Securing MariaDB and Creating Database '${DB_NAME}' ==="
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
}

# Execution
$INSTALL_APACHE && install_apache
$INSTALL_APACHE && configure_firewall

$INSTALL_PHP && install_php "$PHP_VERSION"

$INSTALL_MARIADB && install_mariadb

echo "=== ✅ Setup Complete ==="
