# Dockerfile
# Usa una imagen base oficial de Python. Elige una versión específica para consistencia.
FROM python:3.13-slim

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copia solo el archivo de requerimientos primero para aprovechar el cache de Docker
COPY requirements.txt .

# Instala solo las dependencias de ejecución (Flask, Flask-WTF y Gunicorn)
# --require-hashes: solo instala las versiones exactas verificadas con su hash
# --only-binary :all: solo instala wheels, sin ejecutar scripts de instalación
# --no-cache-dir reduce el tamaño de la imagen
RUN pip install --no-cache-dir --require-hashes --only-binary :all: -r requirements.txt

# Copia el código de la aplicación (solo la carpeta app)
COPY app/ ./app/

# Crea un usuario sin privilegios y ejecuta la aplicación con él (no como root)
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Expón el puerto en el que Gunicorn servirá la aplicación
# Gunicorn por defecto usa 8000, así que usaremos ese.
EXPOSE 8000

# Comando para ejecutar la aplicación usando Gunicorn cuando el contenedor inicie
# 'app.app:app' significa: del archivo app.py dentro del paquete app, usa la instancia 'app' de Flask.
# '--preload' carga la app una sola vez antes de crear los workers, así los 4 comparten
# la misma SECRET_KEY y el token CSRF es válido sin importar qué worker atienda la petición.
# 'bind 0.0.0.0:8000' hace que Gunicorn escuche en todas las interfaces de red en el puerto 8000.
CMD ["gunicorn", "--workers=4", "--preload", "--bind=0.0.0.0:8000", "app.app:app"]
