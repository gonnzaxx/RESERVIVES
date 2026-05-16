# Frontend Dockerfile

# --- Etapa 1: Build Flutter Web ---
FROM instrumentisto/flutter:3.41.5 AS build-env

WORKDIR /app

# 1. Copiar archivos de configuración primero
COPY pubspec.yaml ./

# 2. Copiar todas las carpetas necesarias
COPY lib/ lib/
COPY assets/ assets/
COPY web/ web/

# 3. Obtener dependencias
RUN flutter pub get

# 4. Eliminar tests
RUN rm -rf test

# 5. Compilar la web
RUN flutter build web --release

# --- Etapa 2: Servir con Nginx ---
FROM nginx:alpine

# Copiar build generado a Nginx
COPY --from=build-env /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
