# Informe técnico: oportunidades de optimización de CGV

**Fecha:** 2026-07-31
**Alcance:** tiempos de carga, búsqueda, renderizado de gráficos, alineamientos LASTZ y generación de reportes.
**Método:** análisis estático del código fuente (sin modificaciones). Todas las referencias a archivos/líneas corresponden al estado actual del repositorio.

---

## 1. Resumen ejecutivo

CGV ya tiene una base de ingeniería mejor de lo habitual en aplicaciones Shiny: carga perezosa de datos vía tabix/2bit/SQLite, cachés LRU acotadas en bytes, workers asíncronos con `future`/`promises` y guardrails de muestreo en los gráficos más densos. Es decir, **no hay que rehacer la arquitectura; hay que cerrar brechas concretas**.

Los mayores problemas de experiencia de usuario detectados, ordenados por impacto:

1. **Alineamientos LASTZ con paralelismo efectivo de 1 en producción** (`APP_LASTZ_WORKERS=1` en `.env` y `docker-compose.yml`) y tres flujos que aún bloquean la sesión (suggest-reference, modo homo, fase LASTZ de reportes). Un suggest con 6 organismos lanza ~30 procesos lastz secuenciales en el hilo principal.
2. **Los resultados de LASTZ no sobreviven a la sesión**: la caché es solo en memoria; cada sesión nueva (cada contenedor ShinyProxy) repite alineamientos idénticos.
3. **Renderizado síncrono de gráficos pesados**: el plot de sintenia alineada extrae secuencias FASTA y alinea dentro del propio `renderGirafe`; el cambio de tema re-renderiza todos los plots visibles a la vez.
4. **Arranque en frío costoso**: el índice "gene light" de cada anotación se construye parseando el GFF completo la primera vez (humano: 109 MB gz) si no existe en `cache/annotation_index/`.
5. **Riesgo de memoria en ShinyProxy**: los límites de las cachés en memoria (GFF hasta 900 MB + índice de genes hasta 1200 MB) pueden exceder la cuota de 2 GB por contenedor si varias cachés se llenan simultáneamente.

La mayoría de las mejoras de mayor impacto son **cambios de configuración o refactorings acotados**, no reescrituras.

---

## 2. Estado actual en cifras

| Aspecto | Valor |
|---|---|
| `server.R` | 35.013 líneas, 1,7 MB, una sola función servidor |
| Reactivos por sesión | 136 `reactiveVal` + 1 `reactiveValues`, 54 `reactive`, 110 `observeEvent` |
| Outputs gráficos | 23 `renderGirafe` (ggiraph/ggplot2), 1 `renderVisNetwork`, 2 `renderDataTable` |
| Tareas asíncronas | 15 `future_promise` (plan multisession, 2 workers por defecto) |
| Datos en runtime | ~16 GB: genomas 2bit (8 GB), alias SQLite (6,1 GB), GO (1 GB), anotaciones GFF (586 MB) |
| Caché en disco | 295 MB (200 MB en `shared_reports`, 94 MB en `annotation_index`) |
| Caché en memoria | ~30 entornos LRU propios con límites por entradas y bytes; **sin `bindCache` ni `memoise`** |
| Despliegue | Docker + ShinyProxy (1 contenedor/sesión, 2 GB RAM, lifetime 120 min, máx. 5-10 instancias) |

---

## 3. Tiempos de carga

### Diagnóstico

- La carga perezosa está bien resuelta: genomas 2bit por región (`rtracklayer::TwoBitFile`), anotaciones por tabix (`Rsamtools::scanTabix`), alias por SQLite. Al arrancar solo se leen los `registry.tsv`.
- **Cuello frío n.º 1:** la primera búsqueda sobre una anotación sin índice en disco dispara `build_gff_gene_light_index` (`R/utils.R:2779`), que re-streama el GFF completo con parsing línea a línea (`strsplit` + `lapply`, `R/utils.R:2676`). En GRCh38 esto son decenas de segundos de bloqueo por organismo.
- **Cuello frío n.º 2 (ShinyProxy):** cada sesión arranca un contenedor nuevo. El arranque de R carga 19 paquetes en `global.R` (varios Bioconductor pesados) y compila/verifica assets. Ese tiempo lo paga cada usuario nuevo.
- El cache warming existe (`R/server_cache_warm.R`) pero viene desactivado por defecto (`APP_PREWARM_ON_START=0`).
- La telemetría de tiempos existe (`app_perf_mark`) pero está desactivada (`APP_PERF_TIMING=0`) y no persiste.

### Propuestas viables

