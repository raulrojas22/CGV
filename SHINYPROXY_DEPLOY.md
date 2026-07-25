# CGV ShinyProxy Deployment

CGV now has a multi-user deployment path:

```text
Cloudflare Tunnel -> nginx:18080 -> ShinyProxy:8080 -> one CGV container per browser session
```

ShinyProxy is configured with `authentication: none`, so capacity limits are the
main protection:

- `SP_MAX_TOTAL_INSTANCES=5`
- `SP_CONTAINER_MEMORY=2g`
- `SP_MAX_LIFETIME_MINUTES=120`
- `SP_HEARTBEAT_RATE_MS=30000`

The compose file binds ShinyProxy direct access to `127.0.0.1:8080`; public
traffic should go through nginx or Cloudflare on `CGV_NGINX_PORT` (`18080` by
default, to avoid conflicts with NAS/system port 80).

## Deploy

```bash
./deploy-nas-shinyproxy.sh
```

After the first deploy, Cloudflare Tunnel should point to:

```text
http://localhost:18080
```

## Smoke Test

Open several independent/private browser windows:

```text
http://192.168.1.200:18080/
```

Then on the NAS:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker stats --no-stream
docker logs cgv-shinyproxy --tail 100
```

Expected result: each active browser session has an isolated CGV app container;
closing tabs should release containers after the heartbeat timeout.
