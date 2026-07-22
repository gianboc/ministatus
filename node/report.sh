#!/usr/bin/env bash
# ministatus node reporter — writes status/<host>.json (+ optional event), commits, pushes.
#
# Usage:
#   report.sh          heartbeat (cron: */5 * * * *)
#   report.sh boot     heartbeat + boot event (cron: @reboot, after a network wait)
#   report.sh <word>   heartbeat + arbitrary event (e.g. "deploy")
#
# Runs unprivileged. Lives inside a clone of the repo's `data` branch.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

# never let two runs (cron overlap, slow push) fight over the same clone
exec 9>"$HOME/.ministatus.lock"
flock -n 9 || exit 0

HOST=$(hostname -s)
NOW=$(date -u +%s)
UPTIME_S=$(cut -d. -f1 /proc/uptime)
BOOT=$(( NOW - UPTIME_S ))
read -r L1 L5 L15 _REST < /proc/loadavg
NPROC=$(nproc)
MEM_TOTAL=$(awk '/^MemTotal/{print $2*1024}' /proc/meminfo)
MEM_AVAIL=$(awk '/^MemAvailable/{print $2*1024}' /proc/meminfo)
MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
DISK_ROOT=$(df --output=pcent / | tail -1 | tr -dc 0-9)
DISK_HOME=$(df --output=pcent /home 2>/dev/null | tail -1 | tr -dc 0-9)
SESSIONS=$(who | wc -l)
# counts only; -1 would mean "no scheduler answer" but wc gives 0 either way — acceptable v0
SLURM_R=$( (timeout 5 squeue -h -t R 2>/dev/null || true) | wc -l )
SLURM_PD=$( (timeout 5 squeue -h -t PD 2>/dev/null || true) | wc -l )

mkdir -p status events
cat > "status/$HOST.json" <<EOF
{
  "host": "$HOST",
  "t": $NOW,
  "boot": $BOOT,
  "uptime_s": $UPTIME_S,
  "load": [$L1, $L5, $L15],
  "cores": $NPROC,
  "mem_used": $MEM_USED,
  "mem_total": $MEM_TOTAL,
  "disk_root_pct": ${DISK_ROOT:-0},
  "disk_home_pct": ${DISK_HOME:-0},
  "sessions": $SESSIONS,
  "slurm_running": $SLURM_R,
  "slurm_pending": $SLURM_PD
}
EOF

MSG="hb $HOST"
EVENT="${1:-}"
if [ -n "$EVENT" ]; then
  echo "{\"host\":\"$HOST\",\"event\":\"$EVENT\",\"t\":$NOW}" >> "events/$HOST.jsonl"
  MSG="$(printf '%s' "$EVENT" | tr '[:lower:]' '[:upper:]') $HOST $(date -u -d "@$NOW" +%Y-%m-%dT%H:%M:%SZ)"
fi

git pull --rebase -q origin data || true
git add -A
git commit -q -m "$MSG" || exit 0        # nothing changed, nothing to push
git push -q origin data || {
  git pull --rebase -q origin data
  git push -q origin data
}
