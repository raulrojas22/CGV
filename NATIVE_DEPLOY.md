# Native Deployment Without Docker or Podman

This guide is for running **CGV** directly on a Linux server with native packages.

It is based on the current repository structure:

- main app: `R + Shiny`
- required runtime directories: `annotations/`, `genomes/`, `go_annotations/`, `cache/`
- optional helper folder: `paper/` (not required to run the web app)

## What you actually need on the server

Required:

1. Linux server with `systemd`
2. `R 4.5.x`
3. system libraries used to compile R packages
4. bioinformatics tools used by the app:
   - `lastz`
   - `samtools`
   - `tabix`
5. the project files
6. the runtime data folders:
   - `annotations/`
   - `genomes/`
   - `go_annotations/`
   - `cache/`

Optional but recommended:

- `nginx` as reverse proxy
- a DNS record pointing your domain to the server
- HTTPS with Let's Encrypt

## Recommended server layout

Use this layout to keep things simple and compatible with the app:

```text
/opt/cgv/app
├── global.R
├── ui.R
├── server.R
├── scripts/
├── docker/
├── R/
├── www/
├── annotations/
├── genomes/
├── go_annotations/
└── cache/
```

## 1) Prepare the server user

Create a dedicated user:

```bash
sudo useradd --system --create-home --home-dir /opt/cgv --shell /bin/bash cgv
sudo mkdir -p /opt/cgv/app
sudo chown -R cgv:cgv /opt/cgv
```

## 2) Install R from the official CRAN repository

These commands are for **Ubuntu 24.04 / 22.04 / 20.04** and follow the official CRAN instructions:

```bash
sudo apt update -qq
sudo apt install --no-install-recommends -y software-properties-common dirmngr wget ca-certificates gnupg lsb-release
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc >/dev/null
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
sudo apt update
sudo apt install --no-install-recommends -y r-base r-base-dev
```

If your server is **Debian**, use the official CRAN Debian instructions instead:

- <https://cran.r-project.org/bin/linux/debian/>

For Ubuntu:

- <https://cran.r-project.org/bin/linux/ubuntu/>

## 3) Install native Linux packages required by this repo

These packages come from the current `Dockerfile` of this project:

```bash
sudo apt install -y \
  bash \
  curl \
  build-essential \
  g++ \
  gfortran \
  make \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  zlib1g-dev \
  libbz2-dev \
  liblzma-dev \
  libicu-dev \
  libfontconfig1-dev \
  libcairo2-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libgit2-dev \
  libxt-dev \
  cmake \
  lastz \
  samtools \
  tabix
```

Notes:

- `lastz` is needed for the alignment views.
- `samtools` and `tabix` are used for indexing and post-processing workflows.
- if your distro does not provide `lastz`, install it separately and define `APP_LASTZ_BIN=/path/to/lastz` in `.env.local`

## 4) Copy the project to the server

From your local machine:

```bash
rsync -avz --progress \
  --exclude='.git' \
  --exclude='.claude' \
  --exclude='.codex_backups' \
  --exclude='.qodo' \
  --exclude='.DS_Store' \
  --exclude='.env.local' \
  --exclude='paper/node_modules' \
  /Users/rarojas/Documents/A_FULLAPP/ \
  usuario@TU_SERVIDOR:/opt/cgv/app/
```

If you also want to sync the heavy runtime data again later, you can do it folder by folder:

```bash
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/annotations/ usuario@TU_SERVIDOR:/opt/cgv/app/annotations/
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/genomes/ usuario@TU_SERVIDOR:/opt/cgv/app/genomes/
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/go_annotations/ usuario@TU_SERVIDOR:/opt/cgv/app/go_annotations/
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/cache/ usuario@TU_SERVIDOR:/opt/cgv/app/cache/
```

Then on the server:

```bash
sudo chown -R cgv:cgv /opt/cgv
sudo chmod +x /opt/cgv/app/scripts/run-native.sh
```

## 5) Create the environment file

On the server:

```bash
cd /opt/cgv/app
cp .env.example .env
```

Edit `.env` and leave at least this:

```dotenv
CGV_PORT=3838
APP_HOST=0.0.0.0
APP_PORT=3838

APP_DEBUG_LOGS=0
APP_PERF_TIMING=0
APP_FUTURE_MODE=multisession
APP_FUTURE_WORKERS=2

APP_ORTHO_SUSPEND_HIDDEN=1
APP_ORTHO_DEFER_SEQUENCE=0
APP_FOOTER_DEFER_SEQUENCE=0
APP_HOMO_UPFRONT_ISOFORMS=0
APP_ORTHO_UPFRONT_ISOFORMS=0

APP_PREWARM_ON_START=1
APP_PREWARM_CLEAN=0
APP_PREWARM_BLOCK_START=0
```

These render defaults keep the first gene visualization fast in native/desktop
runs without removing footer sequence composition or per-feature GC content:
hidden outputs stay suspended, hidden isoforms are created on expansion, and
sequence reads are reused from the cached genomic span where possible.

Optional secrets go in `.env.local`:

```dotenv
FEEDBACK_RESEND_API_KEY=...
FEEDBACK_TO_EMAIL=...
FEEDBACK_FROM_EMAIL=CGV Feedback <onboarding@resend.dev>
APP_LASTZ_BIN=/usr/bin/lastz
```

Important:

- `annotations/`, `genomes/`, `go_annotations/` must exist
- `cache/` must exist and be writable by the `cgv` user

## 6) Install the R packages used by the app

This repo already includes the installer script:

```bash
sudo -u cgv -H bash -lc 'cd /opt/cgv/app && Rscript docker/install_packages.R'
```

That script installs:

- CRAN packages such as `shiny`, `bslib`, `dplyr`, `ggplot2`, `future`, `promises`, `httr2`, `visNetwork`
- Bioconductor packages such as `Biostrings`, `Rsamtools`, `GenomicRanges`, `IRanges`, `GenomeInfoDb`, `rtracklayer`

## 7) Test the app manually first

Before creating the service, test it interactively:

```bash
sudo -u cgv -H bash -lc 'cd /opt/cgv/app && ./scripts/run-native.sh'
```

If everything is fine, you should see something like:

```text
[cgv-native] starting Shiny app at 0.0.0.0:3838
```

Then test from the same server:

```bash
curl -I http://127.0.0.1:3838
```

Stop it with `Ctrl+C` after the check.

## 8) Optional but recommended: prewarm cache

This reduces first-search latency:

```bash
sudo -u cgv -H bash -lc 'cd /opt/cgv/app && Rscript scripts/precompute_preloaded_cache.R --root=/opt/cgv/app'
```

If you want it on every startup, leave:

```dotenv
APP_PREWARM_ON_START=1
```

## 9) Create the systemd service

This repo now includes an example unit file:

- `deploy/systemd/cgv.service.example`

Install it:

```bash
sudo cp /opt/cgv/app/deploy/systemd/cgv.service.example /etc/systemd/system/cgv.service
sudo systemctl daemon-reload
sudo systemctl enable --now cgv
```

Check status:

```bash
sudo systemctl status cgv
sudo journalctl -u cgv -f
```

Useful commands:

```bash
sudo systemctl restart cgv
sudo systemctl stop cgv
sudo systemctl start cgv
```

## 10) Open the firewall

If you want direct access on port `3838`:

```bash
sudo ufw allow 3838/tcp
sudo ufw reload
```

## 11) Optional: publish behind Nginx on port 80/443

Install nginx:

```bash
sudo apt install -y nginx
```

Example virtual host:

```nginx
server {
    listen 80;
    server_name TU_DOMINIO;

    location / {
        proxy_pass http://127.0.0.1:3838;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
```

Save it as:

```text
/etc/nginx/sites-available/cgv
```

Then enable it:

```bash
sudo ln -s /etc/nginx/sites-available/cgv /etc/nginx/sites-enabled/cgv
sudo nginx -t
sudo systemctl reload nginx
```

## 12) Optional: enable HTTPS

If your domain already points to the server:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d TU_DOMINIO
```

## 13) How to update the app later

From your local machine:

```bash
rsync -avz --progress \
  --delete \
  --exclude='annotations' \
  --exclude='genomes' \
  --exclude='go_annotations' \
  --exclude='cache' \
  --exclude='.git' \
  --exclude='.env.local' \
  --exclude='paper/node_modules' \
  /Users/rarojas/Documents/A_FULLAPP/ \
  usuario@TU_SERVIDOR:/opt/cgv/app/
```

Then on the server:

```bash
sudo chown -R cgv:cgv /opt/cgv
sudo -u cgv -H bash -lc 'cd /opt/cgv/app && Rscript docker/install_packages.R'
sudo systemctl restart cgv
```

## 14) What is not required for production

You do **not** need this to run the web app:

- Docker
- Podman
- the `paper/` Node dependency for `docx`

The `paper/` folder is only for manuscript/document generation.

## 15) Quick troubleshooting

If the service does not start:

```bash
sudo journalctl -u cgv -n 100 --no-pager
```

If R packages fail to install:

1. verify `r-base-dev` is installed
2. verify the `lib*-dev` packages from step 3 are installed
3. run again:

```bash
sudo -u cgv -H bash -lc 'cd /opt/cgv/app && Rscript docker/install_packages.R'
```

If the app opens but some alignments fail:

```bash
which lastz
lastz --help | head
```

If that binary is elsewhere, set:

```dotenv
APP_LASTZ_BIN=/absolute/path/to/lastz
```

If first search is slow:

```bash
sudo -u cgv -H bash -lc 'cd /opt/cgv/app && Rscript scripts/precompute_preloaded_cache.R --root=/opt/cgv/app --clean'
```

## Summary

For this repository, native deployment means:

1. install `R 4.5`, Linux build libraries, and bioinformatics binaries
2. copy the app to `/opt/cgv/app`
3. copy the data directories
4. run `Rscript docker/install_packages.R`
5. test with `./scripts/run-native.sh`
6. enable the `systemd` service
7. optionally place nginx in front of it
