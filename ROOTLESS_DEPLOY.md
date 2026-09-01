# Rootless Deployment In Your Home Directory

This guide is for your exact case:

- no `root`
- no Docker
- no Podman
- Debian server
- only your user account, for example `/home/rarojas`

## What changes compared to a normal deployment

Without `root`, you cannot rely on:

- `apt install`
- system-wide `R`
- `systemd` services
- `nginx`
- ports below `1024`

So the workable strategy is:

1. install a private package manager in your home directory
2. create an isolated environment with `R` and the required binaries
3. copy the project into your home directory
4. run the app on a user port such as `3838`
5. keep it alive with `tmux` or `nohup`
6. access it with SSH port forwarding unless the server admin exposes it publicly

## Recommended approach: micromamba in your home

This is the cleanest option because it installs everything under your user path and does not need admin rights.

Official micromamba installation docs:

- <https://mamba.readthedocs.io/en/stable/installation/micromamba-installation.html>
- <https://mamba.readthedocs.io/en/stable/user_guide/micromamba.html>

Package availability confirmed for this workflow:

- `r-base` on conda-forge
- `lastz` on Bioconda
- `samtools` on Bioconda
- `tabix` on Bioconda

## 1) Connect to the server

```bash
ssh colors
```

From what you showed, your home is:

```text
/home/rarojas
```

## 2) Fix the locale warning first

You are seeing:

```text
-bash: warning: setlocale: LC_CTYPE: cannot change locale (UTF-8): No such file or directory
```

Because you do not have root, do the simple safe fix in your shell profile:

```bash
echo 'export LANG=C' >> ~/.bashrc
echo 'export LC_ALL=C' >> ~/.bashrc
source ~/.bashrc
```

That avoids the warning. If your admin later enables `C.UTF-8`, you can switch to that.

## 3) Install micromamba in your home directory

On the server:

```bash
cd /home/rarojas
mkdir -p ~/.local/bin
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
mv bin/micromamba ~/.local/bin/
rmdir bin 2>/dev/null || true
echo 'export MAMBA_ROOT_PREFIX="$HOME/micromamba"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(micromamba shell hook -s bash)"' >> ~/.bashrc
source ~/.bashrc
```

Check:

```bash
micromamba --version
```

## 4) Copy the project to your home directory

From your Mac:

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
  colors:/home/rarojas/A_FULLAPP/
```

If the heavy data folders are not already included or need resync:

```bash
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/annotations/ colors:/home/rarojas/A_FULLAPP/annotations/
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/genomes/ colors:/home/rarojas/A_FULLAPP/genomes/
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/go_annotations/ colors:/home/rarojas/A_FULLAPP/go_annotations/
rsync -avz --progress /Users/rarojas/Documents/A_FULLAPP/cache/ colors:/home/rarojas/A_FULLAPP/cache/
```

## 5) Create the private environment

This repo now includes a rootless environment file:

- `deploy/rootless/environment.yml`

On the server:

```bash
cd /home/rarojas/A_FULLAPP
micromamba create -y -f deploy/rootless/environment.yml
micromamba activate cgv-rootless
```

Check the important binaries:

```bash
R --version
which R
which lastz
which samtools
which tabix
```

## 6) Install anything still missing from inside R

Most dependencies should come from the environment file. If one package is still missing, install it inside the active environment:

```bash
cd /home/rarojas/A_FULLAPP
micromamba activate cgv-rootless
Rscript docker/install_packages.R
```

If the solver fails specifically because of `rbioapi`, leave the environment as-is and then run the same installer script above. That script can fetch the missing R packages from CRAN/Bioconductor inside your user environment.

## 7) Prepare the app environment file

On the server:

```bash
cd /home/rarojas/A_FULLAPP
cp .env.example .env
```

Edit `.env` and leave at least this:

```dotenv
APP_HOST=0.0.0.0
APP_PORT=3838