| # | Propuesta | Impacto | Esfuerzo |
|---|---|---|---|
| 3.1 | **Precalcular los índices de anotación en build-time**: generar `cache/annotation_index/*.rds` para todos los organismos durante la construcción de la imagen Docker o con un script de despliegue, y versionarlos junto a los GFF. Convierte el peor caso de primera búsqueda en una lectura de RDS de milisegundos. | Alto | Bajo |
| 3.2 | **Activar el pre-warm selectivo** (`APP_PREWARM_ON_START=1` limitado a los organismos más usados) y el prewarm de workers que ya existe para búsquedas y renderer. El coste lo paga el arranque del contenedor, no el primer clic del usuario. | Medio-Alto | Muy bajo |
| 3.3 | **Reducir el tiempo de arranque del contenedor**: pasar de `library()` directo a carga diferida (`requireNamespace` ya se usa en `R/`) para los paquetes no necesarios en la primera pantalla; medir el aporte de cada paquete al tiempo de `global.R`. | Medio | Medio |
| 3.4 | **Encender la telemetría existente en staging** (`APP_PERF_TIMING=1`) y volcar las marcas a `logs/` para saber dónde se van realmente los segundos antes de seguir optimizando. | Habilitador | Muy bajo |
| 3.5 | Revisar el peso del CSS compilado desde `custom.scss` (~477 KB fuente) y servir assets estáticos con caché de larga duración en nginx (el versionado `app_asset_version` ya facilita el cache-busting). | Bajo-Medio | Bajo |

---

## 4. Búsqueda

### Diagnóstico

- La búsqueda local usa índices hash construidos desde el GFF (`build_gene_lookup_maps`, `R/utils.R:2760`) con caché en memoria y disco, y resolución de alias en SQLite por organismo (`R/alias_resolution.R`). El autocompletado es incremental con presupuesto de tiempo (180k líneas / 0,45 s) y workers de fondo: es de lo mejor diseñado de la app.
- **Peor caso real:** el fallback `search_gene_rows_via_bridge_descriptions` (`R/utils.R:2638-2657`) aplica regex sobre el vector completo de atributos por cada gen consultado — O(n×m) sobre ~60k genes en humano cuando el lookup hash falla.
- El parsing inicial del GFF usa `strsplit` línea a línea en R puro; `vroom` solo se usa en una ruta (`load_gff_cached`, `R/utils.R:4267`).
- Solo hay **1 debounce en toda la aplicación** (`server.R:15905`); los inputs de texto y umbrales disparan reactividad por cada pulsación/cambio.

### Propuestas viables

| # | Propuesta | Impacto | Esfuerzo |
|---|---|---|---|
| 4.1 | **Eliminar el fallback regex full-scan**: precalcular los tokens "bridge"/descripción durante la construcción del índice (mismo paso que `build_gene_lookup_maps`), o moverlos a la tabla SQLite de alias ya existente con índice FTS5. Convierte el peor caso en una consulta indexada. | Alto | Medio |
| 4.2 | **Usar `vroom`/`data.table::fread` en la construcción del índice** (`stream_gff_gene_rows` / `parse_gff_lines_to_df`). Solo afecta al caso de caché fría, pero combinado con 3.1 desaparece como problema. | Medio | Bajo |
| 4.3 | **Añadir debounce (300-500 ms)** a los campos de búsqueda textual y sliders de umbral que hoy invalidan en cada evento. Patrón ya usado una vez; es replicable. | Medio | Muy bajo |
| 4.4 | Verificar que `warm_alias_index` (`R/alias_resolution.R:954`) se invoca en el arranque vía `server_cache_warm.R` para los genomas incluidos; si no, conectarlo al pre-warm de 3.2. | Medio | Muy bajo |
| 4.5 | A medio plazo, consolidar índices de genes en SQLite/DuckDB por organismo en lugar de RDS + hash en memoria: reduce huella por sesión y habilita FTS5 para búsqueda aproximada sin APIs externas. | Medio | Alto |

---

## 5. Renderizado de gráficos

### Diagnóstico

