#!/bin/bash
set -euo pipefail

DB_NAME="${MYSQL_DATABASE:-${DB_NAME:-php_kube}}"

cat <<SQL | mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}"
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE \`${DB_NAME}\`;

CREATE TABLE IF NOT EXISTS items (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
SQL
