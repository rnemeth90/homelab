#!/usr/bin/env bash
# Upgrade a kubeadm cluster (Debian/Ubuntu nodes, pkgs.k8s.io repos) one minor
# version at a time: control planes first, then workers, one node at a time.
#
# Usage:
#   ./upgrade-kubeadm-cluster.sh -v 1.33.1 [-u ssh_user] [-t control-plane|workers|all] [-n] [-y]
#
# Run from a workstation with kubectl access to the cluster and SSH access to
# every node. The password is prompted for once and used for both SSH login and
# sudo on all nodes (set SUDO_PASS to skip the prompt); SSH keys and passwordless
# sudo are used automatically when available. Node SSH addresses default to the node
# names; override with SSH_SUFFIX (e.g. SSH_SUFFIX=.geekyryan.lan).
set -euo pipefail

TARGET_VERSION=""
SSH_USER="${SSH_USER:-$USER}"
SSH_SUFFIX="${SSH_SUFFIX:-}"
SCOPE="all"
DRY_RUN=false
ASSUME_YES=false
SUDO_PASS="${SUDO_PASS:-}"
CTL_DIR="$(mktemp -d /tmp/kubeadm-upg.XXXXXX)"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10
  -o ControlMaster=auto -o ControlPath="$CTL_DIR/%C" -o ControlPersist=15m)

cleanup() {
  local n
  for n in ${TARGETS[@]+"${TARGETS[@]}"}; do
    ssh "${SSH_OPTS[@]}" -O exit "${SSH_USER}@${n}${SSH_SUFFIX}" >/dev/null 2>&1 || true
  done
  rm -rf "$CTL_DIR"
}
TARGETS=()
trap cleanup EXIT

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

while getopts "v:u:t:nyh" opt; do
  case $opt in
    v) TARGET_VERSION="${OPTARG#v}" ;;
    u) SSH_USER="$OPTARG" ;;
    t) SCOPE="$OPTARG" ;;
    n) DRY_RUN=true ;;
    y) ASSUME_YES=true ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done

