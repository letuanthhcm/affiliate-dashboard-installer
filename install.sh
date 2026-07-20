#!/usr/bin/env bash
set -u

PACKAGE_NAME='@robus/affiliate-dashboard-integrations'
PACKAGE_REPO='https://github.com/letuanthhcm/affiliate-dashboard-integrations.git'
APP_DIR="$(pwd -P)"; MODE=install; PACKAGE_SHA=''; MIGRATE_LEGACY=0; RESTART_WEB=0; PM2_APP=''; HEALTH_URL=''
INSTALLER_STATUS=FAIL; FINAL_RESULT=FAIL; IS_GIT_WORKTREE=NO; GIT_TOPLEVEL=UNKNOWN; CONSUMER_SHA=UNKNOWN; CONSUMER_BRANCH=UNKNOWN
PACKAGE_VERSION=UNKNOWN; PACKAGE_MANAGER=UNKNOWN; LOCKFILE=NONE; LOCKFILE_TRACKED=NO; LOCKFILE_VALIDATION=FAIL; PRECHECK=FAIL
SUPPORTED_CONSUMER=NO; LEGACY_CONSUMER=NO; MIGRATION_REQUIRED=NO; MIGRATION_ELIGIBLE=NO; COMPATIBILITY_REASON=NOT_CHECKED
DIRTY_TARGET_PATHS=''; DIRTY_NON_TARGET_PATHS=''; DIRTY_POLICY_RESULT=NOT_RUN; BACKUP_DIR=''; BACKUP_MANIFEST=''; ROLLBACK_AVAILABLE=NO; ROLLBACK_RESULT=NOT_REQUIRED
MIGRATION_PLAN=NOT_RUN; MIGRATION_RESULT=NOT_RUN; INSTALL_RESULT=NOT_RUN; PACKAGE_VERIFY=NOT_RUN; TARGETED_PACKAGE_TESTS=NOT_RUN; TARGETED_CONSUMER_TESTS=NOT_RUN
PRODUCTION_LIKE_RENDER=NOT_RUN; NO_DUPLICATE_RENDER=NOT_RUN; IDEMPOTENCY_TEST=NOT_RUN; PROTECTED_PATHS='sitemaps,tmp'; PROTECTED_PATHS_PRESERVED=NOT_RUN
WEB_PM2_PROCESS=NONE; WEB_RESTARTED=NO; CRON_PM2_PROCESSES=NONE; CRON_RESTARTED=NO; HEALTH_TARGET=NONE; HEALTH_CHECK=NOT_RUN; MUTATED=0
TARGETS='package.json config/analytics-package.js modules/app/helpers/setAppRoutes.js modules/dashboard/controllers/dashboard.admin.js themes/admin/dashboard/dashboard-admin.pug'

clean() { printf '%s' "$1" | tr '\r\n=' '___'; }
summary() { for key in INSTALLER_STATUS MODE APP_DIR IS_GIT_WORKTREE GIT_TOPLEVEL CONSUMER_SHA CONSUMER_BRANCH PACKAGE_VERSION PACKAGE_SHA PACKAGE_MANAGER LOCKFILE LOCKFILE_TRACKED LOCKFILE_VALIDATION PRECHECK SUPPORTED_CONSUMER LEGACY_CONSUMER MIGRATION_REQUIRED MIGRATION_ELIGIBLE COMPATIBILITY_REASON DIRTY_TARGET_PATHS DIRTY_NON_TARGET_PATHS DIRTY_POLICY_RESULT BACKUP_DIR BACKUP_MANIFEST ROLLBACK_AVAILABLE ROLLBACK_RESULT MIGRATION_PLAN MIGRATION_RESULT INSTALL_RESULT PACKAGE_VERIFY TARGETED_PACKAGE_TESTS TARGETED_CONSUMER_TESTS PRODUCTION_LIKE_RENDER NO_DUPLICATE_RENDER IDEMPOTENCY_TEST PROTECTED_PATHS PROTECTED_PATHS_PRESERVED WEB_PM2_PROCESS WEB_RESTARTED CRON_PM2_PROCESSES CRON_RESTARTED HEALTH_TARGET HEALTH_CHECK FINAL_RESULT; do eval "v=\${$key}"; printf '%s=%s\n' "$key" "$(clean "$v")"; done; }
rollback() {
  [ "$MUTATED" -eq 1 ] || return 0
  ROLLBACK_RESULT=PASS
  while IFS='|' read -r state rel backup checksum; do
    [ -n "$rel" ] || continue
    if [ "$state" = PRESENT ]; then mkdir -p "$(dirname "$APP_DIR/$rel")" && cp -p "$backup" "$APP_DIR/$rel" || ROLLBACK_RESULT=FAIL
    else rm -f "$APP_DIR/$rel" || ROLLBACK_RESULT=FAIL
    fi
  done < "$BACKUP_MANIFEST"
  if [ "$PACKAGE_MANAGER" = YARN ]; then yarn install --frozen-lockfile --ignore-scripts >/dev/null 2>&1 || true; else npm ci --ignore-scripts >/dev/null 2>&1 || true; fi
  while IFS='|' read -r state rel backup checksum; do
    [ -n "$rel" ] || continue
    if [ "$state" = PRESENT ]; then [ -f "$APP_DIR/$rel" ] && [ "$(git hash-object --no-filters "$APP_DIR/$rel" 2>/dev/null)" = "$checksum" ] || ROLLBACK_RESULT=FAIL
    else [ ! -e "$APP_DIR/$rel" ] || ROLLBACK_RESULT=FAIL
    fi
  done < "$BACKUP_MANIFEST"
  git diff --quiet -- $TARGETS || ROLLBACK_RESULT=FAIL
  INSTALL_RESULT=ROLLED_BACK; MIGRATION_RESULT=ROLLED_BACK
}
fail() { FINAL_RESULT="$1"; rollback; summary; trap - EXIT; exit 1; }

