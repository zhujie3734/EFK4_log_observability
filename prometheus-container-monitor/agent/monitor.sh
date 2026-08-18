#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly STATUS_OK=0
readonly STATUS_WARNING=1
readonly STATUS_CRITICAL=2
readonly STATUS_UNKNOWN=3

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR
readonly CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config/containers.conf}"
readonly LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/monitor.log}"
readonly PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://127.0.0.1:9091}"
readonly PUSHGATEWAY_JOB="${PUSHGATEWAY_JOB:-container_monitor}"
readonly MONITOR_ENV="${MONITOR_ENV:-uat}"
readonly HOST_NAME="${HOST_NAME:-$(hostname)}"
readonly DRY_RUN="${DRY_RUN:-false}"
readonly DEBUG="${DEBUG:-false}"

METRICS_FILE=$(mktemp)
readonly METRICS_FILE

cleanup() {
    rm -f -- "$METRICS_FILE"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

case "$MONITOR_ENV" in
    uat|prd) ;;
    *)
        printf 'MONITOR_ENV must be uat or prd: %s\n' "$MONITOR_ENV" >&2
        exit 1
        ;;
esac

prometheus_escape_label() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    printf '%s' "$value"
}

log_result() {
    local container_name="$1"
    local rule="$2"
    local status="$3"
    local value="$4"
    local message="$5"

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
        "$HOST_NAME" \
        "$MONITOR_ENV" \
        "$container_name" \
        "$rule" \
        "$status" \
        "$value" \
        "$message" >> "$LOG_FILE"
}

init_metrics() {
    cat > "$METRICS_FILE" <<'EOF'
# HELP container_log_check_status Container log check status: 0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN
# TYPE container_log_check_status gauge
# HELP container_log_check_value Numeric value returned by the container log check
# TYPE container_log_check_value gauge
# HELP container_log_check_last_run_timestamp_seconds Unix timestamp of the last container log check
# TYPE container_log_check_last_run_timestamp_seconds gauge
EOF
}

write_metrics() {
    local container_name="$1"
    local rule="$2"
    local status="$3"
    local value="$4"
    local escaped_container
    local escaped_rule

    escaped_container=$(prometheus_escape_label "$container_name")
    escaped_rule=$(prometheus_escape_label "$rule")
    if ! [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        value=0
    fi

    printf 'container_log_check_status{container="%s",rule="%s"} %s\n' \
        "$escaped_container" "$escaped_rule" "$status" >> "$METRICS_FILE"
    printf 'container_log_check_value{container="%s",rule="%s"} %s\n' \
        "$escaped_container" "$escaped_rule" "$value" >> "$METRICS_FILE"
    printf 'container_log_check_last_run_timestamp_seconds{container="%s",rule="%s"} %s\n' \
        "$escaped_container" "$escaped_rule" "$(date +%s)" >> "$METRICS_FILE"
}

record_result() {
    log_result "$@"
    write_metrics "$1" "$2" "$3" "$4"
}

check_no_logs() {
    local container_name="$1"
    local time_interval="$2"
    local log_output
    local log_count

    if ! log_output=$(docker logs --since "$time_interval" --tail 1000 "$container_name" 2>&1); then
        record_result "$container_name" no_logs "$STATUS_UNKNOWN" 0 \
            "failed to read container logs"
        return
    fi

    if [ -n "$log_output" ]; then
        log_count=$(printf '%s\n' "$log_output" | wc -l)
    else
        log_count=0
    fi

    if [ "$log_count" -gt 0 ]; then
        record_result "$container_name" no_logs "$STATUS_OK" "$log_count" \
            "logs found within $time_interval"
    else
        record_result "$container_name" no_logs "$STATUS_CRITICAL" 0 \
            "no logs found within $time_interval"
    fi
}

run_rule() {
    local container_name="$1"
    local rule="$2"
    local args="$3"

    case "$rule" in
        no_logs) check_no_logs "$container_name" "$args" ;;
        *) record_result "$container_name" "$rule" "$STATUS_UNKNOWN" 0 "unknown rule" ;;
    esac
}

push_metrics() {
    local endpoint
    local response_file
    local http_code
    local curl_status
    local -a debug_options=()

    endpoint="${PUSHGATEWAY_URL%/}/metrics/job/${PUSHGATEWAY_JOB}/env/${MONITOR_ENV}/instance/${HOST_NAME}"
    response_file=$(mktemp)

    if [ "$DEBUG" = true ]; then
        debug_options=(--verbose)
        printf 'Pushgateway endpoint: %s\n' "$endpoint"
        nl -ba "$METRICS_FILE"
    fi

    set +o errexit
    http_code=$(curl \
        "${debug_options[@]}" \
        --silent --show-error \
        --connect-timeout 5 --max-time 15 \
        --request PUT \
        --header 'Content-Type: text/plain; version=0.0.4' \
        --output "$response_file" \
        --write-out '%{http_code}' \
        --data-binary @"$METRICS_FILE" \
        "$endpoint")
    curl_status=$?
    set -o errexit

    if [ "$curl_status" -ne 0 ] || ! [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        printf 'Pushgateway request failed: curl=%s http=%s\n' \
            "$curl_status" "${http_code:-none}" >&2
        if [ -s "$response_file" ]; then
            cat "$response_file" >&2
        fi
        rm -f -- "$response_file"
        return 1
    fi

    rm -f -- "$response_file"
}

if [ ! -r "$CONFIG_FILE" ]; then
    printf 'Configuration file cannot be read: %s\n' "$CONFIG_FILE" >&2
    exit 1
fi

init_metrics
declare -A configured_checks=()

while IFS='|' read -r container_name rule args || [ -n "$container_name$rule$args" ]; do
    if [ -z "$container_name" ] && [ -z "$rule" ] && [ -z "$args" ]; then
        continue
    fi
    case "$container_name" in \#*) continue ;; esac

    check_key="$container_name|$rule"
    if [[ -v "configured_checks[$check_key]" ]]; then
        printf 'Duplicate container/rule pair: %s\n' "$check_key" >&2
        exit 1
    fi
    configured_checks[$check_key]=1
    run_rule "$container_name" "$rule" "$args"
done < "$CONFIG_FILE"

if [ "$DRY_RUN" = true ]; then
    cp "$METRICS_FILE" "$SCRIPT_DIR/metrics.test"
    printf 'DRY RUN: metrics were not pushed\n'
    cat "$METRICS_FILE"
elif push_metrics; then
    printf 'Metrics pushed successfully: env=%s host=%s\n' "$MONITOR_ENV" "$HOST_NAME"
else
    log_result monitor-script pushgateway_delivery "$STATUS_UNKNOWN" 0 \
        "failed to push metrics to $PUSHGATEWAY_URL"
    exit 1
fi
