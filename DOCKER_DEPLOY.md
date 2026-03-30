# Docker: empaquetado y despliegue (NAS + servidor)

CGV (Comparative Genomics Viewer) es una app Shiny en R que usa datasets grandes (`annotations/`, `genomes/`, `go_annotations/`).
La configuración incluida usa este enfoque:

- Imagen Docker con código + dependencias R.
- Datos biológicos montados como volúmenes (no embebidos en la imagen).

## 1) Requisitos previos

1. Docker Engine 24+.
2. Docker Compose plugin (`docker compose`).
3. Datos disponibles en el host donde correrá el contenedor:
   - `annotations/`
   - `genomes/`
   - `go_annotations/`
   - `cache/` (escritura)

## 2) Primer arranque local

1. Crear archivo de entorno:

```bash
cd /ruta/a/cgv
cp .env.example .env
```

2. Editar `.env` si quieres rutas absolutas o puerto distinto.
   Para reducir la latencia de la primera búsqueda, puedes activar:
   - `APP_PREWARM_ON_START=1`
   - `APP_PREWARM_CLEAN=0`

3. Construir imagen:

```bash
docker compose build
```

4. Levantar contenedor:

```bash
docker compose up -d
```

5. Ver logs:

```bash
docker compose logs -f
```

6. Abrir la app:
   - `http://localhost:3838`

### Warm-up manual (opcional)

Si ya levantaste el contenedor y quieres precomputar índices/caché sin reiniciar:

```bash
docker exec -it cgv Rscript /app/scripts/precompute_preloaded_cache.R --root=/app
```

Esto llena `cache/annotation_index/` (persistente si está montado como volumen).

## 3) Despliegue en NAS (recomendado)

### Opción A: construir directamente en NAS

1. Copiar carpeta del proyecto (sin datasets pesados embebidos) al NAS.
2. Copiar/sincronizar datasets al NAS.
3. Configurar `.env` en NAS con rutas reales, por ejemplo:
   - `CGV_ANNOTATIONS_DIR=/volume1/docker/cgv/annotations`
   - `CGV_GENOMES_DIR=/volume1/docker/cgv/genomes`
   - `CGV_GO_ANNOTATIONS_DIR=/volume1/docker/cgv/go_annotations`
   - `CGV_CACHE_DIR=/volume1/docker/cgv/cache`
4. Ejecutar:

```bash
docker compose build
docker compose -f docker-compose.deploy.yml up -d
```

### Opción B: construir local y subir imagen al NAS

1. Construir local:

```bash
docker compose build
```

2. Exportar imagen:

```bash
docker save cgv:1.0.0 -o cgv_1.0.0.tar
```

3. Copiar `cgv_1.0.0.tar` al NAS.
4. Importar en NAS:

```bash
docker load -i cgv_1.0.0.tar
```

5. En NAS, ajustar `.env` y levantar:

```bash
docker compose -f docker-compose.deploy.yml up -d
```

## 4) Despliegue en servidor de trabajo

1. Repetir el mismo flujo que en NAS (opción A o B).
2. Cambiar `.env` para rutas y puerto del servidor.
3. Levantar con:

```bash
docker compose -f docker-compose.deploy.yml up -d
```

4. Verificar:

```bash
docker ps
docker logs -f cgv
curl -I http://127.0.0.1:${CGV_PORT:-3838}
```

## 5) Actualizaciones de versión

1. Cambiar tag en `.env` (`CGV_IMAGE=cgv:1.0.1`).
2. Construir nueva imagen (o cargar nueva tar).
3. Re-crear contenedor:

```bash
docker compose -f docker-compose.deploy.yml up -d
```

## 6) Parada y limpieza

```bash
docker compose -f docker-compose.deploy.yml down
```

Para borrar imagen local:

```bash
docker image rm cgv:1.0.0
```

## Nota importante sobre tamaño de imagen

`.dockerignore` excluye `annotations/`, `genomes/`, `go_annotations/` y `cache/` para evitar builds de decenas de GB.
Si quieres una imagen totalmente autocontenida (muy pesada), tendrías que quitar esas exclusiones y cambiar la estrategia de volúmenes.

## Nota de performance (primera búsqueda)

- El prewarm de Docker ocurre contra datos montados por volumen, no durante `docker build`.
- Por eso, la optimización correcta es post-arranque (automática con `APP_PREWARM_ON_START=1` o manual con `docker exec`).
- Mantén `CGV_CACHE_DIR` persistente y evita `docker compose down -v` para conservar cachés entre reinicios.