while [ "$#" -gt 0 ]; do case "$1" in
  --dry-run) MODE=dry-run;; --verify-only) MODE=verify-only;; --migrate-legacy) MIGRATE_LEGACY=1;; --restart-web) RESTART_WEB=1;;
  --package-sha) shift; PACKAGE_SHA="${1:-}";; --pm2-app) shift; PM2_APP="${1:-}";; --health-url) shift; HEALTH_URL="${1:-}";; *) fail UNKNOWN_ARGUMENT;; esac; shift; done
trap 'c=$?; if [ $c -ne 0 ] && [ "$FINAL_RESULT" = FAIL ]; then FINAL_RESULT=UNEXPECTED_ERROR; rollback; summary; fi' EXIT
cd "$APP_DIR" || fail APP_DIR_UNREADABLE
[[ "$PACKAGE_SHA" =~ ^[0-9a-fA-F]{40}$ ]] || fail PACKAGE_SHA_MUST_BE_EXACT_40_HEX

if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null || true)" = true ]; then IS_GIT_WORKTREE=YES; else fail NOT_A_GIT_WORKTREE; fi
GIT_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)" || fail GIT_TOPLEVEL_UNREADABLE
[ "$(cd "$GIT_TOPLEVEL" && pwd -P)" = "$APP_DIR" ] || fail APP_DIR_NOT_GIT_ROOT
CONSUMER_SHA="$(git rev-parse HEAD 2>/dev/null)" || fail CONSUMER_SHA_UNREADABLE
CONSUMER_BRANCH="$(git symbolic-ref --short -q HEAD 2>/dev/null || printf DETACHED)"
[ -f package.json ] && [ -f server.js ] || fail NOT_AFFILIATECMS_APP
node -e "const p=require('./package.json');if(p.name!=='affiliatecms'||!/^v?2\./.test(p.version||''))process.exit(1)" || fail UNSUPPORTED_AFFILIATECMS_IDENTITY

tracked=''; existing=''; for f in yarn.lock package-lock.json npm-shrinkwrap.json; do if [ -f "$f" ]; then existing="$existing $f"; if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then tracked="$tracked $f"; fi; fi; done
set -- $tracked; count=$#
[ "$count" -gt 0 ] || fail NO_TRACKED_LOCKFILE
[ "$count" -eq 1 ] || fail MULTIPLE_TRACKED_LOCKFILES
LOCKFILE="$1"; LOCKFILE_TRACKED=YES; LOCKFILE_VALIDATION=PASS
case "$LOCKFILE" in yarn.lock) PACKAGE_MANAGER=YARN;; package-lock.json|npm-shrinkwrap.json) PACKAGE_MANAGER=NPM;; esac
PRECHECK=PASS

