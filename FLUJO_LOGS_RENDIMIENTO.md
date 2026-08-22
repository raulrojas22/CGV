# Flujo manual de comparación de rendimiento

Este flujo corresponde exclusivamente a los dos despliegues multiusuario
ShinyProxy de CGV:

- NAS local: `deploy-nas-shinyproxy.sh`
- Colors: `deploy-colors-shinyproxy.sh`

No se utiliza `deploy-nas.sh`, `docker-compose.yml` ni
`docker-compose.deploy.yml` para estas mediciones.

## Regla principal

La prueba **antes** y la prueba **después** deben repetir exactamente las mismas
acciones, con los mismos datos, organismos, opciones y navegador. Se evalúa una
sola optimización cada vez.

Las mediciones del NAS y Colors son independientes. Nunca se compara un log del
NAS con uno de Colors.

## 1. Captura ANTES en el NAS local

Ejecutar el despliegue real del NAS con una etiqueta exclusiva:

```bash
PERF_RUN_LABEL=antes_nas_01 ./deploy-nas-shinyproxy.sh
```

El script configura en el NAS `SP_APP_PERF_TIMING=1` y propaga la etiqueta a
cada contenedor de sesión. No es necesario modificar `.env` manualmente.

Después del despliegue:

1. Abrir una sesión nueva de CGV.
2. Ejecutar el recorrido manual elegido.
3. Esperar a que todos los gráficos terminen de cargar.
4. Cerrar la sesión.
5. Repetir el mismo recorrido en una segunda sesión nueva si se desea reducir
   el efecto de variaciones puntuales.

Los archivos persistentes quedan en el NAS:

```text
/mnt/Datos4raro/cgv/app/cache/perf_runs/antes_nas_01/
```

## 2. Captura ANTES en Colors

Ejecutar el despliegue seguro de Colors con otra etiqueta:

```bash
COLORS_PERF_TIMING=1 PERF_RUN_LABEL=antes_colors_01 ./deploy-colors-shinyproxy.sh
```

Colors conserva su configuración endurecida de ShinyProxy en el servidor. El
modo normal deja la telemetría desactivada; `COLORS_PERF_TIMING=1` habilita esta
captura de forma explícita y propaga la etiqueta y la identificación de la
imagen a las sesiones nuevas. Después se realiza el recorrido manual en
`cgv.mobilomics.org`. `./deploy-colors-shinyproxy.sh --check` muestra el valor
efectivo como `perf=0` o `perf=1`.

Los archivos quedan en Colors:

```text
/home/rarojas/cgv/app/cache/perf_runs/antes_colors_01/
```

No es necesario medir los dos servidores al mismo tiempo. Se puede comenzar
por uno y evaluar el otro más adelante.

## 3. Captura DESPUÉS

Aplicar una sola optimización y cambiar únicamente `antes` por `despues`:

```bash
PERF_RUN_LABEL=despues_nas_01 ./deploy-nas-shinyproxy.sh
```

o para Colors:

```bash
COLORS_PERF_TIMING=1 PERF_RUN_LABEL=despues_colors_01 ./deploy-colors-shinyproxy.sh
```

Repetir exactamente el recorrido utilizado en la captura ANTES del mismo
servidor.

Al terminar las capturas de Colors, volver al modo normal con un deploy sin el
override (o con `COLORS_PERF_TIMING=0` explícito):

```bash
COLORS_PERF_TIMING=0 ./deploy-colors-shinyproxy.sh
```

## 4. Qué compartir para la revisión

Compartir el par correspondiente al mismo servidor:

```text
perf_runs/antes_nas_01/
perf_runs/despues_nas_01/
```

o:

```text
perf_runs/antes_colors_01/
perf_runs/despues_colors_01/
```

También indicar:

- pasos realizados y orden exacto;
- gen o conjunto de datos utilizado;
- organismos seleccionados;
- si era la primera sesión después del despliegue;
- cualquier espera, error o comportamiento visual percibido.

### Recorrido de control Cross-Species + Alignment

Para medir esta ruta de forma reproducible:

1. seleccionar `Canis lupus familiaris`, `Equus caballus`, `Homo sapiens` y
   `Pan troglodytes`;
2. buscar exactamente `TP53`;
3. esperar a que aparezcan las cuatro visualizaciones primarias;
4. abrir **Alignment > Synteny** con **Translated CDS**;
5. esperar a que el SVG alineado y sus cuatro tracks sean visibles.

En los logs del mismo `ORTHO_SEARCH` se comparan principalmente:

- `browser_first_plot_painted_ms`: tiempo hasta el primer SVG realmente
  pintado en el navegador;
- `server_ready_to_browser_paint_ms`: transporte y render del primer SVG una
  vez preparado por el servidor;
- `search_finish_ms` y el mensaje `ALL ... CARDS RENDERED`: búsqueda y carga
  progresiva completa;
- `aligned_corr_compute_ms`: cálculo real de las correspondencias entre tracks;
- `aligned_total_ms`: generación total de la vista de synteny alineada.

La línea de correspondencias debe terminar en `schedule=in_process`. No debe
aparecer `parallel_corr_fallback`: esa línea indicaría una release anterior que
intentaba exportar los entornos de caché a workers antes de ejecutar el mismo
cálculo local.

Los logs incluyen etiqueta, fecha UTC, proceso, versión de R, imagen y variables
de rendimiento permitidas. No se guardan claves ni secretos. Aun así, pueden
aparecer nombres de genes, organismos, rutas o mensajes de error producidos por
la aplicación.

## 5. Reversión

Cada optimización debe quedar en un commit independiente y, cuando corresponda,
detrás de una variable de configuración. Si el resultado DESPUÉS empeora:

1. desactivar la variable o revertir únicamente el commit;
2. desplegar con una etiqueta como `revertido_nas_01` o
   `revertido_colors_01`;
3. repetir el mismo recorrido para confirmar la recuperación.

La instrumentación de logs permanece idéntica en ANTES, DESPUÉS y REVERTIDO.
