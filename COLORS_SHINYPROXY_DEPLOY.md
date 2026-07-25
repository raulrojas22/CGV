# Deploy seguro de CGV en Colors

Producción está publicada en:

```text
https://cgv.mobilomics.org
  -> 127.0.0.1:3838
  -> nginx sin privilegios
  -> ShinyProxy 3.2.4
  -> contenedor CGV versionado por release
```

El despliegue normal actualiza únicamente la aplicación. No reemplaza
ShinyProxy, nginx, `docker-socket-proxy`, las redes seguras ni los datos
biológicos persistentes.

## Antes de desplegar

Comprueba la infraestructura sin realizar cambios:

```bash
./deploy-colors-shinyproxy.sh --check
```

El resultado esperado termina con:

```text
CHECK OK: no se realizaron cambios en Colors.
```

El script aborta si detecta cualquiera de estas condiciones:

- ShinyProxy no corresponde al digest fijado de la versión `3.2.4`;
- ShinyProxy monta directamente el socket Podman;
- `docker-socket-proxy` no está saludable;
- la red de control no está aislada;
- la imagen activa no es una release versionada;
- Git contiene cambios sin commit.

## Flujo habitual para un cambio pequeño

1. Modifica y prueba la aplicación localmente.
2. Revisa exactamente qué archivos cambiaron.
3. Crea un commit.
4. Ejecuta el deploy.

```bash
git status
Rscript -e "testthat::test_dir('tests/testthat', reporter='summary')"

git add ui.R custom.scss www/css/cgv_compiled.css
git commit -m "fix: describe el cambio"

./deploy-colors-shinyproxy.sh
```

No uses `--skip-tests` como flujo habitual. Existe únicamente para una
emergencia conocida:

```bash
./deploy-colors-shinyproxy.sh --skip-tests
```

## Qué hace el script

1. Audita la infraestructura remota en modo lectura.
2. Ejecuta parseo y pruebas `testthat` locales.
3. Respalda la configuración y el estado actual.
4. Sincroniza solamente código de aplicación, excluyendo infraestructura,
   secretos, datos, cachés y archivos de trabajo locales.
5. Construye una imagen inmutable como:

   ```text
   localhost/cgv:release-<commit>-<fecha-UTC>
   ```

6. Verifica que `ui.R`, `server.R` y `global.R` dentro de la imagen coincidan
   con los archivos locales.
7. Ejecuta el prewarm y cambia producción a la nueva imagen.
8. Comprueba socket proxy, HTTP interno, instancia CGV y URL pública.

Las sesiones abiertas se cierran durante la conmutación. El tiempo de corte
normal es el necesario para reiniciar ShinyProxy y crear la primera instancia
CGV.

## Rollback automático

Si la nueva release no queda saludable o la URL pública no responde, el script
restaura la imagen anterior y la configuración respaldada.

Cada ejecución guarda su respaldo en:

```text
/home/rarojas/cgv/rollback/<fecha>-pre-app-deploy
```

La imagen nueva no se elimina automáticamente después de un fallo, para poder
inspeccionarla sin afectar la release restaurada.

## Dependencias R

Los cambios normales de R, JavaScript, CSS o contenido reutilizan:

```text
cgv-deps:1.0.0
```

Sólo cuando cambien `Dockerfile.dependencies` o
`docker/install_packages.R`, reconstruye explícitamente la base:

```bash
REBUILD_R_DEPS=1 ./deploy-colors-shinyproxy.sh
```

## Datos persistentes

El script nunca sincroniza ni elimina estos directorios de Colors:

```text
/home/rarojas/cgv/app/annotations
/home/rarojas/cgv/app/genomes
/home/rarojas/cgv/app/go_annotations
/home/rarojas/cgv/app/data
/home/rarojas/cgv/app/cache
/home/rarojas/cgv/ncbi_downloads
```

## Acciones que no deben usarse para un cambio de página

No ejecutes manualmente:

```bash
podman-compose down
podman network rm -f sp-control
podman rm -f cgv-docker-socket-proxy
```

Tampoco vuelvas a configurar ShinyProxy `3.1.1` ni una imagen mutable
`cgv:1.0.0`. Para cambios normales, el único comando de producción es:

```bash
./deploy-colors-shinyproxy.sh
```
