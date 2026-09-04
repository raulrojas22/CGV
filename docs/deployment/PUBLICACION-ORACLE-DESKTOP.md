# Publicar CGeV Desktop en Oracle Object Storage

Este flujo separa tres cosas que hoy están mezcladas:

1. `INSTALABLES-FINALES/` es la salida bruta y conserva instaladores,
   actualizadores, firmas y logs.
2. `desktop/oracle-upload-VERSION/` es el paquete público mínimo.
3. `desktop-release.json` es el índice estable que leen CGeV Web y CGeV Desktop
   para activar los botones de descarga.

Los instaladores no contienen una URL distinta para cada versión: todos consultan
el mismo `desktop-release.json` estable. Esta primera incorporación del sistema
Oracle sí requiere generar un nuevo build de Desktop después de configurar la
URL, porque los instaladores históricos `1.1.0` se construyeron antes de que
existieran el manifiesto y esta integración. Después de ese build inicial no hay
que recompilar sólo para cambiar los archivos apuntados por el manifiesto.

## Resumen muy corto

### Esta primera vez

1. Crea en Oracle un bucket o carpeta pública llamada, por ejemplo,
   `cgv-desktop`.
2. Copia su URL base.
3. Ejecuta una vez:

   ```bash
   ./scripts/configurar-url-oracle-desktop.sh "URL_BASE_DE_ORACLE"
   ```

4. Usa la versión nueva `1.2.0` y ejecuta:

   ```bash
   ./desktop/scripts/regenerar-instalables.sh
   ./scripts/preparar-publicacion-desktop.sh
   ```

5. Abre `desktop/oracle-upload-1.2.0/` y sube todos sus archivos a Oracle.
   Sube `desktop-release.json` al final.

### Las próximas veces

Sólo haces:

```bash
./desktop/scripts/regenerar-instalables.sh
./scripts/preparar-publicacion-desktop.sh
```

Después subes la nueva carpeta `desktop/oracle-upload-VERSION/`. La URL de la
página no se vuelve a editar.

## Qué se publica

| Archivo | Público | Motivo |
|---|---:|---|
| DMG macOS arm64 | Sí | Instalador para Apple Silicon |
| DMG macOS x64 | Sí | Instalador para Intel Mac |
| AppImage Linux x86_64 | Sí | Instalador Linux portátil |
| DEB Linux amd64 | Sí | Instalador Debian/Ubuntu |
| EXE Windows x64 | Sí | Instalador Windows 10/11 |
| Firma `.asc` de cada instalador público | Sí | Verificación GPG |
| `SHA256SUMS.txt` y su `.asc` | Sí | Integridad del conjunto público |
| `CGV-GPG-public-key.asc` | Sí | Permite verificar las firmas |
| `desktop-release.json` | Sí, al final | Activa los botones y contiene URLs, tamaños y SHA-256 |
| ZIP de macOS | No para esta página | Artefacto de actualización/empaquetado |
| `latest-linux.yml` y otros `latest*.yml` | No para esta página | Metadatos de `electron-updater` |
| `logs/` | No | Diagnóstico interno del build |

No hay que unir ni comprimir los instaladores. Cada sistema operativo descarga
su archivo nativo.

## Configuración inicial en Oracle (una sola vez)

### Opción recomendada: bucket exclusivo para instaladores

1. En Oracle Cloud, abre **Storage → Object Storage & Archive Storage → Buckets**.
2. Crea un bucket dedicado, por ejemplo `cgv-desktop-releases`, en tier
   **Standard**.
3. Activa **Object Versioning** para poder recuperar un manifiesto reemplazado
   por error.
4. Configura visibilidad pública de sólo descarga, sin listado
   (`ObjectReadWithoutList`).
5. Usa un prefijo estable, por ejemplo `cgv-desktop/`.

No conviertas en público el bucket privado que contiene organismos. Si necesitas
usar ese mismo bucket, mantenlo privado y crea una **Pre-Authenticated Request
de sólo lectura limitada al prefijo** `cgv-desktop/`. Las PAR expiran y su URL
debe guardarse cuando se crea; al rotarla habrá que registrar la nueva URL y
volver a desplegar la configuración web.

