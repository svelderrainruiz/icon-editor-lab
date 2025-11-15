#!/usr/bin/env sh
# log-telemetry.sh – POSIX shell JSONL logger

event="$1"
data="$2"           # optional JSON string

log_dir="$(dirname "$0")/../telemetry"
log_file="$log_dir/insight.log"
[ -d "$log_dir" ] || mkdir -p "$log_dir"

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf "{\"ts\":\"%s\",\"evt\":\"%s\",\"data\":%s}\n" "$ts" "$event" "${data:-{}}" >> "$log_file"
