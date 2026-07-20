#!/usr/bin/env bash
set -u

PACKAGE_NAME="@robus/affiliate-dashboard-integrations"
PACKAGE_REPO="https://github.com/letuanthhcm/affiliate-dashboard-integrations.git"
MODE="install"
PACKAGE_SHA=""
RESTART_WEB=0
PM2_APP=""
APP_DIR="$(pwd -P)"
STATUS="FAIL"
FINAL_RESULT="FAIL"
PACKAGE_MANAGER="UNKNOWN"
LOCKFILE="NONE"
LOCKFILE_VALIDATION="FAIL"
PRECHECK="FAIL"
INSTALL_RESULT="NOT_RUN"
PACKAGE_VERIFY="NOT_RUN"
TARGETED_PACKAGE_TESTS="NOT_RUN"
TARGETED_CONSUMER_TESTS="NOT_RUN"
PRODUCTION_LIKE_RENDER="NOT_RUN"
IDEMPOTENCY_TEST="NOT_RUN"
PROTECTED_PATHS="sitemaps,tmp"
WEB_PM2_PROCESS="NONE"
WEB_RESTARTED="NO"
CRON_PM2_PROCESS="NONE"
CRON_RESTARTED="NO"
HEALTH_CHECK="NOT_RUN"
ROLLBACK_AVAILABLE="NO"
CONSUMER_SHA="UNKNOWN"
PACKAGE_VERSION="UNKNOWN"
BACKUP_DIR=""
MUTATED=0

say() { printf '%s\n' "$*" >&2; }
value() { printf '%s' "$1" | tr '\r\n=' '___'; }
summary() {
  printf 'INSTALLER_STATUS=%s\n' "$(value "$STATUS")"
  printf 'MODE=%s\n' "$(value "$MODE")"
  printf 'APP_DIR=%s\n' "$(value "$APP_DIR")"
  printf 'CONSUMER_SHA=%s\n' "$(value "$CONSUMER_SHA")"
  printf 'PACKAGE_VERSION=%s\n' "$(value "$PACKAGE_VERSION")"
  printf 'PACKAGE_SHA=%s\n' "$(value "${PACKAGE_SHA:-UNKNOWN}")"
  printf 'PACKAGE_MANAGER=%s\n' "$PACKAGE_MANAGER"
  printf 'LOCKFILE=%s\n' "$LOCKFILE"
  printf 'LOCKFILE_VALIDATION=%s\n' "$LOCKFILE_VALIDATION"
  printf 'PRECHECK=%s\n' "$PRECHECK"
  printf 'INSTALL_RESULT=%s\n' "$INSTALL_RESULT"
  printf 'PACKAGE_VERIFY=%s\n' "$PACKAGE_VERIFY"
  printf 'TARGETED_PACKAGE_TESTS=%s\n' "$TARGETED_PACKAGE_TESTS"
  printf 'TARGETED_CONSUMER_TESTS=%s\n' "$TARGETED_CONSUMER_TESTS"
  printf 'PRODUCTION_LIKE_RENDER=%s\n' "$PRODUCTION_LIKE_RENDER"
  printf 'IDEMPOTENCY_TEST=%s\n' "$IDEMPOTENCY_TEST"
  printf 'PROTECTED_PATHS=%s\n' "$PROTECTED_PATHS"
  printf 'WEB_PM2_PROCESS=%s\n' "$WEB_PM2_PROCESS"
  printf 'WEB_RESTARTED=%s\n' "$WEB_RESTARTED"
  printf 'CRON_PM2_PROCESS=%s\n' "$CRON_PM2_PROCESS"
  printf 'CRON_RESTARTED=%s\n' "$CRON_RESTARTED"
  printf 'HEALTH_CHECK=%s\n' "$HEALTH_CHECK"
  printf 'ROLLBACK_AVAILABLE=%s\n' "$ROLLBACK_AVAILABLE"
  printf 'FINAL_RESULT=%s\n' "$(value "$FINAL_RESULT")"
}
rollback() {
  [ "$MUTATED" -eq 1 ] || return 0
  say "Rolling back package manifest and lockfile"
  cp "$BACKUP_DIR/package.json" "$APP_DIR/package.json" || true
  cp "$BACKUP_DIR/$LOCKFILE" "$APP_DIR/$LOCKFILE" || true
  [ ! -f "$BACKUP_DIR/analytics-package.js" ] || cp "$BACKUP_DIR/analytics-package.js" "$APP_DIR/config/analytics-package.js" || true
  if [ "$PACKAGE_MANAGER" = yarn ]; then yarn install --frozen-lockfile --ignore-scripts >/dev/null 2>&1 || true; else npm ci --ignore-scripts >/dev/null 2>&1 || true; fi
  INSTALL_RESULT="ROLLED_BACK"
}
fail() { FINAL_RESULT="$1"; rollback; summary; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --verify-only) MODE="verify-only" ;;
    --restart-web) RESTART_WEB=1 ;;
    --package-sha) shift; PACKAGE_SHA="${1:-}" ;;
    --pm2-app) shift; PM2_APP="${1:-}" ;;
    *) say "Unknown argument: $1"; summary; exit 2 ;;
  esac
  shift
