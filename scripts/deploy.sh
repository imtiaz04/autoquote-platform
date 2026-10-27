#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# AutoQuote Blue-Green Deployment
# ============================================================

IMAGE_REPOSITORY="ghcr.io/imtiaz04/autoquote-backend"
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
NGINX_CONFIG="${AUTOQUOTE_NGINX_CONFIG:-${PROJECT_DIR}/nginx/autoquote.conf}"
LOCK_FILE="/tmp/autoquote-deploy.lock"

log() {
    printf '[AutoQuote] %s\n' "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

exists() {
    docker container inspect "$1" >/dev/null 2>&1
}

get_active_port() {
    awk '
        /^[[:space:]]*proxy_pass[[:space:]]+http:\/\/127\.0\.0\.1:800[45];/ {
            port=$2
            sub(/^.*:/, "", port)
            sub(/;.*/, "", port)
            print port
        }
    ' "$NGINX_CONFIG"
}

check_health() {
    local port="$1"
    local attempt

    for attempt in {1..12}; do
        if curl --fail --silent --show-error --max-time 3 \
            "http://127.0.0.1:${port}/healthz" 2>/dev/null |
            grep -q '"status"[[:space:]]*:[[:space:]]*"healthy"'; then
            return 0
        fi

        log "Health check ${attempt}/12 failed on port ${port}."
        sleep 5
    done

    return 1
}

check_nginx_slot() {
    local expected="$1"
    local headers
    local attempt

    for attempt in {1..10}; do
        if headers="$(curl --fail --silent --show-error --max-time 5 \
            -D - -o /dev/null http://127.0.0.1:8080/healthz 2>/dev/null)"; then

            if printf '%s\n' "$headers" |
                grep -Eiq "^X-Active-Slot:[[:space:]]*${expected}[[:space:]]*\r?$"; then

                log "NGINX active slot verified: ${expected}"
                return 0
            fi
        fi

        log "NGINX slot verification ${attempt}/10 failed. Expected: ${expected}"
        sleep 2
    done

    log "ERROR: NGINX did not report expected slot: ${expected}"
    return 1
}

# ============================================================
# Restore NGINX Routing
# ============================================================

restore_nginx() {
    if [[ "$NGINX_SWITCH_ATTEMPTED" != true ]]; then
        return 0
    fi

    log "Restoring original NGINX routing..."

    if [[ -z "$NGINX_BACKUP" || ! -f "$NGINX_BACKUP" ]]; then
        log "CRITICAL: NGINX backup missing."
        return 1
    fi

    cp "$NGINX_BACKUP" "$NGINX_CONFIG" || return 1

    sudo -n /usr/sbin/nginx -t || return 1
    sudo -n /usr/bin/systemctl reload nginx || return 1

    [[ "$(get_active_port)" == "$ACTIVE_PORT" ]] || return 1

    check_health "$ACTIVE_PORT" || return 1
    check_nginx_slot "$ACTIVE_SLOT" || return 1

    log "Original NGINX routing restored and verified."
}

# ============================================================
# Restore Previous Standby
# ============================================================

restore_standby() {
    if ! exists "$BACKUP_CONTAINER"; then

        if [[ "$BACKUP_CREATED" == true ]]; then
            log "CRITICAL: Expected backup container is missing."
            return 1
        fi

        if exists "$STANDBY_CONTAINER"; then
            log "No original standby backup exists."
            log "Leaving the existing standby container untouched."
            log "Manual review may be required."
        else
            log "No standby backup or replacement container exists."
        fi

        return 0
    fi

    log "Restoring previous standby..."

    if exists "$STANDBY_CONTAINER"; then
        docker rm -f "$STANDBY_CONTAINER" || return 1
    fi

    docker rename "$BACKUP_CONTAINER" "$STANDBY_CONTAINER" || return 1

    local running
    running="$(docker inspect -f '{{.State.Running}}' \
        "$STANDBY_CONTAINER")" || return 1

    if [[ "$running" != true ]]; then
        docker start "$STANDBY_CONTAINER" || return 1
    fi

    if ! check_health "$STANDBY_PORT"; then
        log "CRITICAL: Restored standby is unhealthy."
        return 1
    fi

    BACKUP_CREATED=false
    log "Previous standby restored."
}

# ============================================================
# Automatic Failure Recovery
# ============================================================

handle_exit() {
    local status=$?

    trap - EXIT INT TERM

    if [[ "$DEPLOYMENT_COMPLETED" == true ]]; then
        [[ -z "$NGINX_BACKUP" ]] || rm -f "$NGINX_BACKUP"
        return "$status"
    fi

    log "Deployment did not complete (exit ${status}); starting recovery."

    if ! restore_nginx; then
        log "CRITICAL: Cannot verify NGINX rollback."
        log "Leaving replacement container in place to protect live traffic."
        log "Manual intervention required."
        return 1
    fi

    if ! restore_standby; then
        log "CRITICAL: Standby rollback incomplete."
        log "Manual intervention required."
        return 1
    fi

    [[ -z "$NGINX_BACKUP" ]] || rm -f "$NGINX_BACKUP"

    return "$status"
}

# ============================================================
# Deployment Lock and Validation
# ============================================================

exec 200>"$LOCK_FILE"
flock -n 200 || die "Another deployment is already running."

[[ $# -eq 1 && -n "${1:-}" ]] ||
    die "Usage: $0 <image-tag>"

[[ "$1" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] ||
    die "Invalid image tag."

[[ -f "$NGINX_CONFIG" ]] ||
    die "Missing NGINX config: $NGINX_CONFIG"

for command in docker curl awk grep sudo; do
    command -v "$command" >/dev/null ||
        die "Missing command: $command"
done

IMAGE="${IMAGE_REPOSITORY}:$1"
ACTIVE_PORT="$(get_active_port)"

case "$ACTIVE_PORT" in
    8004)
        ACTIVE_SLOT="blue"
        STANDBY_SLOT="green"
        ACTIVE_CONTAINER="autoquote-blue"
        STANDBY_CONTAINER="autoquote-green"
        STANDBY_PORT="8005"
        ;;
    8005)
        ACTIVE_SLOT="green"
        STANDBY_SLOT="blue"
        ACTIVE_CONTAINER="autoquote-green"
        STANDBY_CONTAINER="autoquote-blue"
        STANDBY_PORT="8004"
        ;;
    *)
        die "Expected exactly one active NGINX proxy_pass to port 8004 or 8005."
        ;;
esac

BACKUP_CONTAINER="${STANDBY_CONTAINER}-backup"

BACKUP_CREATED=false
NGINX_SWITCH_ATTEMPTED=false
NGINX_BACKUP=""
DEPLOYMENT_COMPLETED=false

# ============================================================
# Preflight Checks
# ============================================================

log "Active: ${ACTIVE_SLOT}:${ACTIVE_PORT}"
log "Standby: ${STANDBY_SLOT}:${STANDBY_PORT}"

exists "$ACTIVE_CONTAINER" ||
    die "Active container missing."

check_health "$ACTIVE_PORT" ||
    die "Active backend unhealthy."

check_nginx_slot "$ACTIVE_SLOT" ||
    die "NGINX slot header does not match active slot."

if exists "$BACKUP_CONTAINER"; then
    die "Existing ${BACKUP_CONTAINER} must be reviewed before deploying."
fi

sudo -n /usr/sbin/nginx -t ||
    die "NGINX config validation failed."

log "Pulling ${IMAGE}..."

docker pull "$IMAGE" ||
    die "Docker pull failed."

docker image inspect "$IMAGE" >/dev/null ||
    die "Pulled image not found."

[[ "$(get_active_port)" == "$ACTIVE_PORT" ]] ||
    die "NGINX routing changed during preflight."

# ============================================================
# Register Rollback Handler
# ============================================================

trap 'handle_exit' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ============================================================
# Preserve Existing Standby
# ============================================================

log "Preserving old standby container..."

if exists "$STANDBY_CONTAINER"; then
    docker rename "$STANDBY_CONTAINER" "$BACKUP_CONTAINER"
    BACKUP_CREATED=true
    docker stop "$BACKUP_CONTAINER"
else
    log "No existing standby container."
fi

# ============================================================
# Deploy New Standby
# ============================================================

log "Launching replacement ${STANDBY_CONTAINER}..."

docker run -d \
    --name "$STANDBY_CONTAINER" \
    -p "127.0.0.1:${STANDBY_PORT}:8000" \
    "$IMAGE"

if ! check_health "$STANDBY_PORT"; then
    docker logs --tail 30 "$STANDBY_CONTAINER" || true
    die "New standby failed health checks."
fi

# ============================================================
# Switch NGINX Traffic
# ============================================================

[[ "$(get_active_port)" == "$ACTIVE_PORT" ]] ||
    die "Active NGINX routing changed unexpectedly."

NGINX_BACKUP="$(mktemp)"
cp "$NGINX_CONFIG" "$NGINX_BACKUP"

NGINX_SWITCH_ATTEMPTED=true

[[ "$(grep -Fc "proxy_pass http://127.0.0.1:${ACTIVE_PORT};" \
    "$NGINX_CONFIG")" == 1 ]] ||
    die "Expected exactly one active proxy_pass."

[[ "$(grep -Fc "X-Active-Slot ${ACTIVE_SLOT}" \
    "$NGINX_CONFIG")" == 1 ]] ||
    die "Expected exactly one active slot header."

sed -i \
    -e "s|proxy_pass http://127.0.0.1:${ACTIVE_PORT};|proxy_pass http://127.0.0.1:${STANDBY_PORT};|" \
    -e "s|X-Active-Slot ${ACTIVE_SLOT}|X-Active-Slot ${STANDBY_SLOT}|" \
    "$NGINX_CONFIG"

sudo -n /usr/sbin/nginx -t
sudo -n /usr/bin/systemctl reload nginx

# ============================================================
# Verify Traffic Switch
# ============================================================

[[ "$(get_active_port)" == "$STANDBY_PORT" ]] ||
    die "NGINX config did not switch ports."

check_health "$STANDBY_PORT" ||
    die "New active backend unhealthy."

check_health 8080 ||
    die "NGINX health endpoint unhealthy."

check_nginx_slot "$STANDBY_SLOT" ||
    die "NGINX did not switch to expected slot."

# ============================================================
# Deployment Successful
# ============================================================

DEPLOYMENT_COMPLETED=true

log "SUCCESS: ${STANDBY_SLOT}:${STANDBY_PORT} is active."
log "Previous active ${ACTIVE_SLOT}:${ACTIVE_PORT} remains running."

if exists "$BACKUP_CONTAINER"; then
    log "Removing old standby backup ${BACKUP_CONTAINER}..."
    docker rm "$BACKUP_CONTAINER"
fi
