# AffiliateCMS analytics installer

Run the immutable raw `install.sh` URL from the AffiliateCMS Git root with an exact 40-character package SHA.

Modes and controls:

- `--verify-only` reports readiness and migration eligibility without mutation.
- `--dry-run` prints the complete planned action without mutation.
- `--migrate-legacy` authorizes migration only after structural eligibility and target-aware dirty checks pass.
- `--restart-web` authorizes restart of exactly one PM2 web process whose `pm_cwd` equals the app root; cron processes are excluded and their restart counters are verified unchanged.
- `--pm2-app NAME` resolves an otherwise ambiguous exact web process name.
- `--health-url URL` supplies an explicit local health target when it cannot be uniquely inferred from PM2.

The installer never resets the worktree, creates a lockfile, restarts cron, runs Google sync, changes a database, changes nginx, or changes a port. `sitemaps/` and `tmp/` are protected runtime paths. Failures after mutation restore every declared target from the timestamped manifest and do not restart PM2.
