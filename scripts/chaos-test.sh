#!/usr/bin/env bash
#
# chaos-test.sh - Basic chaos engineering experiments for the microservices
# running on EKS. Randomly deletes pods, simulates node pressure, and checks
# recovery, to validate PDBs/HPA/readiness probes actually protect availability.
#
# Requires: kubectl configured against the target cluster.
#
# Usage:
#   ./chaos-test.sh [NAMESPACE] [EXPERIMENT]
#
#   NAMESPACE   Kubernetes namespace (default: microservices)
#   EXPERIMENT  one of: pod-kill | latency | full (default: full)

set -euo pipefail

NAMESPACE="${1:-microservices}"
EXPERIMENT="${2:-full}"
SERVICES=(user-service product-service order-service)

log() { echo "[$(date +%H:%M:%S)] $*"; }

check_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl not found. Install it and configure access to the cluster." >&2
    exit 1
  fi
}

wait_for_ready() {
  local svc="$1"
  log "Waiting for ${svc} to become fully ready again..."
  kubectl rollout status deployment/"${svc}" -n "${NAMESPACE}" --timeout=180s
}

experiment_pod_kill() {
  log "=== Experiment: random pod kill ==="
  for svc in "${SERVICES[@]}"; do
    pod=$(kubectl get pods -n "${NAMESPACE}" -l app="${svc}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -z "${pod}" ]]; then
      log "No pods found for ${svc}, skipping."
      continue
    fi
    log "Deleting pod ${pod} (${svc})"
    kubectl delete pod "${pod}" -n "${NAMESPACE}" --grace-period=0 --force
    wait_for_ready "${svc}"
    log "${svc} recovered."
  done
}

experiment_latency() {
  log "=== Experiment: CPU stress on one pod per service (simulated latency) ==="
  for svc in "${SERVICES[@]}"; do
    pod=$(kubectl get pods -n "${NAMESPACE}" -l app="${svc}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -z "${pod}" ]]; then
      log "No pods found for ${svc}, skipping."
      continue
    fi
    log "Injecting CPU stress into ${pod} for 60s (requires 'stress' or busybox 'yes' fallback in the container)"
    kubectl exec "${pod}" -n "${NAMESPACE}" -- sh -c \
      "command -v stress >/dev/null 2>&1 && timeout 60 stress --cpu 2 || (timeout 60 sh -c 'yes > /dev/null &' )" || true
    log "Stress injected on ${pod}. Watch HPA and latency dashboards for the next few minutes."
  done
}

experiment_full() {
  experiment_pod_kill
  experiment_latency
  log "=== Post-chaos health check ==="
  kubectl get pods -n "${NAMESPACE}" -o wide
  kubectl get hpa -n "${NAMESPACE}"
  kubectl get pdb -n "${NAMESPACE}"
}

check_kubectl

case "${EXPERIMENT}" in
  pod-kill) experiment_pod_kill ;;
  latency)  experiment_latency ;;
  full)     experiment_full ;;
  *) echo "Unknown experiment: ${EXPERIMENT} (expected pod-kill|latency|full)" >&2; exit 1 ;;
esac

log "Chaos test complete."