- Todos los gráficos son ggiraph (SVG interactivo) construidos **síncronamente en el hilo principal**. Ningún `future_promise` se usa para renderizar.
- **El plot más pesado, sintenia alineada** (`output$homo_aligned_plot_out`, `server.R:20951`; `ortho_aligned_plot_out`, `:23996`), extrae regiones FASTA y calcula alineamientos **dentro del cuerpo del render**.
- `input$app_theme` se lee dentro de 15+ cuerpos de render: un toggle de tema re-renderiza todos los plots visibles simultáneamente.
- Cada chart de analytics se registra 2-3 veces (visible + `_export` + modal); al exportar se renderizan los ~20 duplicados además de los visibles (`server.R:32857-32880`).
- Cada plot de estructura génica añade 3 capas hover invisibles (`alpha = 0.003`, `server.R:2555-2586`) que triplican elementos SVG interactivos.
- Mitigaciones ya presentes (hay que conservarlas): fases diferidas de analytics, `suspendWhenHidden`, `bindEvent` en 11 plots pesados, guardrails de muestreo en PIP (2.500 bloques/track), compresión de SVG (`R/utils.R:130-209`).

### Propuestas viables

| # | Propuesta | Impacto | Esfuerzo |
|---|---|---|---|
| 5.1 | **Sacar el cómputo fuera del render**: la extracción FASTA y el alineamiento del plot de sintenia deben ejecutarse en un `future_promise`/`ExtendedTask` que alimente un reactive; el `renderGirafe` solo dibuja datos ya listos. Es el cambio de mayor impacto percibido en gráficos. | Alto | Medio |
| 5.2 | **Desacoplar el tema del ggplot**: parametrizar colores vía CSS/variables o regenerar solo la paleta; las geometrías no cambian con el tema y no deberían recalcularse. Alternativa pragmática: aislar la lectura de `input$app_theme` en un reactive de paleta y hacer que solo los elementos de color dependan de él. | Alto | Medio |
| 5.3 | **Eliminar las 3 capas hover invisibles**: unificar en una sola capa con `data_id` común o tooltips sobre las capas visibles reales. Reduce el SVG y el tiempo de serialización ggiraph por plot. | Medio | Bajo |
| 5.4 | **Reutilizar los SVG ya renderizados para exportar** en lugar de los ~20 outputs `_export` duplicados: el navegador ya los captura para los reportes (`www/js/reproducible_report.js`). Como mínimo, que visible y export compartan el mismo reactive de datos. | Medio-Alto | Medio |
| 5.5 | **`bindCache` en los renders deterministas** (misma entrada ⇒ mismo gráfico), con clave = organismo + gen + ventana + filtros. Permite compartir resultados entre sesiones del mismo proceso y es el mecanismo nativo que hoy está ausente (0 usos). | Medio | Bajo-Medio |
| 5.6 | Debounce en controles que regeneran plots pesados (umbral de identidad, reordenación de tracks). | Medio | Muy bajo |

---

## 6. Alineamientos LASTZ

### Diagnóstico

El flujo ortho (Blocks y MultiPIP) ya es asíncrono (`future_promise` + `promise_all`, `server.R:10691`, `11357`) con una caché de resultados bien diseñada (la clave incluye mtime/tamaño del genoma; los filtros se aplican post-hoc). Los problemas son:

1. **Paralelismo efectivo = 1 en producción**: `APP_LASTZ_WORKERS=1` en `.env:30` y `docker-compose.yml:32`. Los N trabajos se ejecutan en serie en un único worker de fondo.
2. **Tres flujos síncronos que bloquean la sesión:**
   - Suggest-reference (PIP y MultiPIP): O(n²) de pares, `lapply` anidado en el hilo principal (`server.R:10400-10487`, `11050-11143`).
   - Modo homo Multi-Gene: bucle `for` secuencial (`run_homo_local_lastz`, `server.R:20281-20321`).
   - Fase LASTZ de reportes (`server.R:34885-34977`), que el propio UI admite que "can take several minutes".
3. **Caché volátil**: solo memoria por sesión, máx. 48 entradas. Con 1 contenedor por sesión en ShinyProxy, cada usuario repite alineamientos idénticos.
4. **Trabajo redundante**: la secuencia de referencia se re-extrae del 2bit por cada par (`R/utils.R:4960-4961`); la caché de secuencias no se comparte entre workers; suggest-reference ni lee ni puebla la caché principal; Blocks y MultiPIP son ejecuciones lastz independientes para el mismo par.
5. **Efecto colateral:** `with_lastz_future_plan` (`server.R:136-185`) muta el plan global de `future` y no lo restaura; tras un run con 1 worker, el resto de tareas asíncronas de la app quedan serializadas.
6. **Sin tuning ni reintentos**: lastz corre single-thread con parámetros por defecto; un timeout (90 s) en ventanas grandes produce fallo total del par sin reintento con ventana reducida.

### Propuestas viables

