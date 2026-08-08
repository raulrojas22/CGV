# Flujo manual de comparación de rendimiento

Este flujo genera evidencia comparable sin ejecutar benchmarks automáticos. La
aplicación conserva sus marcas `[PERF]` actuales y escribe un archivo separado
por cada proceso R dentro del volumen persistente de caché.

## Regla principal

La prueba **antes** y la prueba **después** deben repetir exactamente las mismas
acciones, con los mismos datos, organismos, opciones y navegador. No se deben
cambiar dos optimizaciones al mismo tiempo.

## 1. Captura ANTES

En el `.env` usado por ShinyProxy:

```env
SP_APP_PERF_TIMING=1
SP_PERF_RUN_LABEL=antes_01
```

Después de aplicar la configuración mediante el procedimiento normal de
despliegue:

1. Abrir una sesión nueva de CGV.
2. Ejecutar el recorrido manual elegido.
3. Esperar a que todos los gráficos terminen de cargar.
4. Cerrar la sesión.
5. Repetir el mismo recorrido en una segunda sesión nueva si se desea una
   comparación menos sensible a variaciones puntuales.

Los archivos quedan en el host bajo:

```text
${SP_CACHE_DIR}/perf_runs/antes_01/
```

No es necesario borrar cachés. Si se decide borrar o precalentar algo, se debe
hacer exactamente lo mismo antes de la captura DESPUÉS.

## 2. Captura DESPUÉS

Aplicar **una sola optimización** y cambiar únicamente la etiqueta:

```env
SP_APP_PERF_TIMING=1
SP_PERF_RUN_LABEL=despues_01
```

Repetir exactamente el recorrido anterior. Los nuevos archivos quedan en:

```text
${SP_CACHE_DIR}/perf_runs/despues_01/
```

## 3. Qué compartir para la revisión

Compartir las dos carpetas completas:

```text
perf_runs/antes_01/
perf_runs/despues_01/
```

También indicar, en texto breve:

- pasos realizados y orden exacto;
- gen o conjunto de datos utilizado;
- organismos seleccionados;
- si era la primera sesión después del despliegue;
- cualquier espera, error o comportamiento visual percibido.

Los logs incluyen la etiqueta, fecha UTC, proceso, versión de R, imagen y las
variables de rendimiento relevantes. No se guardan claves ni secretos de
configuración. Aun así, pueden aparecer nombres de genes, organismos, rutas o
mensajes de error producidos por la aplicación.

## 4. Reversión de una optimización

Cada optimización debe quedar en un commit independiente y, cuando corresponda,
detrás de una variable de configuración. Si el resultado DESPUÉS empeora:

1. desactivar la variable de la optimización, o
2. revertir únicamente su commit;
3. crear una etiqueta nueva, por ejemplo `revertido_01`;
4. repetir el mismo recorrido para confirmar la recuperación.

La instrumentación de logs debe permanecer idéntica en ANTES, DESPUÉS y
REVERTIDO para que los resultados sean comparables.

