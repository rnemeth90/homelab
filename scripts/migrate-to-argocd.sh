#!/usr/bin/env bash
#
# migrate-to-argocd.sh
#
# One-time migration runbook for handing metrics-server, metallb,
# ingress-nginx, and cert-manager over to ArgoCD (see
# helm-charts/argocd/applicationset.yaml). Run this ONCE, from a machine
# with kubectl access to the cluster, AFTER ansible-playbooks/kubernetes/10-argocd.yaml
# has been applied and ArgoCD is up and running.
#
# cert-manager and ingress-nginx were already installed via Helm under the
# same release name/namespace ArgoCD will use, so they're adopted in place.
# metrics-server and metallb were installed via raw manifests in different
# namespaces than ArgoCD will use, so their old copies are deleted first to
# avoid running duplicate controllers (metrics.k8s.io APIService is a
# cluster-wide singleton; running two MetalLB speakers simultaneously risks
# duplicate/ conflicting LoadBalancer IP announcements).
#
# Usage:
#   ./scripts/migrate-to-argocd.sh                 # interactive, full migration
#   ./scripts/migrate-to-argocd.sh --yes            # skip confirmation prompts
#   ./scripts/migrate-to-argocd.sh --skip-metallb   # adopt cert-manager/ingress-nginx/
#                                                    # metrics-server only; leave the
#                                                    # existing metallb install alone
#   ./scripts/migrate-to-argocd.sh --dry-run        # print what would run, do nothing
#
# Requires: kubectl (with a working KUBECONFIG or /etc/kubernetes/admin.conf)

set -euo pipefail

METALLB_VERSION="v0.14.9"
SYNC_TIMEOUT_SECONDS=300
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLICATIONSET_FILE="${REPO_ROOT}/helm-charts/argocd/applicationset.yaml"

YES=false
DRY_RUN=false
SKIP_METALLB=false

for arg in "$@"; do
  case "$arg" in
    --yes) YES=true ;;
    --dry-run) DRY_RUN=true ;;
    --skip-metallb) SKIP_METALLB=true ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

run() {
  echo "+ $*"
  if ! $DRY_RUN; then
    "$@"
  fi


confirm() {
  local prompt="$1"
  if $YES || $DRY_RUN; then
    return 0
  fi
  read -r -p "${prompt} [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

if [[ -z "${KUBECONFIG:-}" && -f /etc/kubernetes/admin.conf ]]; then
  export KUBECONFIG=/etc/kubernetes/admin.conf
fi

echo "== Pre-flight checks =="
command -v kubectl >/dev/null || { echo "kubectl not found in PATH" >&2; exit 1; }
run kubectl cluster-info >/dev/null
echo "Current context: $(kubectl config current-context 2>/dev/null || echo unknown)"

if ! kubectl get deploy -n argocd argocd-server >/dev/null 2>&1; then
  echo "argocd-server deployment not found in 'argocd' namespace." >&2
  echo "Run ansible-playbooks/kubernetes/10-argocd.yaml first." >&2
  exit 1
fi
echo "ArgoCD found."

echo
echo "== Current LoadBalancer services (for before/after comparison) =="
kubectl get svc -A -o wide --field-selector spec.type=LoadBalancer || true

echo
if ! confirm "Proceed with migrating metrics-server${SKIP_METALLB:+ (metallb skipped)} and cert-manager/ingress-nginx adoption to ArgoCD?"; then
  echo "Aborted."
  exit 1
fi

echo
echo "== Removing old metrics-server (raw manifest, kube-system) =="
run kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --ignore-not-found

if ! $SKIP_METALLB; then
  echo
  echo "== Removing old MetalLB (raw manifest, metallb-system) =="
  echo "NOTE: LoadBalancer services will briefly lose their external IP until the"
  echo "new ArgoCD-managed MetalLB re-assigns addresses from the same pool."
  if confirm "Really remove the existing MetalLB install now?"; then
    run kubectl delete -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml" --ignore-not-found
    run kubectl delete namespace metallb-system --ignore-not-found
  else
    echo "Skipping MetalLB removal; ArgoCD's metallb app will be left out of sync"
    echo "until you remove the old install manually."
  fi
else
  echo
  echo "== Skipping MetalLB migration (--skip-metallb) =="
fi

echo
echo "== Applying ArgoCD ApplicationSet (helm-charts/argocd/applicationset.yaml) =="
run kubectl apply -f "$APPLICATIONSET_FILE"

if $DRY_RUN; then
  echo
  echo "Dry run complete. No changes were made."
  exit 0
fi

all_synced_and_healthy() {
  # Reads "NAME SYNC HEALTH" rows on stdin. Ready only if there's at least
  # one non-blank row and every row is Synced/Healthy.
  awk 'NF{lines++} NF && ($2!="Synced" || $3!="Healthy"){bad=1} END{exit (lines>0 && !bad) ? 0 : 1}'
}

echo
echo "== Waiting for ArgoCD Applications to sync (timeout ${SYNC_TIMEOUT_SECONDS}s) =="
deadline=$((SECONDS + SYNC_TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  echo "--- $(date '+%H:%M:%S') ---"
  status_table=$(kubectl get applications.argoproj.io -n argocd \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' \
    --no-headers 2>/dev/null || true)
  echo "NAME  SYNC  HEALTH"
  echo "$status_table"

  if all_synced_and_healthy <<<"$status_table"; then
    echo "All Applications Synced/Healthy."
    break
  fi
  sleep 10
done

echo
echo "== Final LoadBalancer services =="
kubectl get svc -A -o wide --field-selector spec.type=LoadBalancer || true

echo
echo "Done. Verify:"
echo "  kubectl get applications -n argocd"
echo "  kubectl get pods -A | grep -E 'metallb|ingress-nginx|cert-manager|metrics-server'"
echo "  Ingress/TLS still resolving correctly for existing apps."