Documentación oficial:

- [Buckets públicos y acceso de sólo lectura](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets.htm)
- [Pre-Authenticated Requests](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/usingpreauthenticatedrequests.htm)
- [Subida masiva de objetos](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/bulk-upload-object.htm)

### Registrar la URL estable

La URL base debe ser la ruta que quedará delante de cada nombre de archivo. Para
un bucket público normalmente tendrá esta forma:

```text
https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/cgv-desktop
```

Para una PAR de prefijo, copia la URL cuando Oracle la muestre y agrega el
prefijo `cgv-desktop` al final si Oracle entrega una URL terminada en `/o/`.

Después ejecuta:

```bash
cd /path/to/CGeV
./scripts/configurar-url-oracle-desktop.sh "https://.../o/cgv-desktop"
```

El script guarda la URL completa del manifiesto en
`www/desktop-release-source.json`. Este cambio se despliega una vez en CGeV Web
y debe quedar incluido en un nuevo build de CGeV Desktop —usa una nueva versión,
por ejemplo `1.2.0`, porque el `1.1.0` existente todavía contiene la integración
anterior basada sólo en GitHub. Mientras la URL base no cambie, las versiones
futuras no requieren modificar la web.

## Publicar una versión

Cada binario público diferente debe tener un número de versión nuevo. No
reemplaces silenciosamente un `1.1.0` por otro binario también llamado `1.1.0`;
usa, por ejemplo, `1.2.0`. Esto mantiene checksums, cachés y soporte
reproducibles.

### 1. Regenerar la salida bruta

```bash
cd /path/to/CGeV
./desktop/scripts/regenerar-instalables.sh
```

### 2. Validar sin crear copias

```bash
./scripts/preparar-publicacion-desktop.sh --check
```

### 3. Crear el paquete de Oracle

```bash
./scripts/preparar-publicacion-desktop.sh
```

El script:

- selecciona los cinco instaladores de la versión de `desktop/package.json`;
- comprueba los checksums de la salida bruta;
- verifica las firmas `.asc` existentes y crea cualquiera que falte;
- crea un `SHA256SUMS.txt` que sólo menciona archivos realmente públicos;
- genera el manifiesto con URL, tamaño y SHA-256 de cada instalador;
- deja el resultado en `desktop/oracle-upload-VERSION/`.

### 4. Subir a Oracle

Sube todo el contenido de `desktop/oracle-upload-VERSION/` al mismo prefijo
configurado como URL base.

Hazlo en dos tandas:

1. Todos los instaladores, `.asc`, checksums y llave pública.
2. `desktop-release.json` **al final**.

Publicar el manifiesto al final impide que la web anuncie una versión cuyos
archivos grandes todavía no terminaron de subir.

### 5. Verificar

```bash
curl -fsS "https://.../o/cgv-desktop/desktop-release.json"
curl -I "https://.../o/cgv-desktop/CGeV-Desktop-VERSION-macOS-arm64.dmg"
```

Después abre la sección **CGeV Desktop** en la versión web. Los mismos enlaces se
usan dentro de la aplicación Desktop porque ambas superficies comparten
`R/ui_desktop_downloads.R`, `www/js/cgv_desktop_downloads.js` y el archivo de
configuración.

## Siguientes versiones

El ciclo normal queda reducido a:

```bash
./desktop/scripts/regenerar-instalables.sh
./scripts/preparar-publicacion-desktop.sh
```

Luego se sube el contenido generado y `desktop-release.json` se reemplaza al
final. No se vuelve a ejecutar el script de configuración, no se editan enlaces
y no se recompilan instaladores por causa de Oracle.

## Alcance del auto-update

Este flujo mueve a Oracle las **descargas visibles de la página CGeV Desktop** en
Web y Desktop. El `electron-updater` de la aplicación sigue siendo un canal
separado configurado actualmente con el repositorio de releases de GitHub. No
se deben subir `latest*.yml`, blockmaps o ZIP de auto-update a Oracle salvo que
se migre ese canal de manera explícita.
