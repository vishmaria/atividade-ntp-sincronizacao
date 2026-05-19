#!/usr/bin/env bash
# destroy.sh — derruba e remove todas as VMs ntp-* da atividade.
#
# Uso: ./destroy.sh

set -euo pipefail

log() { printf '\033[1;31m[destroy]\033[0m %s\n' "$*"; }

VMS=$(multipass list --format csv | awk -F',' 'NR>1 && $1 ~ /^ntp-/ {print $1}')

if [ -z "${VMS}" ]; then
  log "Nenhuma VM ntp-* encontrada. Nada a fazer."
  exit 0
fi

for VM in ${VMS}; do
  log "Removendo ${VM}..."
  multipass delete "${VM}"
done

multipass purge
log "Todas as VMs ntp-* foram removidas."
