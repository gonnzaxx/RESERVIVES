<div align="center">
  <img src="https://iesluisvives.es/Design/Themes/IESluisvivies/Images/logo.png" width="200" alt="Reservives Logo" />
  <h1>RESERVIVES APP</h1>
  <p><strong>El sistema de gestión de reservas para recursos y espacios académicos.</strong></p>
  
  <p>
    <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" />
    <img src="https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
    <img src="https://img.shields.io/badge/Docker-2CA5E0?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  </p>
</div>

<hr>

## 📖 Sobre el Proyecto

**Reservives** es una aplicación diseñada para simplificar y modernizar el proceso de reserva de espacios, equipos y recursos para estudiantes y profesores del IES Luis Vives. 

## ✨ Características Principales

*   🔐 **Autenticación Segura & Microsoft OAuth**: Inicio de sesión integrado con cuentas institucionales.
*   👥 **Gestión de Roles**: Interfaces adaptativas para Estudiantes, Profesores y Administradores (Backoffice).
*   🌐 **Internacionalización (i18n)**: Soporte multi-idioma integrado desde la pantalla de bienvenida.
*   🎨 **UX/UI**: Modo oscuro automatizado, efectos de glassmorphis y skeleton loaders.
*   📋 **Panel de Administración**: Gestión y edición de usuarios, reservas y recursos.
*   🐳 **Despliegue Sencillo**: Estructurado en contenedores Docker para levantar todos los servicios con un solo comando.

## 🏗 Arquitectura y Estructura

El proyecto se divide en diferentes directorios principales:

```text
📦 RESERVIVES-APP
 ┣ 📂 backend            # API RESTFUL construida con FastAPI (Python) & SQLAlchemy
 ┣ 📂 frontend           # Interfaz de usuario construida con Flutter y Riverpod 3.x
 ┣ 📂 database           # Scripts de inicialización y migración (PostgreSQL)
 ┣ 📂 Mockups            # Recursos de diseño gráfico, logos y referencias UI
 ┗ 📜 docker-compose.yml # Orquestación de múltiples contenedores
```

## 🚀 Cómo Empezar (Getting Started)

La forma más rápida y fácil de levantar todo el ecosistema de **Reservives** (Frontend web, Backend, Database) es a través de Docker.

### Pre-requisitos
* [Docker](https://www.docker.com/get-started) y Docker Compose instalados.
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Si deseas correr la app en emuladores móbiles o desarrollar la UI localmente).
* Python 3.9+ (Para desarrollo local del backend sin Docker).

### Despliegue Rápido (Local)

1. **Clona el repositorio**
   ```bash
   git clone https://github.com/gonnzaxx/RESERVIVES-DESARROLLO.git
   cd RESERVIVES-APP
   ```

2. **Levanta los contenedores**
   La base de datos, el backend y el entorno de desarrollo web se iniciarán automáticamente.
   ```bash
   docker-compose up --build -d
   ```

3. **¡Accede a la app!**
   * **Frontend Web**: Visita `http://localhost:X` (Depende del puerto mapeado).
   * **API Docs (Swagger)**: Visita `http://localhost:8000/docs`.

### Desarrollo Local (Frontend - Flutter)

Si deseas trabajar estrictamente en la versión móvil:
```bash
cd frontend
flutter pub get
flutter run
```

## 🛠 Tecnologías Utilizadas

### Frontend (App Móvil & Web)
- **Framework**: [Flutter](https://flutter.dev/)
- **Gestor de Estado**: Riverpod 3.x (`NotifierProvider`)
- **Estilos**: Theming y Localization adaptativa.

### Backend (Servicio API)
- **Framework**: Python 3 con [FastAPI](https://fastapi.tiangolo.com/)
- **ORM**: SQLAlchemy
- **Autenticación**: AuthLib/OAuth2

### Base de Datos & Infraestructura
- **Base de datos**: PostgreSQL
- **Contenedores**: Docker Compose

## 🤝 Contribuyendo

1. Haz un Fork del proyecto
2. Crea tu Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Haz Commit a tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Haz Push al Branch (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

<div align="center">
  <i>Desarrollado con ❤️ para mejorar la gestión académica.</i>
</div>

## 👨‍💻 Autoría

Este proyecto ha sido desarrollado por:

- [Alejandro Sánchez Monzón](https://github.com/AlejandroSanchezMonzon)
- [Mireya Sánchez Pinzón](https://github.com/Mireyasanche)
- [Rubén García-Redondo Marín](https://github.com/RuyMi)

## 📚 Documentación

- [Anteproyecto](https://github.com/RuyMi/tfg-gestion-espacios/blob/main/metadata/Anteproyecto.pdf)
- [Documentación del proyecto](https://github.com/RuyMi/tfg-gestion-espacios/blob/main/Proyecto%20Desarrolo%20de%20aplicaciones_IES%20Luis%20Vives.pdf)


## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT. Consulte el archivo [LICENSE](LICENSE) para obtener más información.
