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

- **sar archives from a crash day can be corrupt and will kill a pipeline
  quietly.** One node's `sa` file from the day it was power-cycled made `sadf`
  exit non-zero with nothing on stdout; under `set -euo pipefail` with stderr
  discarded, the whole backfill died silently. Per-file `|| true` is required
  when sweeping `/var/log/sysstat/` — precisely because the machines we care
  about are the ones that crash. (observed 2026-07-22)
