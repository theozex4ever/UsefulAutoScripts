#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# T3Code Disposable Development Environment
# "Agents can go nuts in here."
# ============================================================

NAME="t3-dev"
IMAGE="images:ubuntu/24.04/cloud"

CPU="4"
MEMORY="12GiB"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT="${SCRIPT_DIR}/cloud-init.yaml"

# ------------------------------------------------------------
# Pretty output
# ------------------------------------------------------------

info() {
    printf '\n\033[1;34m==>\033[0m %s\n' "$1"
}

ok() {
    printf '\033[1;32m✓\033[0m %s\n' "$1"
}

fail() {
    printf '\033[1;31mERROR:\033[0m %s\n' "$1" >&2
    exit 1
}

# ------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------

command -v incus >/dev/null 2>&1 \
    || fail "Incus is not installed."

[[ -f "$CLOUD_INIT" ]] \
    || fail "Missing: $CLOUD_INIT"

info "Waiting for Incus daemon"

incus admin waitready -t 30

ok "Incus ready"

# ------------------------------------------------------------
# NUKE
# ------------------------------------------------------------

if incus info "$NAME" >/dev/null 2>&1; then
    info "Destroying existing $NAME"

    incus delete "$NAME" --force

    ok "Old environment destroyed"
else
    info "No existing $NAME found"
fi

# ------------------------------------------------------------
# CREATE
# ------------------------------------------------------------

info "Creating clean $NAME"

incus init "$IMAGE" "$NAME"

ok "Container created"

# ------------------------------------------------------------
# SECURITY / LIMITS
# ------------------------------------------------------------

info "Applying sandbox configuration"

incus config set "$NAME" \
    limits.cpu="$CPU" \
    limits.memory="$MEMORY" \
    security.privileged=false \
    security.idmap.isolated=true \
    security.nesting=true

ok "Sandbox configuration applied"

# ------------------------------------------------------------
# CLOUD INIT
# ------------------------------------------------------------

info "Injecting development environment configuration"

incus config set "$NAME" cloud-init.user-data - < "$CLOUD_INIT"

# ------------------------------------------------------------
# START
# ------------------------------------------------------------

info "Starting $NAME"

incus start "$NAME"

# Wait until networking exists.
incus wait "$NAME" ipv4 --timeout 60 || true

# ------------------------------------------------------------
# WAIT FOR PROVISIONING
# ------------------------------------------------------------

info "Installing development environment"

incus exec "$NAME" -- cloud-init status --wait

ok "Cloud-init completed"

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------

info "Running sanity checks"

incus exec "$NAME" -- test -f /var/lib/t3-sandbox-ready \
    || fail "Provisioning marker missing."

incus exec "$NAME" -- git --version
incus exec "$NAME" -- python3 --version
incus exec "$NAME" -- node --version
incus exec "$NAME" -- npm --version
incus exec "$NAME" -- docker --version

ok "Development tools verified"

# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------

IP="$(incus list "$NAME" -c 4 --format csv | cut -d' ' -f1 || true)"

printf '\n'
printf '=============================================\n'
printf ' T3 DEVELOPMENT SANDBOX READY\n'
printf '=============================================\n'
printf '\n'
printf 'Container : %s\n' "$NAME"
printf 'IP        : %s\n' "${IP:-unknown}"
printf 'CPU       : %s\n' "$CPU"
printf 'RAM       : %s\n' "$MEMORY"
printf '\n'
printf 'Enter:\n'
printf '\n'
printf '  incus exec %s -- su - dev\n' "$NAME"
printf '\n'
printf 'Workspace:\n'
printf '\n'
printf '  /home/dev/projects\n'
printf '\n'
printf 'Agents have passwordless sudo INSIDE this sandbox.\n'
printf 'Host filesystem is NOT mounted.\n'
printf '=============================================\n'
