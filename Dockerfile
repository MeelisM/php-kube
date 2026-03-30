FROM php:8.3-apache

RUN docker-php-ext-install pdo_mysql

WORKDIR /var/www/html

COPY app/public/ /var/www/html/
COPY app/src/ /var/www/src/
COPY docker/000-default.conf /etc/apache2/sites-available/000-default.conf

EXPOSE 80
