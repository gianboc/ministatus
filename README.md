# ministatus

Dead-simple status page for the mini workstations. **No servers, no databases, no
Grafana** — each machine pushes a tiny JSON heartbeat to the `data` branch of this
repo via cron; GitHub Pages serves a static page that reads those files and shows
who's alive.

**Page:** https://gianboc.github.io/ministatus/

## How it works

- Every 5 minutes, each enrolled node runs [`node/report.sh`](node/report.sh)
  (plain bash, unprivileged): it writes `status/<host>.json` (uptime, boot time,
  load, RAM, disk, session count, Slurm job counts) and pushes to the `data`
  branch with a scoped deploy key.
- On boot (`@reboot` cron), the same script also appends a line to
  `events/<host>.jsonl` and pushes with a `REBOOT <host> <time>` commit message —
  so **the git log of the `data` branch is the reboot log**.
- The page compares each node's last heartbeat with the current time in *your*
  browser: a machine can't report that it's dead, but silence can — no heartbeat
  for >20 min shows as **likely down**.
- **Peer checks**: each heartbeat also TCP-probes the other minis' SSH port and
  records the result. A silent node that fresh peers can still reach shows as
  **not reporting** (its reporting broke); one they can't reach shows as
  **unreachable** (peer-confirmed down, ~5–10 min detection).
- **Load history**: every heartbeat appends `t,load1` to `history/<host>.csv`
  (pruned to a 35-day window). The page renders 24 h / 7 d / 30 d charts of load
  as % of cores under each tile. [`node/backfill_sar.sh`](node/backfill_sar.sh)
  seeds the file from the node's existing sysstat archives on enrollment.
- Machine vitals only: no usernames, no job names.

## Enrolling a node

```bash
# on the node, as an unprivileged user
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_ministatus -N "" -C "$(hostname -s) ministatus reporter"
# add ~/.ssh/id_ed25519_ministatus.pub as a WRITE deploy key on this repo, then:
cat >> ~/.ssh/config <<'EOF'
Host github-ministatus
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_ministatus
  IdentitiesOnly yes
EOF
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
git clone -b data git@github-ministatus:gianboc/ministatus.git ~/ministatus
cd ~/ministatus && git config user.name "$(hostname -s)-reporter" && git config user.email "ministatus@localhost"
# fetch the reporter script from the main branch:
git show origin/main:node/report.sh > report.sh && chmod +x report.sh   # (after: git fetch origin main)
./report.sh deploy    # first push — should appear on the page within minutes
crontab -e            # add:
#   */5 * * * *  $HOME/ministatus/report.sh
#   @reboot      sleep 75 && $HOME/ministatus/report.sh boot
```

Then add the hostname to the `NODES` array in [`index.html`](index.html).

## Maintenance valve

Heartbeat commits accumulate (~288/day/node). If the `data` branch ever feels
heavy, squash it: check out `data`, `git checkout --orphan data-new && git commit
-m "squash heartbeats"`, force-push over `data`, re-clone on the nodes. Events
history is preserved in the `events/*.jsonl` files themselves, so nothing is lost.
