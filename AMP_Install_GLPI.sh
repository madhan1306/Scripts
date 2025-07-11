#!/bin/bash

# ===== Basic Config =====
MYSQL_ROOT_PASSWORD='Admin@121'
DB_NAME="fhlp"

INSTALL_APACHE=false
INSTALL_PHP=false
INSTALL_MARIADB=false
PHP_VERSION="8.1"

# ===== Prompt for User Selection =====
echo "========== AMP Stack Installer =========="
echo "1) Install All (Apache + PHP + MariaDB)"
echo "2) Choose components manually"
read -rp "Select an option [1-2]: " INSTALL_OPTION

if [[ "$INSTALL_OPTION" == "1" ]]; then
    INSTALL_APACHE=true
    INSTALL_PHP=true
    INSTALL_MARIADB=true
elif [[ "$INSTALL_OPTION" == "2" ]]; then
    read -rp "Install Apache? [y/n]: " ans
    [[ "$ans" == [Yy]* ]] && INSTALL_APACHE=true

    read -rp "Install PHP? [y/n]: " ans
    if [[ "$ans" == [Yy]* ]]; then
        INSTALL_PHP=true
        echo "Select PHP version:"
        echo "1) 5.6"
        echo "2) 7.4"
        echo "3) 8.1"
        echo "4) 8.2"
        read -rp "Choose PHP version [1-4]: " PHP_OPT
        case "$PHP_OPT" in
            1) PHP_VERSION="5.6" ;;
            2) PHP_VERSION="7.4" ;;
            3) PHP_VERSION="8.1" ;;
            4) PHP_VERSION="8.2" ;;
            *) echo "Invalid selection. Defaulting to 8.1"; PHP_VERSION="8.1" ;;
        esac
    fi

    read -rp "Install MariaDB? [y/n]: " ans
    [[ "$ans" == [Yy]* ]] && INSTALL_MARIADB=true
else
    echo "❌ Invalid input. Exiting."
    exit 1
fi

# ===== Functions =====

install_apache() {
    echo "=== Installing Apache ==="
    if ! rpm -q httpd >/dev/null 2>&1; then
        yum install -y httpd
        systemctl enable --now httpd
    else
        echo "✅ Apache already installed."
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
    echo "=== Installing PHP $version ==="

    echo "➡ Removing old PHP packages and repos..."
    dnf remove -y php\* >/dev/null 2>&1
    dnf remove -y remi-release epel-release >/dev/null 2>&1

    echo "➡ Installing required repositories..."
    dnf install -y epel-release
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm

    echo "➡ Resetting and enabling Remi PHP $version..."
    dnf module reset -y php
    dnf module enable -y php:remi-${version}

    echo "➡ Installing PHP $version and common extensions..."
    dnf install -y php php-cli php-fileinfo php-gd php-json php-mbstring \
        php-ldap php-mysqli php-mysqlnd php-session php-zlib php-simplexml \
        php-xml php-intl php-xmlrpc php-imap php-bcmath php-gmp

    php -v
    echo "✅ PHP $version installed successfully."
}

install_mariadb() {
    echo "=== Installing MariaDB ==="
    if ! rpm -q mariadb-server >/dev/null 2>&1; then
        yum install -y mariadb-server
        systemctl enable --now mariadb
    else
        echo "✅ MariaDB already installed."
    fi

    echo "➡ Securing MariaDB and setting up database..."
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
    echo "✅ MariaDB database '${DB_NAME}' created."
}

# ===== Execute Steps =====

$INSTALL_APACHE && install_apache
$INSTALL_APACHE && configure_firewall
$INSTALL_PHP && install_php "$PHP_VERSION"
$INSTALL_MARIADB && install_mariadb

echo "=== ✅ AMP Setup Completed ==="