| # | Propuesta | Impacto | Esfuerzo |
|---|---|---|---|
| 6.1 | **Subir `APP_LASTZ_WORKERS`** (p. ej. a núcleos-1) en despliegues con CPU disponible. Es un cambio de una variable de entorno con efecto inmediato sobre el tiempo total de una corrida de N pares (de lineal a ~lineal/N). | Muy alto | Trivial |
| 6.2 | **Asincronizar los tres flujos síncronos** reutilizando el patrón ya probado del observer ortho (future_promise + promise_all + token anti-stale). La UI deja de congelarse en suggest-reference, modo homo y reportes. | Muy alto | Medio |
| 6.3 | **Persistir resultados en disco** (`cache/alignments/`, RDS/TSV con la misma clave actual, que ya incluye mtime del genoma): la caché sobrevive a sesiones y reinicios, y habilita pre-cómputo de pares frecuentes en build-time o por cache warming. | Muy alto | Medio |
| 6.4 | **Extraer la referencia una sola vez por corrida** y materializar su FASTA compartido para los N queries; elimina N-1 lecturas redundantes de archivos 2bit de hasta ~960 MB. | Alto | Bajo |
| 6.5 | **Conectar suggest-reference con la caché de alineamientos**: los pares ya alineados en la vista principal se reutilizan, y el scoring puebla la caché para la vista. Elimina trabajo duplicado visible para el usuario. | Alto | Bajo |
| 6.6 | **Restaurar el plan global de `future` tras cada run** (o usar un plan dedicado anidado). Corrige la degradación silenciosa de autocomplete/prefetch tras un alineamiento. | Medio-Alto | Bajo |
| 6.7 | **Una invocación lastz con múltiples archivos query** por proceso en lugar de N procesos (lastz lo soporta), y captura de stdout en lugar de fichero intermedio. Reduce overhead de arranque e I/O temporal. | Medio | Medio |
| 6.8 | **Manejo inteligente de timeout**: registrar los pares que expiran y ofrecer reintento con ventana reducida o parámetros menos estrictos (`--step`, umbrales) en lugar de fallo total. | Medio | Medio |
| 6.9 | Derivar la tabla "general" del parseo LAV (o viceversa) para no pagar dos alineamientos cuando el usuario alterna Blocks/MultiPIP del mismo par. | Medio | Medio |

---

## 7. Generación de reportes

### Diagnóstico

- No hay rmarkdown/knitr: el reporte es HTML autocontenido generado por concatenación (JSON embebido + SVG capturados del navegador + CSS/JS inline, `R/server_shared_analysis_domain.R:1032-1069`), más un ZIP de reproducibilidad con checksums. La captura de SVG desde el navegador es una buena decisión: evita re-renderizar en el servidor.
- Los tiempos los dominan las fases orquestadas con timeouts armados: captura (55 s), **LASTZ (hasta 370 s, síncrono)**, sintenia (60 + 35 s/vista).
- El ensamblado del manifiesto/HTML/ZIP corre en el hilo principal (es I/O relativamente ligero, pero el ZIP con checksums crece con los FASTA/TSV incluidos).
- El JSON del manifiesto se serializa dos veces (`cgv_prepare_report_artifacts` y `cgv_render_report_html`, `:1071-1089`).
- `cache/shared_reports` acumula 200 MB; existe limpieza por expiración y un `report-cleaner` en docker-compose — conviene verificar que ambos corren en producción.

### Propuestas viables

| # | Propuesta | Impacto | Esfuerzo |
|---|---|---|---|
| 7.1 | **Que la fase LASTZ de reportes reuse la caché persistente de 6.3 y el pool asíncrono de 6.2**: si el usuario ya corrió alineamientos en la sesión, el reporte no debería repetirlos; si no, deben correr en paralelo. Reduce la fase de "several minutes" al mínimo real. | Muy alto | Medio |
| 7.2 | **Mover el empaquetado ZIP + checksums a un worker** (`future_promise`), con progreso reportado por polling; el downloadHandler entrega el fichero cuando está listo. | Medio-Alto | Medio |
| 7.3 | **Cachear artefactos por hash del manifiesto** y serializar el JSON una sola vez; republicaciones idénticas devuelven el mismo HTML sin reconstruir nada. | Medio | Bajo |
| 7.4 | Verificar en producción la limpieza de `shared_reports` (cron de 15 min + expiración) y alertar si el directorio supera un umbral. | Medio | Muy bajo |
| 7.5 | Considerar `zip::zipr` (streaming, sin `setwd`) para paquetes grandes. | Bajo | Bajo |

---

## 8. Optimizaciones transversales

