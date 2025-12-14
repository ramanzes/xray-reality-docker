FROM debian:12-slim

RUN apt update && apt upgrade -y && apt install -y \
    curl jq ca-certificates openssl \
    qrencode \
 && rm -rf /var/lib/apt/lists/*

# Xray
RUN bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

WORKDIR /app

COPY scripts/ /app/scripts/
COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /app/scripts/*.sh

ENTRYPOINT ["/entrypoint.sh"]
