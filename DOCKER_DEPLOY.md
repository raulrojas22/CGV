# Docker: empaquetado y despliegue (NAS + servidor)

CGV (Comparative Genomics Viewer) es una app Shiny en R que usa datasets grandes (`annotations/`, `genomes/`, `go_annotations/`, `data/alias_index/`).
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
   - `data/alias_index/` (índices SQLite/TSV de nombres y sinónimos)
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
   - `CGV_DATA_DIR=/volume1/docker/cgv/data`
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

`.dockerignore` excluye `annotations/`, `genomes/`, `go_annotations/`, `data/` y `cache/` para evitar builds de decenas de GB.
Si quieres una imagen totalmente autocontenida (muy pesada), tendrías que quitar esas exclusiones y cambiar la estrategia de volúmenes.

## Nota de performance (primera búsqueda)

- El prewarm de Docker ocurre contra datos montados por volumen, no durante `docker build`.
- Por eso, la optimización correcta es post-arranque (automática con `APP_PREWARM_ON_START=1` o manual con `docker exec`).
- Mantén `CGV_CACHE_DIR` persistente y evita `docker compose down -v` para conservar cachés entre reinicios.
- Para que el primer gráfico aparezca rápido sin perder contenido, conserva:
  `APP_ORTHO_SUSPEND_HIDDEN=1`, `APP_ORTHO_DEFER_SEQUENCE=0`,
  `APP_FOOTER_DEFER_SEQUENCE=0`, `APP_HOMO_UPFRONT_ISOFORMS=0` y
  `APP_ORTHO_UPFRONT_ISOFORMS=0`. No eliminan anexos, fuentes externas,
  composición de secuencia del footer ni GC por feature: solo difieren
  isoformas ocultas y reutilizan el tramo genómico cacheado para evitar lecturas
  repetidas durante la construcción del gráfico.

## Nota de performance (tráfico navegador/servidor)

CGV envía muchos widgets interactivos por la conexión viva de Shiny. Para reducir bytes sin perder funcionalidad:

- `APP_SHINY_JSON_DIGITS=12`: reduce precisión numérica JSON enviada al navegador. Usa `16` o `max` si necesitas máxima precisión.
- `APP_GIRAFE_COMPACT_SVG=1`: compacta el SVG interno de `ggiraph` antes de enviarlo por Shiny.
- `APP_GIRAFE_SVG_DECIMALS=2`: redondea coordenadas SVG a 2 decimales; los datos biológicos originales en R no se modifican.
- `APP_ALIGNED_RIBBON_POINTS=25`: controla la suavidad de las cintas curvas del alineamiento. Mantén `25` para curvas suaves; valores menores reducen bytes pero pueden verse más rectos.
- `APP_MULTIPIP_VISUAL_MERGE_FROM=350`: en MultiPIP denso, agrupa segmentos visuales cercanos por pista/categoría; mantiene tooltips resumen.
- `APP_TRANSPORT_TIMING=1`: activa medición temporal en navegador. Los logs del contenedor mostrarán bytes HTTP y volumen de mensajes Shiny/WebSocket. Déjalo en `0` para uso normal.

Si usas Nginx delante de Docker/Shiny, adapta `deploy/nginx/cgv-shiny.conf`. Activa gzip siempre; Brotli solo si tu build de Nginx incluye el módulo. En Cloudflare, mantén WebSockets activos y habilita Compression Rules/Brotli/Zstandard para respuestas HTTP comprimibles.

## Reportes interactivos compartidos

Los reportes se escriben en `${CGV_CACHE_DIR}/shared_reports` y los paquetes de
autor en `${CGV_CACHE_DIR}/reproducibility_packages`. Configuración inicial:

```dotenv
APP_SHARED_REPORTS_ENABLED=1
APP_SHARED_REPORT_MAX_MB=100
APP_SHARED_REPORT_STORAGE_GB=5
CGV_PUBLIC_BASE_URL=https://cgv.mobilomics.org
```

En ShinyProxy, Nginx monta el mismo caché como sólo lectura y sirve
`/share/<token>/index.html` sin crear otro contenedor CGV. La ruta desactiva el
access log para no registrar tokens secretos. `report-cleaner` elimina reportes
caducados cada 15 minutos y paquetes temporales después de 24 horas.
La publicación usa staging, renombrado atómico y un bloqueo compartido de cuota
entre contenedores. Al alcanzar 100 MB por reporte o 5 GB totales se rechazan
nuevas publicaciones; nunca se elimina un enlace vigente para liberar espacio.

Si usas el despliegue Shiny nativo, CGV registra `/share` como recurso estático
del propio proceso. Conserva el caché persistente y no expongas
`shared_report_metadata`, que contiene los hashes privados de revocación.
