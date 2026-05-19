#!/usr/bin/env bash
# launch-part-b.sh — acrescenta a 4a VM (ntp-cliente-slew) com makestep
# desabilitado, demonstrando convergencia por slew puro.
#
# Pre-requisito: launch.sh ja foi executado (ntp-servidor existe).
#
# Uso: ./launch-part-b.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "${HERE}/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT

VM_FLAGS=(--cpus 1 --memory 512M --disk 3G)
RELEASE="22.04"

log() { printf '\033[1;34m[launch-b]\033[0m %s\n' "$*"; }

if ! multipass info ntp-servidor >/dev/null 2>&1; then
  echo "Erro: ntp-servidor nao existe. Rode launch.sh primeiro." >&2
  exit 1
fi

SERVIDOR_IP=$(multipass info ntp-servidor --format csv \
  | awk -F',' 'NR==2 {print $3}')
log "Servidor encontrado em ${SERVIDOR_IP}"

sed "s/SERVIDOR_IP/${SERVIDOR_IP}/g" \
  "${INFRA}/cloud-init/cliente-slew.yaml" > "${TMP}/cliente-slew.yaml"

log "Subindo ntp-cliente-slew..."
multipass launch "${RELEASE}" --name ntp-cliente-slew "${VM_FLAGS[@]}" \
  --cloud-init "${TMP}/cliente-slew.yaml"
multipass exec ntp-cliente-slew -- cloud-init status --wait >/dev/null

log "Injetando drift de +60s..."
"${HERE}/inject-drift.sh" ntp-cliente-slew +60

log "Parte B pronta. Slew puro converge lentamente (~30 min para 60s)."
log "Aguarde pelo menos 5 minutos antes de 'make logs && make plot'."
