#!/usr/bin/env bash
# One-time backfill of history/<host>.csv from the node's sysstat (sar) archives.
# Gives the charts days of load history on day one instead of starting empty.
# Safe to re-run: only inserts samples older than the oldest existing entry.
# Run from inside the ~/ministatus clone:  bash backfill_sar.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

HOST=$(hostname -s)
command -v sadf >/dev/null || { echo "no sadf/sysstat here — nothing to backfill"; exit 0; }

TMP=$(mktemp)
for f in /var/log/sysstat/sa[0-9][0-9]; do
  [ -e "$f" ] || continue
  # sadf -d -U → "host;interval;epoch;runq;plist;ldavg-1;..." ; keep epoch,ldavg-1
  # || true: a single corrupt archive (e.g. the day of a hard crash) must not kill the run
  LANG=C sadf -d -U "$f" -- -q 2>/dev/null \
    | awk -F';' 'NR>1 && $3 ~ /^[0-9]+$/ {print $3","$6}' || true
done | sort -t, -k1,1n | awk -F, '!seen[$1]++' > "$TMP"

mkdir -p history
touch "history/$HOST.csv"
OLDEST=$(head -1 "history/$HOST.csv" | cut -d, -f1)
if [ -n "$OLDEST" ]; then
  awk -F, -v o="$OLDEST" '$1 < o' "$TMP" > "$TMP.older"
else
  cp "$TMP" "$TMP.older"
fi
N=$(wc -l < "$TMP.older")
cat "$TMP.older" "history/$HOST.csv" > "$TMP.merged" && mv "$TMP.merged" "history/$HOST.csv"
rm -f "$TMP" "$TMP.older"
echo "backfilled $N samples into history/$HOST.csv (total $(wc -l < history/$HOST.csv))"
