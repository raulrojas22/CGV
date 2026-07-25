ARG CGV_DEPS_IMAGE=cgv-deps:1.0.0
FROM ${CGV_DEPS_IMAGE}

LABEL org.opencontainers.image.title="CGV" \
      org.opencontainers.image.description="Comparative Genomics Viewer — interactive Shiny app for ortholog analysis, GO enrichment, and genome comparison" \
      org.opencontainers.image.version="1.1.0" \
      org.opencontainers.image.authors="Raul Rojas" \
      org.opencontainers.image.source="https://github.com/rarojas/cgv" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

COPY . /app
# ShinyProxy launches application containers with an unprivileged runtime UID.
# Normalize read/traverse permissions after COPY so static assets keep working
# even if a local file arrived with owner-only permissions (for example 0600).
RUN chmod -R a+rX /app \
    && chmod +x /app/docker/run-app.sh

ENV APP_DIR=/app \
    APP_HOST=0.0.0.0 \
    APP_PORT=3838 \
    APP_DEBUG_LOGS=0 \
    APP_PERF_TIMING=0 \
    APP_PARTIAL_SUGGESTIONS_STRICT=0

EXPOSE 3838

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD wget -qO- "http://127.0.0.1:${APP_PORT}/" >/dev/null 2>&1 || exit 1

CMD ["/app/docker/run-app.sh"]
