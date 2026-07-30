# Operational experience

Empirical facts about how this system actually behaves, earned by running it —
not derivable from reading the code. See README for what the system *is*.

- **raw.githubusercontent.com caches for ~5 minutes and ignores query-string
  cache-busters.** `?x=<timestamp>` does not force a fresh copy; content updates
  simply surface when the CDN entry expires. Any consumer of the data branch
  (the page, scripts, humans checking "did my push land") must tolerate a ~5 min
  lag — and freshness thresholds must budget for it on top of the heartbeat
  interval. (observed 2026-07-22)

- **GitHub Pages builds queue noticeably when you push often.** Normally a push
  deploys in well under a minute, but after ~6 pushes to the Pages branch within
  an hour, a build sat in `status: building` for several minutes (soft limit is
  ~10 builds/hour). This is why heartbeat data lives on a separate `data` branch:
  288 pushes/day against the Pages branch would throttle site deploys
  permanently. (observed 2026-07-22)

- **A hard crash can corrupt the reporter's own git clone — and reporting then
  fails silently forever.** mini01's crash on 2026-07-24 left a truncated object
  in `~/ministatus/.git` (`object file … is empty`, `fatal: bad object HEAD`);
  every cron run after that — including `@reboot` — died instantly, so the node
  showed "not reporting" for a week while being perfectly healthy. Telltale
  signature on the data branch: missed beats, then several `hb` commits stamped
  in the same second (queued cron runs on the dying machine), then silence.
  `report.sh` now self-heals: on any git read failure it quarantines the clone
  as `<dir>.corrupt-<ts>`, re-clones, and logs a `selfheal` event. (observed
  2026-07-30)

- **sar archives from a crash day can be corrupt and will kill a pipeline
  quietly.** One node's `sa` file from the day it was power-cycled made `sadf`
  exit non-zero with nothing on stdout; under `set -euo pipefail` with stderr
  discarded, the whole backfill died silently. Per-file `|| true` is required
  when sweeping `/var/log/sysstat/` — precisely because the machines we care
  about are the ones that crash. (observed 2026-07-22)