done

trap 'code=$?; if [ $code -ne 0 ] && [ "$FINAL_RESULT" = FAIL ]; then FINAL_RESULT="UNEXPECTED_ERROR"; rollback; summary; fi' EXIT
cd "$APP_DIR" || fail "APP_DIR_UNREADABLE"
[[ "$PACKAGE_SHA" =~ ^[0-9a-fA-F]{40}$ ]] || fail "PACKAGE_SHA_MUST_BE_EXACT_40_HEX"
[ -f package.json ] && [ -f server.js ] || fail "NOT_AFFILIATECMS_APP"
node -e "const p=require('./package.json');if(p.name!=='affiliatecms'||!/^v?2\./.test(p.version||''))process.exit(1)" || fail "UNSUPPORTED_AFFILIATECMS_IDENTITY"
[ -f modules/app/helpers/setAppRoutes.js ] && grep -q 'registerAffiliateCmsDashboardIntegrations' modules/app/helpers/setAppRoutes.js || fail "ANALYTICS_REGISTRATION_PATH_MISSING"
[ -f config/analytics-package.js ] || fail "ANALYTICS_CONFIG_MISSING"

has_yarn=0; has_npm=0; [ -f yarn.lock ] && has_yarn=1; [ -f package-lock.json ] && has_npm=1
[ $((has_yarn + has_npm)) -eq 1 ] || fail "EXACTLY_ONE_LOCKFILE_REQUIRED"
if [ "$has_yarn" -eq 1 ]; then PACKAGE_MANAGER=yarn; LOCKFILE=yarn.lock; git ls-files --error-unmatch yarn.lock >/dev/null 2>&1 || fail "LOCKFILE_NOT_GIT_TRACKED"; else PACKAGE_MANAGER=npm; LOCKFILE=package-lock.json; git ls-files --error-unmatch package-lock.json >/dev/null 2>&1 || fail "LOCKFILE_NOT_GIT_TRACKED"; fi
LOCKFILE_VALIDATION=PASS
CONSUMER_SHA="$(git rev-parse HEAD 2>/dev/null || printf UNKNOWN)"
current_sha="$(node -e "const p=require('./package.json');const s=(p.dependencies||{})['$PACKAGE_NAME']||'';const m=s.match(/#([0-9a-f]{40})$/i);process.stdout.write(m?m[1]:'')")"
if [ "$current_sha" = "$PACKAGE_SHA" ] && [ -f "node_modules/$PACKAGE_NAME/package.json" ]; then
  dirty="$(git status --porcelain --untracked-files=all | awk '{p=substr($0,4); if (p !~ /^(sitemaps|tmp)(\/|$)/ && p != "package.json" && p != "config/analytics-package.js" && p != "'"$LOCKFILE"'" ) print}')"
else
  dirty="$(git status --porcelain --untracked-files=all | awk '{p=substr($0,4); if (p !~ /^(sitemaps|tmp)(\/|$)/) print}')"
fi
[ -z "$dirty" ] || { say "$dirty"; fail "UNRELATED_DIRTY_WORKTREE"; }
PRECHECK=PASS

if [ "$current_sha" = "$PACKAGE_SHA" ] && [ -f "node_modules/$PACKAGE_NAME/package.json" ]; then
  PACKAGE_VERSION="$(node -p "require('./node_modules/$PACKAGE_NAME/package.json').version")"
  STATUS=ALREADY_INSTALLED; INSTALL_RESULT=ALREADY_INSTALLED; IDEMPOTENCY_TEST=PASS
else
  [ "$MODE" != verify-only ] || fail "REQUESTED_SHA_NOT_INSTALLED"
  if [ "$MODE" = dry-run ]; then STATUS=DRY_RUN; INSTALL_RESULT=WOULD_INSTALL; FINAL_RESULT=PASS; summary; trap - EXIT; exit 0; fi
  BACKUP_DIR=".git/affiliate-dashboard-integrations-backups/$(date +%Y%m%d%H%M%S)-$$"
  mkdir -p "$BACKUP_DIR" || fail "BACKUP_CREATE_FAILED"
  cp package.json "$BACKUP_DIR/package.json" && cp "$LOCKFILE" "$BACKUP_DIR/$LOCKFILE" || fail "BACKUP_FAILED"
  cp config/analytics-package.js "$BACKUP_DIR/analytics-package.js" || fail "BACKUP_FAILED"
  printf '%s\n' "$CONSUMER_SHA" > "$BACKUP_DIR/consumer.sha"
  printf '%s\n' "$current_sha" > "$BACKUP_DIR/package.sha"
  ROLLBACK_AVAILABLE=YES
  MUTATED=1
  spec="git+${PACKAGE_REPO}#${PACKAGE_SHA}"
  if [ "$PACKAGE_MANAGER" = yarn ]; then
    yarn add --exact --ignore-scripts "$PACKAGE_NAME@$spec" || fail "LOCKFILE_RESOLUTION_FAILED"
    yarn install --frozen-lockfile || fail "DETERMINISTIC_INSTALL_FAILED"
  else
    npm install --package-lock-only --save-exact "$PACKAGE_NAME@$spec" || fail "LOCKFILE_RESOLUTION_FAILED"
    npm ci || fail "DETERMINISTIC_INSTALL_FAILED"
  fi
  INSTALL_RESULT=PASS
fi

PACKAGE_VERSION="$(node -p "require('./node_modules/$PACKAGE_NAME/package.json').version")"
if [ "$MODE" != verify-only ]; then
PACKAGE_VERSION="$PACKAGE_VERSION" PACKAGE_SHA="$PACKAGE_SHA" node - <<'NODE' || fail "ANALYTICS_CONFIG_UPDATE_FAILED"
const fs = require('fs');
const file = 'config/analytics-package.js';
let source = fs.readFileSync(file, 'utf8');
const block = /diagnostics\s*:\s*\{[\s\S]*?\}/m;
const found = source.match(block);
if (!found) process.exit(2);
let replacement = found[0].replace(/[0-9a-f]{40}/ig, process.env.PACKAGE_SHA);
replacement = replacement.replace(/(['"])v?\d+\.\d+\.\d+\1/g, (value, quote) => `${quote}${value.includes(`${quote}v`) ? 'v' : ''}${process.env.PACKAGE_VERSION}${quote}`);
const next = source.replace(block, replacement);
if (next !== source) fs.writeFileSync(file, next);
NODE
fi

node "node_modules/$PACKAGE_NAME/bin/verify.js" --expected-commit "$PACKAGE_SHA" || fail "PACKAGE_VERIFY_FAILED"
PACKAGE_VERIFY=PASS
node "node_modules/$PACKAGE_NAME/test/syntax-check.test.js" && node "node_modules/$PACKAGE_NAME/test/package-smoke.test.js" || fail "TARGETED_PACKAGE_TESTS_FAILED"
TARGETED_PACKAGE_TESTS=PASS
node config/analytics-package.test.js && node scripts/analytics-package.smoke.test.js && node modules/app/helpers/analytics-package.register.test.js || fail "TARGETED_CONSUMER_TESTS_FAILED"
TARGETED_CONSUMER_TESTS=PASS
node scripts/google-analytics-production-like.test.js || fail "PRODUCTION_LIKE_RENDER_FAILED"
PRODUCTION_LIKE_RENDER=PASS
IDEMPOTENCY_TEST=PASS

if [ "$RESTART_WEB" -eq 1 ]; then
  command -v pm2 >/dev/null 2>&1 || fail "PM2_NOT_AVAILABLE"
  before="$(pm2 jlist)"
  selection="$(PM2_JSON="$before" APP_DIR="$APP_DIR" PM2_APP="$PM2_APP" node -e "const n=s=>String(s||'').replace(/^\\/([a-z])\\//i,(_,d)=>d+':/').replace(/\\\\/g,'/').toLowerCase();const a=JSON.parse(process.env.PM2_JSON);const x=a.filter(p=>p.pm2_env&&n(p.pm2_env.pm_cwd)===n(process.env.APP_DIR)&&!/cronjobs/i.test(p.name||'')&&(!process.env.PM2_APP||p.name===process.env.PM2_APP));if(x.length!==1)process.exit(2);process.stdout.write(x[0].name)")" || fail "WEB_PM2_PROCESS_NOT_UNIQUE"
  WEB_PM2_PROCESS="$selection"
  CRON_PM2_PROCESS="$(PM2_JSON="$before" APP_DIR="$APP_DIR" node -e "const n=s=>String(s||'').replace(/^\\/([a-z])\\//i,(_,d)=>d+':/').replace(/\\\\/g,'/').toLowerCase();const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>p.pm2_env&&n(p.pm2_env.pm_cwd)===n(process.env.APP_DIR)&&/cronjobs/i.test(p.name||'')).map(p=>p.name).join(','))")"
  cron_counts="$(PM2_JSON="$before" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cronjobs/i.test(p.name||'')).map(p=>p.name+':'+p.pm2_env.restart_time).sort().join(','))")"
  pm2 restart "$selection" || fail "WEB_RESTART_FAILED"
  WEB_RESTARTED=YES
  after="$(pm2 jlist)"
  after_cron="$(PM2_JSON="$after" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cronjobs/i.test(p.name||'')).map(p=>p.name+':'+p.pm2_env.restart_time).sort().join(','))")"
  [ "$cron_counts" = "$after_cron" ] || fail "CRON_RESTART_COUNT_CHANGED"
  port="$(PM2_JSON="$after" NAME="$selection" node -e "const p=JSON.parse(process.env.PM2_JSON).find(x=>x.name===process.env.NAME);const v=p&&p.pm2_env&&p.pm2_env.env&&p.pm2_env.env.PORT;if(!v)process.exit(2);process.stdout.write(String(v))")" || fail "RUNTIME_PORT_UNREADABLE"
  curl -fsS "http://127.0.0.1:$port/" >/dev/null || fail "HEALTH_CHECK_FAILED"
  HEALTH_CHECK=PASS
fi

STATUS="${STATUS/PASS/INSTALLED}"
[ "$STATUS" = FAIL ] && STATUS=INSTALLED
FINAL_RESULT=PASS
MUTATED=0
summary
trap - EXIT