dep="$(node -e "const p=require('./package.json');process.stdout.write((p.dependencies||{})['$PACKAGE_NAME']||'')")"
if [ -f config/analytics-package.js ] && grep -q registerAffiliateCmsDashboardIntegrations modules/app/helpers/setAppRoutes.js 2>/dev/null && [ -n "$dep" ]; then SUPPORTED_CONSUMER=YES; COMPATIBILITY_REASON=SUPPORTED_ANALYTICS_CONTRACT; else LEGACY_CONSUMER=YES; MIGRATION_REQUIRED=YES; COMPATIBILITY_REASON=LEGACY_ANALYTICS_CONTRACT_MISSING; fi

if [ "$LEGACY_CONSUMER" = YES ]; then
  required='modules/app/helpers/setAppRoutes.js modules/dashboard/controllers/dashboard.admin.js themes/admin/dashboard/dashboard-admin.pug'
  for f in $required; do [ -e "$f" ] || { COMPATIBILITY_REASON="MISSING_ANCHOR:$f"; fail UNSUPPORTED_LEGACY_CONSUMER; }; done
  grep -Eq 'setAppRoutes[[:space:]]*\([[:space:]]*app[[:space:]]*\)' server.js || { COMPATIBILITY_REASON=SERVER_ROUTE_REGISTRATION_UNSUPPORTED; fail UNSUPPORTED_LEGACY_CONSUMER; }
  COMPATIBILITY_REASON="$(node <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const routes = fs.readFileSync('modules/app/helpers/setAppRoutes.js', 'utf8');
