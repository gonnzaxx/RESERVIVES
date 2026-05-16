# Database Dockerfile

# Imagen
FROM postgres:16-alpine

# Copiar scripts de inicialización y seed
COPY ./database/init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY ./database/seed.sql /docker-entrypoint-initdb.d/02-seed.sql