APP_DEBUG_LOGS=0
APP_PERF_TIMING=0
APP_FUTURE_MODE=multisession
APP_FUTURE_WORKERS=2

APP_PREWARM_ON_START=1
APP_PREWARM_CLEAN=0
APP_PREWARM_BLOCK_START=0
```

Optional `.env.local`:

```dotenv
APP_LASTZ_BIN=/home/rarojas/micromamba/envs/cgv-rootless/bin/lastz
FEEDBACK_RESEND_API_KEY=
FEEDBACK_TO_EMAIL=cgvviewer@gmail.com
FEEDBACK_FROM_EMAIL="CGeV Feedback <feedback@cgvapp.com>"
# cgvapp.com is verified in Resend.
FEEDBACK_SEND_RECEIPT=1
FEEDBACK_PUBLIC_URL=https://cgev.mobilomics.org
FEEDBACK_BACKUP_URL=https://cgvapp.com
FEEDBACK_LOGO_PATH=www/cgv-email-logo.png
```

## 8) Verify that the required folders exist

```bash
cd /home/rarojas/A_FULLAPP
ls -ld annotations genomes go_annotations cache
mkdir -p cache/work_sessions
```

## 9) Test the app manually

Use the native launcher already present in the repo:

```bash
cd /home/rarojas/A_FULLAPP
micromamba activate cgv-rootless
./scripts/run-native.sh
```

In another SSH session:

```bash
curl -I http://127.0.0.1:3838
```

If that responds, the app is running correctly.

## 10) Keep it running after logout

Without `systemd`, use `tmux` if available.

Check if `tmux` exists:

```bash
which tmux
```

### Option A: `tmux` (recommended)

```bash
cd /home/rarojas/A_FULLAPP
micromamba activate cgv-rootless
tmux new -s cgv
./scripts/run-native.sh
```

Detach with:

```text
Ctrl+b then d
```

Reattach later:

```bash
tmux attach -t cgv
```

### Option B: `nohup`

If `tmux` is not available:

```bash
cd /home/rarojas/A_FULLAPP
micromamba activate cgv-rootless
nohup ./scripts/run-native.sh > ~/cgv.log 2>&1 &
echo $! > ~/cgv.pid
```

Check:

```bash
tail -f ~/cgv.log
ps -fp "$(cat ~/cgv.pid)"
```

Stop:

```bash
kill "$(cat ~/cgv.pid)"
```

## 11) Access it from your Mac

If the server does not expose port `3838` publicly, use SSH port forwarding from your Mac:

```bash
ssh -L 3838:127.0.0.1:3838 colors
```

Then open locally:

```text
http://127.0.0.1:3838
```

This is often the easiest option when you only have user access.

## 12) If you want a public URL

With no root, you usually cannot publish a permanent public web service by yourself unless one of these is true:

1. the admin already allows inbound traffic to a user port
2. the admin gives you a reverse proxy
3. you use a user-space tunnel approved by your institution

So for a stable public site, the usual next step is asking the admin for one of these:

```text
Please expose 127.0.0.1:3838 from my account through nginx/apache or give me a public subdomain reverse-proxied to that port.
```

## 13) Quick troubleshooting

If `R` is still not found:

```bash
micromamba activate cgv-rootless
which R
R --version
```

If `lastz` is not found:

```bash
which lastz
```

If the app starts but some searches are slow:

```bash
cd /home/rarojas/A_FULLAPP
micromamba activate cgv-rootless
Rscript scripts/precompute_preloaded_cache.R --root=/home/rarojas/A_FULLAPP --clean
```

If logs are needed:

```bash
tail -n 200 ~/cgv.log
```

## Practical summary for your case

For `colors`, the realistic deployment is:

1. install `micromamba` in `/home/rarojas`
2. copy the repo to `/home/rarojas/A_FULLAPP`
3. create `cgv-rootless`
4. run `./scripts/run-native.sh`
5. keep it alive with `tmux` or `nohup`
6. open it from your Mac with `ssh -L`
