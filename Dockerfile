FROM rocker/r-ver:4.5

LABEL org.opencontainers.image.title="CGV" \
      org.opencontainers.image.description="Comparative Genomics Viewer — interactive Shiny app for ortholog analysis, GO enrichment, and genome comparison" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="Rodrigo Rojas" \
      org.opencontainers.image.source="https://github.com/rarojas/cgv" \
      org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    wget \
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
    tabix \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY docker/install_packages.R /tmp/install_packages.R
RUN Rscript /tmp/install_packages.R && rm -f /tmp/install_packages.R

COPY . /app
RUN chmod +x /app/docker/run-app.sh

ENV APP_DIR=/app \
    APP_HOST=0.0.0.0 \
    APP_PORT=3838 \
    APP_DEBUG_LOGS=0 \
    APP_PERF_TIMING=0

EXPOSE 3838

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD wget -qO- "http://127.0.0.1:${APP_PORT}/" >/dev/null 2>&1 || exit 1

CMD ["/app/docker/run-app.sh"]
