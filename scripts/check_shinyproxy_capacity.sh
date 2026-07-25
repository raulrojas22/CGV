#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
EXPECTED_MAX="${SP_MAX_TOTAL_INSTANCES:-10}"
CGV_IMAGE="${CGV_IMAGE:-cgv:1.0.0}"

echo "CGV ShinyProxy capacity check"
echo "URL: ${BASE_URL}"
echo "Expected max instances: ${EXPECTED_MAX}"
echo ""

code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}" || true)"
echo "ShinyProxy HTTP: ${code}"

echo ""
echo "ShinyProxy containers:"
docker ps --filter name=cgv-shinyproxy --filter name=cgv-nginx --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "CGV app containers:"
docker ps --filter ancestor="${CGV_IMAGE}" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'

echo ""
echo "Resource snapshot:"
docker stats --no-stream cgv-shinyproxy cgv-nginx $(docker ps -q --filter ancestor="${CGV_IMAGE}") 2>/dev/null || true
