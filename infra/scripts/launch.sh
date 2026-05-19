#!/usr/bin/env bash
# launch.sh — sobe Parte A: 1 servidor + 2 clientes (step+slew).
#
# Fluxo:
#   1. Launch ntp-servidor com cloud-init de servidor.
#   2. Aguarda chronyd responder no servidor; descobre IP.
#   3. Gera cloud-init dos clientes com SERVIDOR_IP substituido.
#   4. Launch ntp-cliente-1 (offset +30s) e ntp-cliente-2 (offset -45s).
#   5. Injeta drift inicial nos clientes via inject-drift.sh.
#
# Uso: ./launch.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "${HERE}/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT

VM_FLAGS=(--cpus 1 --memory 512M --disk 3G)
RELEASE="22.04"

log() { printf '\033[1;34m[launch]\033[0m %s\n' "$*"; }

# 1. Servidor
log "Subindo ntp-servidor..."
multipass launch "${RELEASE}" --name ntp-servidor "${VM_FLAGS[@]}" \
  --cloud-init "${INFRA}/cloud-init/servidor.yaml"

# 2. Descobre IP do servidor (espera ate cloud-init terminar)
log "Aguardando cloud-init do servidor..."
multipass exec ntp-servidor -- cloud-init status --wait >/dev/null
SERVIDOR_IP=$(multipass info ntp-servidor --format csv \
  | awk -F',' 'NR==2 {print $3}')
log "Servidor pronto. IP = ${SERVIDOR_IP}"

# 3. Gera cloud-init dos clientes com IP substituido
sed "s/SERVIDOR_IP/${SERVIDOR_IP}/g" \
  "${INFRA}/cloud-init/cliente-step.yaml" > "${TMP}/cliente-step.yaml"

# 4. Clientes
for VM in ntp-cliente-1 ntp-cliente-2; do
  log "Subindo ${VM}..."
  multipass launch "${RELEASE}" --name "${VM}" "${VM_FLAGS[@]}" \
    --cloud-init "${TMP}/cliente-step.yaml"
  multipass exec "${VM}" -- cloud-init status --wait >/dev/null
done

# 5. Injeta drift inicial nos clientes
log "Injetando drift inicial..."
"${HERE}/inject-drift.sh" ntp-cliente-1 +30
"${HERE}/inject-drift.sh" ntp-cliente-2 -45

log "Parte A pronta. Use 'multipass exec ntp-cliente-1 -- chronyc tracking' para inspecionar."