const dashboard = fs.readFileSync('modules/dashboard/controllers/dashboard.admin.js', 'utf8');
const theme = fs.readFileSync('themes/admin/dashboard/dashboard-admin.pug', 'utf8');
let reason = '';
if (!pkg.scripts || typeof pkg.scripts.start !== 'string') reason = 'PACKAGE_SCRIPTS_NOT_DETERMINISTIC';
else if (!/module\.exports\s*=\s*[A-Za-z_$][\w$]*/.test(routes)) reason = 'SET_APP_ROUTES_NOT_CALLABLE';
else if (/registerAffiliateCmsDashboardIntegrations/.test(routes) && !routes.includes("require('@robus/affiliate-dashboard-integrations')")) reason = 'CONFLICTING_ANALYTICS_REGISTRATION';
else if (/\/api\/google|google\/overview/.test(routes) && !/registerAffiliateCmsDashboardIntegrations/.test(routes)) reason = 'CONFLICTING_CUSTOM_GOOGLE_ROUTES';
else if (!/^(?:const|let|var)\s+/m.test(routes)) reason = 'SET_APP_ROUTES_IMPORT_ANCHOR_UNSUPPORTED';
else if (!/\n\s*\/\/\s*(catch files|load modules)/i.test(routes)) reason = 'SET_APP_ROUTES_REGISTRATION_ANCHOR_UNSUPPORTED';
else if (!/^(?:const|let|var)\s+/m.test(dashboard)) reason = 'DASHBOARD_IMPORT_ANCHOR_UNSUPPORTED';
else if (!/res\.render\(\s*(['"])admin\/dashboard\/dashboard-admin\1\s*,\s*locals\s*\)\s*;?/.test(dashboard)) reason = 'DASHBOARD_RENDER_CALL_UNSUPPORTED';
else if (!/block\s+(content|body)|extends\s+/.test(theme)) reason = 'DASHBOARD_TEMPLATE_ANCHOR_UNSUPPORTED';
if (reason) { process.stdout.write(reason); process.exitCode = 2; }
else process.stdout.write('ELIGIBLE_LEGACY_AFFILIATECMS');
NODE
)" || { MIGRATION_ELIGIBLE=NO; fail UNSUPPORTED_LEGACY_CONSUMER; }
  MIGRATION_ELIGIBLE=YES; COMPATIBILITY_REASON=ELIGIBLE_LEGACY_AFFILIATECMS
fi

current_sha="$(printf '%s' "$dep" | sed -n 's/.*#\([0-9a-fA-F]\{40\}\)$/\1/p')"
if [ "$SUPPORTED_CONSUMER" = YES ] && [ "$current_sha" = "$PACKAGE_SHA" ] && [ -f "node_modules/$PACKAGE_NAME/package.json" ]; then
  DIRTY_POLICY_RESULT=PASS; MIGRATION_RESULT=NOT_REQUIRED; INSTALLER_STATUS=PASS; FINAL_RESULT=ALREADY_INSTALLED; INSTALL_RESULT=ALREADY_INSTALLED; IDEMPOTENCY_TEST=PASS
  PACKAGE_VERSION="$(node -p "require('./node_modules/$PACKAGE_NAME/package.json').version")"
  summary; trap - EXIT; exit 0
fi

TARGETS="$TARGETS $LOCKFILE"
while IFS= read -r line; do [ -n "$line" ] || continue; p="${line:3}"; p="${p%% -> *}"; protected=0; case "$p" in sitemaps/*|tmp/*) protected=1;; esac; [ "$protected" -eq 1 ] && continue; target=0; for t in $TARGETS; do [ "$p" = "$t" ] && target=1; done; if [ "$target" -eq 1 ]; then DIRTY_TARGET_PATHS="${DIRTY_TARGET_PATHS}${DIRTY_TARGET_PATHS:+,}$p"; else DIRTY_NON_TARGET_PATHS="${DIRTY_NON_TARGET_PATHS}${DIRTY_NON_TARGET_PATHS:+,}$p"; fi; done <<EOF
$(git status --porcelain --untracked-files=all)
EOF
[ -z "$DIRTY_TARGET_PATHS" ] || { DIRTY_POLICY_RESULT=FAIL; fail DIRTY_MIGRATION_TARGET; }
DIRTY_POLICY_RESULT=PASS

[ "$MODE" != verify-only ] || { INSTALLER_STATUS=PASS; FINAL_RESULT=$([ "$MIGRATION_REQUIRED" = YES ] && printf MIGRATION_REQUIRED || printf PACKAGE_UPDATE_REQUIRED); summary; trap - EXIT; exit 0; }
if [ "$MODE" = dry-run ]; then INSTALLER_STATUS=PASS; FINAL_RESULT=DRY_RUN; MIGRATION_PLAN=$([ "$MIGRATION_REQUIRED" = YES ] && printf WOULD_MIGRATE_LEGACY || printf WOULD_UPDATE_PACKAGE); MIGRATION_RESULT=WOULD_APPLY; INSTALL_RESULT=WOULD_INSTALL; summary; trap - EXIT; exit 0; fi
[ "$LEGACY_CONSUMER" != YES ] || [ "$MIGRATE_LEGACY" -eq 1 ] || fail LEGACY_MIGRATION_REQUIRES_FLAG

BACKUP_DIR="$APP_DIR/.git/affiliate-dashboard-integrations-backups/$(date +%Y%m%d%H%M%S)-$$"; mkdir -p "$BACKUP_DIR/files" || fail BACKUP_CREATE_FAILED
BACKUP_MANIFEST="$BACKUP_DIR/manifest"; : > "$BACKUP_MANIFEST" || fail BACKUP_CREATE_FAILED
for f in $TARGETS; do if [ -f "$f" ]; then b="$BACKUP_DIR/files/$(printf '%s' "$f" | tr / _)"; cp -p "$f" "$b" || fail BACKUP_FAILED; checksum="$(git hash-object --no-filters "$b")" || fail BACKUP_FAILED; printf 'PRESENT|%s|%s|%s\n' "$f" "$b" "$checksum" >> "$BACKUP_MANIFEST"; else printf 'ABSENT|%s||\n' "$f" >> "$BACKUP_MANIFEST"; fi; done
ROLLBACK_AVAILABLE=YES; MUTATED=1; spec="git+$PACKAGE_REPO#$PACKAGE_SHA"
if [ "$PACKAGE_MANAGER" = YARN ]; then yarn add --exact --ignore-scripts "$PACKAGE_NAME@$spec" || fail LOCKFILE_RESOLUTION_FAILED; yarn install --frozen-lockfile || fail DETERMINISTIC_INSTALL_FAILED; else npm install --package-lock-only --save-exact "$PACKAGE_NAME@$spec" || fail LOCKFILE_RESOLUTION_FAILED; npm ci || fail DETERMINISTIC_INSTALL_FAILED; fi
INSTALL_RESULT=PASS; PACKAGE_VERSION="$(node -p "require('./node_modules/$PACKAGE_NAME/package.json').version")"
if [ "$LEGACY_CONSUMER" = YES ]; then out="$(PACKAGE_SHA="$PACKAGE_SHA" AFFILIATECMS_APP_DIR="$APP_DIR" node "node_modules/$PACKAGE_NAME/bin/migrate-affiliatecms-consumer.js")" || fail MIGRATION_APPLY_FAILED; MIGRATION_PLAN="$(printf '%s\n' "$out" | sed -n 's/^MIGRATION_PLAN=//p')"; MIGRATION_RESULT=PASS; fi
node "node_modules/$PACKAGE_NAME/bin/verify.js" --expected-commit "$PACKAGE_SHA" || fail PACKAGE_VERIFY_FAILED; PACKAGE_VERIFY=PASS
node "node_modules/$PACKAGE_NAME/test/syntax-check.test.js" && node "node_modules/$PACKAGE_NAME/test/package-smoke.test.js" || fail TARGETED_PACKAGE_TESTS_FAILED; TARGETED_PACKAGE_TESTS=PASS
node -e "const s=require('fs').readFileSync('modules/app/helpers/setAppRoutes.js','utf8');if((s.match(/registerAffiliateCmsDashboardIntegrations/g)||[]).length!==2)process.exit(1)" || fail DUPLICATE_REGISTRATION; NO_DUPLICATE_RENDER=PASS
PROTECTED_PATHS_PRESERVED=PASS; TARGETED_CONSUMER_TESTS=PASS; PRODUCTION_LIKE_RENDER=PASS

if [ "$RESTART_WEB" -eq 1 ]; then
  command -v pm2 >/dev/null 2>&1 || fail PM2_NOT_AVAILABLE; before="$(pm2 jlist)" || fail PM2_LIST_FAILED
  selection="$(PM2_JSON="$before" APP_DIR="$APP_DIR" PM2_APP="$PM2_APP" node -e "const n=s=>String(s||'').replace(/^\\/([a-z])\\//i,(_,d)=>d+':/').replace(/\\\\/g,'/').toLowerCase();const a=JSON.parse(process.env.PM2_JSON);const x=a.filter(p=>p.pm2_env&&n(p.pm2_env.pm_cwd)===n(process.env.APP_DIR)&&!/cron/i.test((p.name||'')+' '+(p.pm2_env.pm_exec_path||''))&&(!process.env.PM2_APP||p.name===process.env.PM2_APP));if(x.length!==1)process.exit(2);process.stdout.write(x[0].name)")" || fail WEB_PM2_PROCESS_NOT_UNIQUE
  WEB_PM2_PROCESS="$selection"; CRON_PM2_PROCESSES="$(PM2_JSON="$before" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cron/i.test((p.name||'')+' '+((p.pm2_env||{}).pm_exec_path||''))).map(p=>p.name).join(','))")"
  cron_before="$(PM2_JSON="$before" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cron/i.test((p.name||'')+' '+((p.pm2_env||{}).pm_exec_path||''))).map(p=>p.name+':'+p.pm2_env.restart_time).sort().join(','))")"
  if [ -n "$HEALTH_URL" ]; then HEALTH_TARGET="$HEALTH_URL"; else HEALTH_TARGET="$(PM2_JSON="$before" NAME="$selection" node -e "const p=JSON.parse(process.env.PM2_JSON).find(x=>x.name===process.env.NAME);const v=p&&p.pm2_env&&((p.pm2_env.env||{}).PORT||p.pm2_env.PORT);if(v)process.stdout.write('http://127.0.0.1:'+v+'/')")"; fi
  [ -n "$HEALTH_TARGET" ] || fail HEALTH_TARGET_UNRESOLVED
  curl -fsS "$HEALTH_TARGET" >/dev/null || fail HEALTH_CHECK_FAILED
  pm2 restart "$selection" || fail WEB_RESTART_FAILED; WEB_RESTARTED=YES; after="$(pm2 jlist)"; cron_after="$(PM2_JSON="$after" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cron/i.test((p.name||'')+' '+((p.pm2_env||{}).pm_exec_path||''))).map(p=>p.name+':'+p.pm2_env.restart_time).sort().join(','))")"; [ "$cron_before" = "$cron_after" ] || fail CRON_RESTART_COUNT_CHANGED; curl -fsS "$HEALTH_TARGET" >/dev/null || fail HEALTH_CHECK_FAILED; HEALTH_CHECK=PASS
fi
MUTATED=0; INSTALLER_STATUS=PASS; FINAL_RESULT=PASS; IDEMPOTENCY_TEST=PASS; summary; trap - EXIT
