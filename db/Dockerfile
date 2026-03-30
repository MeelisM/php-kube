FROM mysql:8.4

COPY db/init.sh /docker-entrypoint-initdb.d/01-init.sh

RUN chmod +x /docker-entrypoint-initdb.d/01-init.sh
