#!/usr/bin/env sh
# Rotate insight.log when it exceeds a given size (in MB)

max=${1:-5}                  # default max size in MB
log_dir="$(dirname "$0")/../telemetry"
log_file="$log_dir/insight.log"

[ -f "$log_file" ] || exit 0

size=$(stat -c%s "$log_file")
threshold=$((max * 1024 * 1024))

if [ "$size" -gt "$threshold" ]; then
  ts=$(date +'%Y%m%d-%H%M%S')
  mv "$log_file" "$log_file.$ts"
  # TODO: optionally compress or remove old rotations
fi
