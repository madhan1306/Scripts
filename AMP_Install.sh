#!/bin/bash

# ===== Basic Config =====
MYSQL_ROOT_PASSWORD='Admin@121'

INSTALL_APACHE=false
INSTALL_PHP=false
INSTALL_MARIADB=false
PHP_VERSION=""

# ===== Parse Command-Line Arguments =====
if [ "$#" -eq 0 ]; then
    # No arguments → install all
    INSTALL_APACHE=true
    INSTALL_PHP=true
    INSTALL_MARIADB=true
else
    for arg in "$@"; do
        case "$arg" in
            all)
                INSTALL_APACHE=true
                INSTALL_PHP=true
                INSTALL_MARIADB=true
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
            *)
                echo "❌ Invalid option: $arg"
                echo "Usage: $0 [all|apache|php|mariadb]"
                exit 1
                ;;
        esac
    done
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

prompt_php_version() {
    echo "=== Select PHP version to install ==="
    select opt in "5.6" "7.4" "8.1" "8.2"; do
        case $opt in
            "5.6") PHP_VERSION="5.6"; break ;;
            "7.4") PHP_VERSION="7.4"; break ;;
            "8.1") PHP_VERSION="8.1"; break ;;
            "8.2") PHP_VERSION="8.2"; break ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done
}

install_php() {
    if [ -z "$PHP_VERSION" ]; then
        prompt_php_version
    fi

    echo "=== Installing PHP $PHP_VERSION ==="

    echo "➡ Removing old PHP packages and repos..."
    dnf remove -y php\* >/dev/null 2>&1
    dnf remove -y remi-release epel-release >/dev/null 2>&1

    echo "➡ Installing required repositories..."
    dnf install -y epel-release
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm

    echo "➡ Resetting and enabling Remi PHP $PHP_VERSION..."
    dnf module reset -y php
    dnf module enable -y php:remi-${PHP_VERSION}

    echo "➡ Installing PHP $PHP_VERSION and extensions..."
    dnf install -y php php-cli php-fileinfo php-gd php-json php-mbstring \
        php-ldap php-mysqli php-mysqlnd php-session php-zlib php-simplexml \
        php-xml php-intl php-xmlrpc php-imap php-bcmath php-gmp

    php -v
    echo "✅ PHP $PHP_VERSION installed successfully."
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
}

# ===== Execute Components =====

$INSTALL_APACHE && install_apache
$INSTALL_APACHE && configure_firewall
$INSTALL_PHP && install_php
$INSTALL_MARIADB && install_mariadb

echo "=== ✅ AMP Stack Installation Completed ==="
