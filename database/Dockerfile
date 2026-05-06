FROM postgres:16-alpine

COPY ./database/init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY ./database/seed.sql /docker-entrypoint-initdb.d/02-seed.sql