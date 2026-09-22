# Despliegue de GeneraTabla en AWS EC2

Este despliegue usa una sola instancia Ubuntu para la presentación académica:

- Nginx sirve el frontend y actúa como proxy inverso.
- FastAPI escucha únicamente en `127.0.0.1:8000`.
- El backend Spring generado escucha únicamente en `127.0.0.1:8084`.
- PostgreSQL escucha únicamente en la interfaz local.
- El modelo de IA permanece en el dispositivo Android.

No se usa Docker. La instancia recomendada para ejecutar los servicios juntos
es `t3.small` con 20 GiB `gp3` y 2 GiB de swap.

## Backend CASE

El archivo privado `/etc/generatabla/case.env` debe tener permisos `0640`, ser
propiedad de `root:ubuntu` y definir:

```dotenv
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=generatabla
DB_USERNAME=generatabla_app
DB_PASSWORD=una-clave-aleatoria
```

Después de instalar los paquetes Python y ejecutar Alembic, se instala la
unidad incluida en el repositorio:

```bash
sudo install -m 644 deploy/aws/systemd/generatabla-case.service \
  /etc/systemd/system/generatabla-case.service
sudo systemctl daemon-reload
sudo systemctl enable --now generatabla-case
curl --fail http://127.0.0.1:8000/health
```

## Nginx

El frontend compilado se copia a `/var/www/generatabla`. La configuración del
proxy se instala así:

```bash
sudo install -m 644 deploy/aws/nginx/generatabla.conf \
  /etc/nginx/sites-available/generatabla
sudo ln -sfn /etc/nginx/sites-available/generatabla \
  /etc/nginx/sites-enabled/generatabla
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

Los puertos internos `5432`, `8000` y `8084` nunca deben abrirse en el grupo de
seguridad. Los puertos públicos `80` y `443` se habilitan únicamente al
configurar el acceso web; antes de la prueba pública debe agregarse HTTPS.

## Verificación

```bash
systemctl is-active generatabla-case nginx postgresql
curl --fail http://127.0.0.1:8000/health
curl --fail http://127.0.0.1/health/case
```

Los secretos, archivos `.pem` y archivos de entorno no deben copiarse al
repositorio.