| # | Propuesta | Impacto | Esfuerzo |
|---|---|---|---|
| 8.1 | **Revisar límites de caché vs cuota de memoria**: GFF 900 MB + gene index 1200 MB potenciales contra `SP_CONTAINER_MEMORY=2g`. Definir un presupuesto de memoria por sesión coherente con la cuota y bajar los límites de las cachés más pesadas, o subir la cuota del contenedor. Riesgo actual: OOM del contenedor con varias cachés llenas. | Alto (estabilidad) | Bajo |
| 8.2 | **Observabilidad**: activar `APP_PERF_TIMING=1` en staging, persistir marcas en `logs/` y definir 4-5 métricas de producto (ver §10). Sin medición, cada optimización es una apuesta. | Habilitador | Bajo |
| 8.3 | **Modularizar `server.R`** (35k líneas, 110 observers): no mejora el rendimiento directamente, pero cada una de las optimizaciones anteriores es más segura y barata de hacer sobre dominios separados (LASTZ, analytics, reportes). Hacerlo incrementalmente, extrayendo lo que se toca. | Medio (velocidad de desarrollo) | Alto (continuo) |
| 8.4 | Fijar versiones de paquetes R (`renv.lock`) para que los cambios de rendimiento sean atribuibles al código y no a deriva de dependencias. | Bajo | Bajo |

---

## 9. Matriz de priorización

**Quick wins (1-2 semanas, impacto inmediato):**

| Prioridad | Ítem | Por qué primero |
|---|---|---|
| P0 | 6.1 Subir `APP_LASTZ_WORKERS` | Una variable de entorno; multiplica el paralelismo real |
| P0 | 3.1 Precalcular índices de anotación en build-time | Elimina el peor caso de primera búsqueda |
| P0 | 8.1 Presupuesto de memoria coherente con 2 GB/contenedor | Evita caídas de sesiones en producción |
| P1 | 6.6 Restaurar plan global de `future` | Bug de degradación silenciosa |
| P1 | 4.3 + 5.6 Debounce en inputs | Cambios mínimos, mejora perceptible |
| P1 | 3.2 Activar pre-warm selectivo | Ya está implementado, solo hay que encenderlo y acotarlo |
| P1 | 8.2 Telemetría en staging | Habilita verificar todo lo demás |

**Corto plazo (1-2 meses):**

| Prioridad | Ítem |
|---|---|
| P2 | 6.2 Asincronizar suggest-reference, modo homo y fase LASTZ de reportes |
| P2 | 6.3 Caché persistente de alineamientos en disco |
| P2 | 6.4 + 6.5 Eliminar re-extracción de referencia y conectar suggest con la caché |
| P2 | 5.1 Cómputo pesado fuera del render de sintenia |
| P2 | 4.1 Eliminar fallback regex full-scan |
| P2 | 7.1 Reportes reutilizan caché/pool de LASTZ |

**Medio plazo (trimestre):**

| Prioridad | Ítem |
|---|---|
| P3 | 5.2 Desacoplar tema de las geometrías |
| P3 | 5.4 Eliminar outputs `_export` duplicados |
| P3 | 5.5 `bindCache` en renders deterministas |
| P3 | 7.2 Empaquetado ZIP en worker |
| P3 | 6.7-6.9 Eficiencia por proceso lastz y manejo de timeouts |
| P3 | 8.3 Modularización incremental de `server.R` |

---

## 10. Cómo medir el éxito

Definir y registrar (con la telemetría existente) antes y después de cada fase:

1. **Tiempo hasta primera búsqueda útil** (arranque de sesión → resultado de búsqueda renderizado), en frío y en caliente.
2. **p50/p95 de búsqueda de gen** por organismo.
3. **Tiempo de corrida LASTZ** para un caso de referencia (p. ej. 6 organismos, ventana 10 kb), total y por par.
4. **Tiempo de render del plot de sintenia** desde el clic hasta el SVG visible.
5. **Tiempo de generación de reporte** extremo a extremo, desglosado por fases.
6. **Memoria pico por contenedor** bajo sesiones concurrentes.

---

## 11. Conclusión

La aplicación no necesita una reescritura: necesita **completar tres trabajos a medias** — (1) llevar la asincronía y la caché persistente a los flujos LASTZ que quedaron síncronos y volátiles, (2) sacar el cómputo pesado de los renders de gráficos, y (3) mover la construcción de índices del runtime al build-time. Con los quick wins de la §9 se debería notar una mejora clara en una o dos semanas; el grueso del beneficio llega con el bloque P2, que convierte los alineamientos —la operación más cara de la app— en trabajo paralelo, no bloqueante y reutilizable entre sesiones.