[[ "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Error: -v <x.y.z> required" >&2; usage 1; }
case "$SCOPE" in control-plane|workers|all) ;; *) echo "Error: -t must be control-plane, workers, or all" >&2; exit 1 ;; esac
MINOR="${TARGET_VERSION%.*}"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mError: %s\033[0m\n' "$*" >&2; exit 1; }

# run <node> <command...>: run on a node via ssh (or print when dry-running).
# The sudo password is sent over stdin (never on the command line) and a
# remote sudo() shell function feeds it to `sudo -S`; any further stdin (e.g. a
# heredoc script) is passed through to the command after the password.
remote() {
  local node="$1"; shift
  if $DRY_RUN; then echo "[dry-run] ssh $node: $*"; return 0; fi
  local payload
  payload='IFS= read -r SUDOPW
sudo() {
  if command sudo -n true 2>/dev/null; then command sudo "$@"
  else { printf "%s\n" "$SUDOPW"; cat; } | command sudo -S -p "" "$@"; fi
}
'"$*"
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${node}${SSH_SUFFIX}" "bash -c $(printf '%q' "$payload")" \
    < <(printf '%s\n' "$SUDO_PASS"; [[ -t 0 ]] || cat)
}

kube() {
  if $DRY_RUN && [[ "$1" =~ ^(drain|uncordon)$ ]]; then echo "[dry-run] kubectl $*"; return 0; fi
  kubectl "$@"
}

# Switch the apt repo to the target minor and install a package version
# (unhold -> install -> hold).
apt_install_pkg() {
  local node="$1" pkg="$2"
  remote "$node" "sudo bash -es" <<EOF
set -euo pipefail
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${MINOR}/deb/Release.key \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${MINOR}/deb/ /' \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-mark unhold ${pkg}
apt-get install -y --allow-change-held-packages ${pkg}='${TARGET_VERSION}-*'
apt-mark hold ${pkg}
EOF
}

upgrade_kubelet() {
  local node="$1"
  apt_install_pkg "$node" "kubelet kubectl"
  remote "$node" "sudo systemctl daemon-reload && sudo systemctl restart kubelet"
}

wait_node_ready() {
  local node="$1"
  $DRY_RUN && return 0
  kubectl wait --for=condition=Ready "node/$node" --timeout=300s
}

# ---- Preflight -------------------------------------------------------------
command -v kubectl >/dev/null || die "kubectl not found"
kubectl get nodes >/dev/null || die "cannot reach cluster"

# Portable (bash 3.2 on macOS has no mapfile)
CONTROL_PLANES=(); WORKERS=()
while IFS= read -r n; do [[ -n "$n" ]] && CONTROL_PLANES+=("$n"); done < <(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
while IFS= read -r n; do [[ -n "$n" ]] && WORKERS+=("$n"); done < <(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
[[ ${#CONTROL_PLANES[@]} -gt 0 ]] || die "no control plane nodes found"

log "Current cluster state"
kubectl get nodes -o wide
echo "Target version: v${TARGET_VERSION}"
echo "Scope:          ${SCOPE}"
echo "Control planes: ${CONTROL_PLANES[*]}"
echo "Workers:        ${WORKERS[*]-none}"
$DRY_RUN && echo "(dry-run: no changes will be made)"

if ! $ASSUME_YES && ! $DRY_RUN; then
  read -r -p "Proceed with upgrade? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

# Nodes this run will touch
[[ "$SCOPE" != "workers" ]] && TARGETS+=("${CONTROL_PLANES[@]}")
[[ "$SCOPE" != "control-plane" ]] && TARGETS+=(${WORKERS[@]+"${WORKERS[@]}"})
[[ ${#TARGETS[@]} -gt 0 ]] || die "no nodes to upgrade for scope '$SCOPE'"

if ! $DRY_RUN && [[ -z "$SUDO_PASS" ]]; then
  read -r -s -p "Password for ${SSH_USER} on nodes (SSH + sudo; blank if key/passwordless sudo): " SUDO_PASS
  echo
fi

# Feed the password to ssh non-interactively (OpenSSH >= 8.4)
if ! $DRY_RUN && [[ -n "$SUDO_PASS" ]]; then
  printf '#!/bin/sh\nprintf "%%s\\n" "$SUDO_PASS"\n' > "$CTL_DIR/askpass"
  chmod 700 "$CTL_DIR/askpass"
  export SUDO_PASS SSH_ASKPASS="$CTL_DIR/askpass" SSH_ASKPASS_REQUIRE=force
fi

log "Checking SSH connectivity"
for n in "${TARGETS[@]}"; do
  remote "$n" "sudo true" || die "SSH/sudo failed for $n"
done

# Back up etcd on the first control plane before touching anything.
FIRST_CP="${CONTROL_PLANES[0]}"
if [[ "$SCOPE" != "workers" ]]; then
log "Backing up etcd on $FIRST_CP"
remote "$FIRST_CP" "sudo mkdir -p /var/backups/etcd && sudo cp -a /etc/kubernetes /var/backups/etcd/kubernetes-\$(date +%F-%H%M%S) && \
  if command -v etcdctl >/dev/null; then sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/backups/etcd/snapshot-\$(date +%F-%H%M%S).db; else echo 'etcdctl not installed; copied /etc/kubernetes only'; fi"
fi

# ---- Control planes --------------------------------------------------------
if [[ "$SCOPE" != "workers" ]]; then
for i in "${!CONTROL_PLANES[@]}"; do
  node="${CONTROL_PLANES[$i]}"
  log "Upgrading control plane $node"

  apt_install_pkg "$node" kubeadm
  remote "$node" "kubeadm version -o short"
  remote "$node" "sudo kubeadm upgrade plan --ignore-preflight-errors=CreateJob"

  if [[ $i -eq 0 ]]; then
    # CreateJob's 15s timeout is hardcoded in kubeadm and flaky on slow nodes
    remote "$node" "sudo kubeadm upgrade apply v${TARGET_VERSION} -y --skip-phases=addon/kube-proxy --ignore-preflight-errors=CreateJob"
  else
    remote "$node" "sudo kubeadm upgrade node --skip-phases=addon/kube-proxy"
  fi

  kube drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s
  upgrade_kubelet "$node"
  wait_node_ready "$node"
  kube uncordon "$node"
done
fi

# ---- Workers ---------------------------------------------------------------
if [[ "$SCOPE" != "control-plane" ]]; then
for node in ${WORKERS[@]+"${WORKERS[@]}"}; do
  [[ -n "$node" ]] || continue
  log "Upgrading worker $node"

  apt_install_pkg "$node" kubeadm
  remote "$node" "sudo kubeadm upgrade node"

  kube drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s
  upgrade_kubelet "$node"
  wait_node_ready "$node"
  kube uncordon "$node"
done
fi

log "Upgrade complete"
kubectl get nodes -o wide
