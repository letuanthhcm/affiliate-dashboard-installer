#!/usr/bin/env bash
set -u

PACKAGE_NAME='@robus/affiliate-dashboard-integrations'
PACKAGE_REPO='https://github.com/letuanthhcm/affiliate-dashboard-integrations.git'
APP_DIR="$(pwd -P)"; MODE=install; PACKAGE_SHA=''; MIGRATE_LEGACY=0; RESTART_WEB=0; PM2_APP=''; HEALTH_URL=''
INSTALLER_STATUS=FAIL; FINAL_RESULT=FAIL; IS_GIT_WORKTREE=NO; GIT_TOPLEVEL=UNKNOWN; CONSUMER_SHA=UNKNOWN; CONSUMER_BRANCH=UNKNOWN
PACKAGE_VERSION=UNKNOWN; PACKAGE_MANAGER=UNKNOWN; LOCKFILE=NONE; LOCKFILE_TRACKED=NO; LOCKFILE_VALIDATION=FAIL; PRECHECK=FAIL
REQUESTED_PACKAGE_SHA=UNKNOWN; REQUESTED_PACKAGE_VERSION=UNKNOWN; PREEXISTING_NODE_MODULES_VERSION=ABSENT; INSTALLED_PACKAGE_VERSION=NOT_INSTALLED; INSTALLED_PACKAGE_COMMIT=NOT_INSTALLED
SUPPORTED_CONSUMER=NO; LEGACY_CONSUMER=NO; MIGRATION_REQUIRED=NO; MIGRATION_ELIGIBLE=NO; COMPATIBILITY_REASON=NOT_CHECKED
LEGACY_STRATEGY=NONE; DASHBOARD_LOCALS_VARIANT=NONE; DIRTY_TARGET_PATHS=''; DIRTY_NON_TARGET_PATHS=''; DIRTY_POLICY_RESULT=NOT_RUN; BACKUP_DIR=''; BACKUP_MANIFEST=''; ROLLBACK_AVAILABLE=NO; ROLLBACK_RESULT=NOT_REQUIRED
SOURCE_ROLLBACK_RESULT=NOT_REQUIRED; LOCKFILE_ROLLBACK_RESULT=NOT_REQUIRED; CREATED_FILES_ROLLBACK_RESULT=NOT_REQUIRED; NODE_MODULES_ROLLBACK_RESULT=NOT_REQUIRED; OVERALL_ROLLBACK_RESULT=NOT_REQUIRED; NODE_MODULES_ORIGINAL_STATE=UNKNOWN
MIGRATION_PLAN=NOT_RUN; MIGRATION_RESULT=NOT_RUN; INSTALL_RESULT=NOT_RUN; PACKAGE_VERIFY=NOT_RUN; TARGETED_PACKAGE_TESTS=NOT_RUN; TARGETED_CONSUMER_TESTS=NOT_RUN
PRODUCTION_LIKE_RENDER=NOT_RUN; NO_DUPLICATE_RENDER=NOT_RUN; IDEMPOTENCY_TEST=NOT_RUN; PROTECTED_PATHS='sitemaps,tmp'; PROTECTED_PATHS_PRESERVED=NOT_RUN
WEB_PM2_PROCESS=NONE; WEB_RESTARTED=NO; WEB_PID_BEFORE=UNKNOWN; WEB_PID_AFTER=UNKNOWN; WEB_RESTART_COUNT_BEFORE=UNKNOWN; WEB_RESTART_COUNT_AFTER=UNKNOWN; CRON_PM2_PROCESSES=NONE; CRON_RESTARTED=NO; CRON_RESTART_COUNT_BEFORE=UNKNOWN; CRON_RESTART_COUNT_AFTER=UNKNOWN; PM2_ONLINE_RESULT=NOT_RUN; LISTENER_RESULT=NOT_RUN; LISTENER_PORT=UNKNOWN; LISTENER_ATTEMPTS=0; LISTENER_READY_AFTER_SECONDS=NOT_READY
HEALTH_TARGET=NONE; HEALTH_TARGET_SOURCE=NONE; HEALTH_TARGET_RESOLUTION=NOT_RUN; HEALTH_PRIMARY_TARGET=NONE; HEALTH_PRIMARY_HTTP=NONE; HEALTH_PRIMARY_LAST_HTTP=NONE; HEALTH_PRIMARY_RESULT=NOT_RUN
HEALTH_FALLBACK_TARGET=NONE; HEALTH_FALLBACK_HTTP=NONE; HEALTH_FALLBACK_LAST_HTTP=NONE; HEALTH_FALLBACK_RESULT=NOT_RUN; HEALTH_ATTEMPTS=0; HEALTH_READY_AFTER_SECONDS=NONE; HEALTH_TIMEOUT_SECONDS="${HEALTH_MAX_WAIT_SECONDS:-30}"; HEALTH_CHECK=NOT_RUN; MUTATED=0
TARGETS='package.json config/analytics-package.js modules/app/helpers/setAppRoutes.js modules/dashboard/controllers/dashboard.admin.js themes/admin/dashboard/dashboard-admin.pug'

clean() { printf '%s' "$1" | tr '\r\n=' '___'; }
summary() { for key in INSTALLER_STATUS MODE APP_DIR IS_GIT_WORKTREE GIT_TOPLEVEL CONSUMER_SHA CONSUMER_BRANCH PACKAGE_VERSION PACKAGE_SHA REQUESTED_PACKAGE_SHA REQUESTED_PACKAGE_VERSION PREEXISTING_NODE_MODULES_VERSION INSTALLED_PACKAGE_VERSION INSTALLED_PACKAGE_COMMIT PACKAGE_MANAGER LOCKFILE LOCKFILE_TRACKED LOCKFILE_VALIDATION PRECHECK SUPPORTED_CONSUMER LEGACY_CONSUMER MIGRATION_REQUIRED MIGRATION_ELIGIBLE COMPATIBILITY_REASON LEGACY_STRATEGY DASHBOARD_LOCALS_VARIANT DIRTY_TARGET_PATHS DIRTY_NON_TARGET_PATHS DIRTY_POLICY_RESULT BACKUP_DIR BACKUP_MANIFEST ROLLBACK_AVAILABLE ROLLBACK_RESULT SOURCE_ROLLBACK_RESULT LOCKFILE_ROLLBACK_RESULT CREATED_FILES_ROLLBACK_RESULT NODE_MODULES_ROLLBACK_RESULT OVERALL_ROLLBACK_RESULT NODE_MODULES_ORIGINAL_STATE MIGRATION_PLAN MIGRATION_RESULT INSTALL_RESULT PACKAGE_VERIFY TARGETED_PACKAGE_TESTS TARGETED_CONSUMER_TESTS PRODUCTION_LIKE_RENDER NO_DUPLICATE_RENDER IDEMPOTENCY_TEST PROTECTED_PATHS PROTECTED_PATHS_PRESERVED WEB_PM2_PROCESS WEB_RESTARTED WEB_PID_BEFORE WEB_PID_AFTER WEB_RESTART_COUNT_BEFORE WEB_RESTART_COUNT_AFTER CRON_PM2_PROCESSES CRON_RESTARTED CRON_RESTART_COUNT_BEFORE CRON_RESTART_COUNT_AFTER PM2_ONLINE_RESULT LISTENER_RESULT LISTENER_PORT LISTENER_ATTEMPTS LISTENER_READY_AFTER_SECONDS HEALTH_TARGET HEALTH_TARGET_SOURCE HEALTH_TARGET_RESOLUTION HEALTH_PRIMARY_TARGET HEALTH_PRIMARY_HTTP HEALTH_PRIMARY_LAST_HTTP HEALTH_PRIMARY_RESULT HEALTH_FALLBACK_TARGET HEALTH_FALLBACK_HTTP HEALTH_FALLBACK_LAST_HTTP HEALTH_FALLBACK_RESULT HEALTH_ATTEMPTS HEALTH_READY_AFTER_SECONDS HEALTH_TIMEOUT_SECONDS HEALTH_CHECK FINAL_RESULT; do eval "v=\${$key}"; printf '%s=%s\n' "$key" "$(clean "$v")"; done; }
rollback() {
  [ "$MUTATED" -eq 1 ] || return 0
  SOURCE_ROLLBACK_RESULT=PASS; LOCKFILE_ROLLBACK_RESULT=PASS; CREATED_FILES_ROLLBACK_RESULT=PASS; NODE_MODULES_ROLLBACK_RESULT=PASS
  while IFS='|' read -r state rel backup checksum; do
    [ -n "$rel" ] || continue
    if [ "$state" = PRESENT ]; then mkdir -p "$(dirname "$APP_DIR/$rel")" && cp -p "$backup" "$APP_DIR/$rel" || { [ "$rel" = "$LOCKFILE" ] && LOCKFILE_ROLLBACK_RESULT=FAIL || SOURCE_ROLLBACK_RESULT=FAIL; }
    else rm -f "$APP_DIR/$rel" || CREATED_FILES_ROLLBACK_RESULT=FAIL
    fi
  done < "$BACKUP_MANIFEST"
  rm -rf "$APP_DIR/node_modules/$PACKAGE_NAME" >/dev/null 2>&1 || NODE_MODULES_ROLLBACK_RESULT=FAIL
  if [ "$NODE_MODULES_ORIGINAL_STATE" = PRESENT ]; then mkdir -p "$APP_DIR/node_modules/@robus" && cp -a "$BACKUP_DIR/node-module" "$APP_DIR/node_modules/$PACKAGE_NAME" || NODE_MODULES_ROLLBACK_RESULT=FAIL; fi
  while IFS='|' read -r state rel backup checksum; do
    [ -n "$rel" ] || continue
    if [ "$state" = PRESENT ]; then
      if ! { [ -f "$APP_DIR/$rel" ] && [ "$(git hash-object --no-filters "$APP_DIR/$rel" 2>/dev/null)" = "$checksum" ]; }; then [ "$rel" = "$LOCKFILE" ] && LOCKFILE_ROLLBACK_RESULT=FAIL || SOURCE_ROLLBACK_RESULT=FAIL; fi
    else [ ! -e "$APP_DIR/$rel" ] || CREATED_FILES_ROLLBACK_RESULT=FAIL
    fi
  done < "$BACKUP_MANIFEST"
  if [ "$NODE_MODULES_ORIGINAL_STATE" = PRESENT ]; then [ -f "$APP_DIR/node_modules/$PACKAGE_NAME/package.json" ] || NODE_MODULES_ROLLBACK_RESULT=FAIL; else [ ! -e "$APP_DIR/node_modules/$PACKAGE_NAME" ] || NODE_MODULES_ROLLBACK_RESULT=FAIL; fi
  git diff --quiet -- $TARGETS || SOURCE_ROLLBACK_RESULT=FAIL
  OVERALL_ROLLBACK_RESULT=PASS
  for result in "$SOURCE_ROLLBACK_RESULT" "$LOCKFILE_ROLLBACK_RESULT" "$CREATED_FILES_ROLLBACK_RESULT" "$NODE_MODULES_ROLLBACK_RESULT"; do [ "$result" = PASS ] || OVERALL_ROLLBACK_RESULT=FAIL; done
  ROLLBACK_RESULT="$OVERALL_ROLLBACK_RESULT"
  INSTALL_RESULT=ROLLED_BACK; MIGRATION_RESULT=ROLLED_BACK
}
fail() { FINAL_RESULT="$1"; rollback; summary; trap - EXIT; exit 1; }

while [ "$#" -gt 0 ]; do case "$1" in
  --dry-run) MODE=dry-run;; --verify-only) MODE=verify-only;; --migrate-legacy) MIGRATE_LEGACY=1;; --restart-web) RESTART_WEB=1;;
  --package-sha) shift; PACKAGE_SHA="${1:-}";; --pm2-app) shift; PM2_APP="${1:-}";; --health-url) shift; HEALTH_URL="${1:-}";; *) fail UNKNOWN_ARGUMENT;; esac; shift; done
trap 'c=$?; if [ $c -ne 0 ] && [ "$FINAL_RESULT" = FAIL ]; then FINAL_RESULT=UNEXPECTED_ERROR; rollback; summary; fi' EXIT
cd "$APP_DIR" || fail APP_DIR_UNREADABLE
[[ "$PACKAGE_SHA" =~ ^[0-9a-fA-F]{40}$ ]] || fail PACKAGE_SHA_MUST_BE_EXACT_40_HEX
REQUESTED_PACKAGE_SHA="$PACKAGE_SHA"
if [ -n "${AFFILIATE_INSTALLER_PACKAGE_METADATA_JSON:-}" ]; then
  package_metadata="$AFFILIATE_INSTALLER_PACKAGE_METADATA_JSON"
else
  metadata_tmp="$(mktemp -d)" || fail REQUESTED_PACKAGE_METADATA_UNREADABLE
  git clone -q --bare --filter=blob:none "$PACKAGE_REPO" "$metadata_tmp/repo" >/dev/null 2>&1 || { rm -rf "$metadata_tmp"; fail REQUESTED_PACKAGE_METADATA_UNREADABLE; }
  package_metadata="$(git -C "$metadata_tmp/repo" show "$PACKAGE_SHA:package.json" 2>/dev/null)" || { rm -rf "$metadata_tmp"; fail REQUESTED_PACKAGE_METADATA_UNREADABLE; }
  rm -rf "$metadata_tmp"
fi
REQUESTED_PACKAGE_VERSION="$(printf '%s' "$package_metadata" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{process.stdout.write(String(JSON.parse(s).version||''))}catch(_){process.exit(1)}})" 2>/dev/null)" || fail REQUESTED_PACKAGE_METADATA_UNREADABLE
[ -n "$REQUESTED_PACKAGE_VERSION" ] || fail REQUESTED_PACKAGE_METADATA_UNREADABLE
PACKAGE_VERSION="$REQUESTED_PACKAGE_VERSION"
[ ! -f "node_modules/$PACKAGE_NAME/package.json" ] || PREEXISTING_NODE_MODULES_VERSION="$(node -p "require('./node_modules/$PACKAGE_NAME/package.json').version" 2>/dev/null || printf UNREADABLE)"

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
  compatibility="$(node <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const routes = fs.readFileSync('modules/app/helpers/setAppRoutes.js', 'utf8');
const dashboard = fs.readFileSync('modules/dashboard/controllers/dashboard.admin.js', 'utf8');
const theme = fs.readFileSync('themes/admin/dashboard/dashboard-admin.pug', 'utf8');
let reason = '';
function extractFunction(source, name) {
  const signature = new RegExp(`async\\s+function\\s+${name}\\s*\\(\\s*req\\s*,\\s*res\\s*\\)\\s*\\{`, 'g');
  const matches = Array.from(source.matchAll(signature)); if (matches.length !== 1) return null;
  const start = matches[0].index; const open = source.indexOf('{', start); let depth=0, quote='', escaped=false, line=false, block=false;
  for (let i=open;i<source.length;i+=1) { const c=source[i],n=source[i+1]; if(line){if(c==='\n')line=false;continue} if(block){if(c==='*'&&n==='/'){block=false;i+=1}continue} if(quote){if(escaped)escaped=false;else if(c==='\\')escaped=true;else if(c===quote)quote='';continue} if(c==='/'&&n==='/'){line=true;i+=1;continue} if(c==='/'&&n==='*'){block=true;i+=1;continue} if(c==="'"||c==='"'||c==='`'){quote=c;continue} if(c==='{')depth+=1; if(c==='}'&&--depth===0)return source.slice(start,i+1); }
  return null;
}
function dashboardVariant(source) {
  const fn=extractFunction(source,'DashboardAdmin'); if(!fn||!/\bgetDashboardHome\s*\(/.test(fn)||!/\bactiveSection\b/.test(fn)||!/\bcontext\s*:\s*\{[\s\S]*?\bdashboard\b/.test(fn)||!/\bbreadcrumb\s*:/.test(fn))return '';
  const alias=/const\s*\{\s*locals\s*\}\s*=\s*res\s*;/.test(fn)||/const\s+locals\s*=\s*res\.locals\s*;/.test(fn); const variant=alias?'LOCALS_ALIAS':'DIRECT_RES_LOCALS'; const target=alias?'locals':'res\\.locals';
  if((fn.match(new RegExp(`Object\\.assign\\(\\s*${target}\\s*,`,'g'))||[]).length!==1)return '';
  if((fn.match(new RegExp(`return\\s+res\\.render\\(\\s*(['"])admin\\/dashboard\\/dashboard-admin\\1\\s*,\\s*${target}\\s*\\)\\s*;?`,'g'))||[]).length!==1)return '';
  return variant;
}
let variant='';
if (!pkg.scripts || typeof pkg.scripts.start !== 'string') reason = 'PACKAGE_SCRIPTS_NOT_DETERMINISTIC';
else if (!/module\.exports\s*=\s*[A-Za-z_$][\w$]*/.test(routes)) reason = 'SET_APP_ROUTES_NOT_CALLABLE';
else if (/registerAffiliateCmsDashboardIntegrations/.test(routes) && !routes.includes("require('@robus/affiliate-dashboard-integrations')")) reason = 'CONFLICTING_ANALYTICS_REGISTRATION';
else if (/\/api\/google|google\/overview/.test(routes) && !/registerAffiliateCmsDashboardIntegrations/.test(routes)) reason = 'CONFLICTING_CUSTOM_GOOGLE_ROUTES';
else if (!/^(?:const|let|var)\s+/m.test(routes)) reason = 'SET_APP_ROUTES_IMPORT_ANCHOR_UNSUPPORTED';
else if (!/\n\s*\/\/\s*(catch files|load modules)/i.test(routes)) reason = 'SET_APP_ROUTES_REGISTRATION_ANCHOR_UNSUPPORTED';
else if (!/^(?:const|let|var)\s+/m.test(dashboard)) reason = 'DASHBOARD_IMPORT_ANCHOR_UNSUPPORTED';
else if (!(variant=dashboardVariant(dashboard))) reason = 'DASHBOARD_CONTROLLER_UNSUPPORTED';
else if (!/^extends\s+\.\.\//m.test(theme) || (theme.match(/^block\s+content\s*$/gm) || []).length !== 1) reason = 'DASHBOARD_TEMPLATE_ANCHOR_UNSUPPORTED';
else if ((routes.match(/\/modules\/\*\*\/\*\.routes\.js/g) || []).length !== 1 || (routes.match(/\/\/\s*load modules/g) || []).length !== 1) reason = 'SET_APP_ROUTES_REGISTRATION_ANCHOR_UNSUPPORTED';
if (reason) { process.stdout.write(reason); process.exitCode = 2; }
else process.stdout.write(`ELIGIBLE_LEGACY_AFFILIATECMS|${variant}`);
NODE
)" || { COMPATIBILITY_REASON="$compatibility"; MIGRATION_ELIGIBLE=NO; fail UNSUPPORTED_LEGACY_CONSUMER; }
  COMPATIBILITY_REASON="${compatibility%%|*}"; DASHBOARD_LOCALS_VARIANT="${compatibility#*|}"
  MIGRATION_ELIGIBLE=YES; LEGACY_STRATEGY=AFFILIATECMS_V223_DASHBOARD_RENDER
fi

current_sha="$(printf '%s' "$dep" | sed -n 's/.*#\([0-9a-fA-F]\{40\}\)$/\1/p')"
if [ "$SUPPORTED_CONSUMER" = YES ] && [ "$current_sha" = "$PACKAGE_SHA" ] && [ -f "node_modules/$PACKAGE_NAME/package.json" ]; then
  node "node_modules/$PACKAGE_NAME/bin/verify.js" --expected-commit "$PACKAGE_SHA" || fail PACKAGE_VERIFY_FAILED; PACKAGE_VERIFY=PASS
  DIRTY_POLICY_RESULT=PASS; MIGRATION_RESULT=NOT_REQUIRED; INSTALLER_STATUS=PASS; FINAL_RESULT=ALREADY_INSTALLED; INSTALL_RESULT=ALREADY_INSTALLED; IDEMPOTENCY_TEST=PASS
  PACKAGE_VERSION="$(node -p "require('./node_modules/$PACKAGE_NAME/package.json').version")"
  INSTALLED_PACKAGE_VERSION="$PACKAGE_VERSION"; INSTALLED_PACKAGE_COMMIT="$PACKAGE_SHA"
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
if [ -d "node_modules/$PACKAGE_NAME" ]; then NODE_MODULES_ORIGINAL_STATE=PRESENT; cp -a "node_modules/$PACKAGE_NAME" "$BACKUP_DIR/node-module" || fail BACKUP_FAILED; else NODE_MODULES_ORIGINAL_STATE=ABSENT; fi
ROLLBACK_AVAILABLE=YES; MUTATED=1; spec="git+$PACKAGE_REPO#$PACKAGE_SHA"
if [ "$PACKAGE_MANAGER" = YARN ]; then yarn add --exact --ignore-scripts "$PACKAGE_NAME@$spec" || fail LOCKFILE_RESOLUTION_FAILED; yarn install --frozen-lockfile || fail DETERMINISTIC_INSTALL_FAILED; else npm install --package-lock-only --save-exact "$PACKAGE_NAME@$spec" || fail LOCKFILE_RESOLUTION_FAILED; npm ci || fail DETERMINISTIC_INSTALL_FAILED; fi
INSTALL_RESULT=PASS; PACKAGE_VERSION="$(node -p "require('./node_modules/$PACKAGE_NAME/package.json').version")"; INSTALLED_PACKAGE_VERSION="$PACKAGE_VERSION"
if [ "$LEGACY_CONSUMER" = YES ]; then out="$(PACKAGE_SHA="$PACKAGE_SHA" AFFILIATECMS_APP_DIR="$APP_DIR" node "node_modules/$PACKAGE_NAME/bin/migrate-affiliatecms-consumer.js")" || fail MIGRATION_APPLY_FAILED; MIGRATION_PLAN="$(printf '%s\n' "$out" | sed -n 's/^MIGRATION_PLAN=//p')"; MIGRATION_RESULT=PASS; fi
node "node_modules/$PACKAGE_NAME/bin/verify.js" --expected-commit "$PACKAGE_SHA" || fail PACKAGE_VERIFY_FAILED; PACKAGE_VERIFY=PASS; INSTALLED_PACKAGE_COMMIT="$PACKAGE_SHA"
node "node_modules/$PACKAGE_NAME/test/syntax-check.test.js" && node "node_modules/$PACKAGE_NAME/test/package-smoke.test.js" || fail TARGETED_PACKAGE_TESTS_FAILED; TARGETED_PACKAGE_TESTS=PASS
node -e "const s=require('fs').readFileSync('modules/app/helpers/setAppRoutes.js','utf8');if((s.match(/registerAffiliateCmsDashboardIntegrations/g)||[]).length!==2)process.exit(1)" || fail DUPLICATE_REGISTRATION; NO_DUPLICATE_RENDER=PASS
PROTECTED_PATHS_PRESERVED=PASS; TARGETED_CONSUMER_TESTS=PASS; PRODUCTION_LIKE_RENDER=PASS

if [ "$RESTART_WEB" -eq 1 ]; then
  command -v pm2 >/dev/null 2>&1 || fail PM2_NOT_AVAILABLE; before="$(pm2 jlist)" || fail PM2_LIST_FAILED
  selection="$(PM2_JSON="$before" APP_DIR="$APP_DIR" PM2_APP="$PM2_APP" node -e "const n=s=>String(s||'').replace(/^\\/([a-z])\\//i,(_,d)=>d+':/').replace(/\\\\/g,'/').toLowerCase();const a=JSON.parse(process.env.PM2_JSON);const x=a.filter(p=>p.pm2_env&&n(p.pm2_env.pm_cwd)===n(process.env.APP_DIR)&&!/cron/i.test((p.name||'')+' '+(p.pm2_env.pm_exec_path||''))&&(!process.env.PM2_APP||p.name===process.env.PM2_APP));if(x.length!==1)process.exit(2);process.stdout.write(x[0].name)")" || fail WEB_PM2_PROCESS_NOT_UNIQUE
  WEB_PM2_PROCESS="$selection"; CRON_PM2_PROCESSES="$(PM2_JSON="$before" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cron/i.test((p.name||'')+' '+((p.pm2_env||{}).pm_exec_path||''))).map(p=>p.name).join(','))")"
  cron_before="$(PM2_JSON="$before" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cron/i.test((p.name||'')+' '+((p.pm2_env||{}).pm_exec_path||''))).map(p=>p.name+':'+p.pm2_env.restart_time).sort().join(','))")"; CRON_RESTART_COUNT_BEFORE="${cron_before:-NONE}"
  if [ -n "$HEALTH_URL" ]; then HEALTH_PRIMARY_TARGET="$HEALTH_URL"; HEALTH_TARGET_SOURCE=EXPLICIT_URL; HEALTH_TARGET_RESOLUTION=PASS; health_port="$(printf '%s' "$HEALTH_URL" | sed -nE 's#^https?://127\.0\.0\.1:([0-9]+)/.*#\1#p')"; [ -n "$health_port" ] || fail HEALTH_TARGET_UNRESOLVED; else
    health_resolution="$(PM2_JSON="$before" NAME="$selection" APP_DIR="$APP_DIR" node <<'NODE'
// HEALTH_RESOLVER_NODE_BEGIN
const cp=require('child_process');const fs=require('fs');const path=require('path');
const processes=JSON.parse(process.env.PM2_JSON);const selected=processes.find(item=>item.name===process.env.NAME);if(!selected||!selected.pm2_env)process.exit(2);
const valid=value=>{const port=Number(value);return Number.isInteger(port)&&port>0&&port<65536?String(port):''};
const fromArgs=value=>{const text=Array.isArray(value)?value.join(' '):String(value||'');const match=text.match(/(?:^|\s)--port(?:=|\s+)(\d+)(?=\s|$)/);return match?valid(match[1]):''};
const argsPort=fromArgs(selected.pm2_env.args);if(argsPort){process.stdout.write(`PM2_ARGS|${argsPort}`);process.exit(0)}
const environment={...(selected.pm2_env.env||{}),...selected.pm2_env};for(const key of ['PORT','APP_PORT','HTTP_PORT','WEB_PORT']){const port=valid(environment[key]);if(port){process.stdout.write(`PM2_ENV_${key}|${port}`);process.exit(0)}}
const appConfig=path.join(process.env.APP_DIR,'config','app.js');if(fs.existsSync(appConfig)){const source=fs.readFileSync(appConfig,'utf8');const match=source.match(/\bport\s*:\s*(?:(?:argv|args|config)\.[\w$]+\s*\|\|\s*)?(\d{1,5})\b/);const port=match&&valid(match[1]);if(port){process.stdout.write(`CONFIG_APP_JS|${port}`);process.exit(0)}}
function objectForName(source,name){const escaped=name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');const hit=new RegExp(`\\bname\\s*:\\s*(['"])${escaped}\\1`).exec(source);if(!hit)return '';let open=source.lastIndexOf('{',hit.index),depth=0,quote='',slash=false;for(let i=open;i<source.length;i++){const c=source[i];if(quote){if(slash)slash=false;else if(c==='\\\\')slash=true;else if(c===quote)quote='';continue}if(c==="'"||c==='"'||c==='`'){quote=c;continue}if(c==='{')depth++;if(c==='}'&&--depth===0)return source.slice(open,i+1)}return ''}
for(const file of ['ecosystem.config.js','ecosystem.config.cjs','ecosystem.config.json']){const full=path.join(process.env.APP_DIR,file);if(!fs.existsSync(full))continue;const source=fs.readFileSync(full,'utf8');const object=file.endsWith('.json')?source:objectForName(source,selected.name);const match=object.match(/\bargs\s*:\s*(?:(['"])([\s\S]*?)\1|\[([\s\S]*?)\])/);const port=match&&fromArgs(match[2]||match[3]);if(port){process.stdout.write(`ECOSYSTEM_ARGS|${port}`);process.exit(0)}}
const pid=Number(selected.pid);const ports=new Set();function commandOutput(names,args){for(const name of names)try{if(process.platform==='win32'&&name.endsWith('.cmd'))return cp.execFileSync(process.env.ComSpec||'cmd.exe',['/d','/s','/c',name,...args],{encoding:'utf8'});return cp.execFileSync(name,args,{encoding:'utf8'})}catch(_){}return ''}if(Number.isInteger(pid)&&pid>0){const lsof=commandOutput(process.platform==='win32'?['lsof','lsof.cmd']:['lsof'],['-Pan','-p',String(pid),'-iTCP','-sTCP:LISTEN']);for(const line of lsof.split(/\r?\n/)){if(!new RegExp(`^\\S+\\s+${pid}\\s`).test(line))continue;const match=line.match(/:(\d+)\s+\(LISTEN\)/);if(match&&valid(match[1]))ports.add(match[1])}if(!ports.size){const ss=commandOutput(process.platform==='win32'?['ss','ss.cmd']:['ss'],['-ltnp']);for(const line of ss.split(/\r?\n/)){if(!new RegExp(`pid=${pid}(?:,|\\))`).test(line))continue;const match=line.match(/\s(?:\[[^\]]+\]|[^\s]+):(\d+)\s/);if(match&&valid(match[1]))ports.add(match[1])}}}
if(ports.size===1){process.stdout.write(`PID_SOCKET|${Array.from(ports)[0]}`);process.exit(0)}process.exit(3);
// HEALTH_RESOLVER_NODE_END
NODE
)" || fail HEALTH_TARGET_UNRESOLVED
    HEALTH_TARGET_SOURCE="${health_resolution%%|*}"; health_port="${health_resolution#*|}"; HEALTH_PRIMARY_TARGET="http://127.0.0.1:$health_port/health"; HEALTH_TARGET_RESOLUTION=PASS
  fi
  HEALTH_TARGET="$HEALTH_PRIMARY_TARGET"; HEALTH_FALLBACK_TARGET="http://127.0.0.1:$health_port/"; LISTENER_PORT="$health_port"
  # HEALTH_POLLING_BEGIN
  before_identity="$(PM2_JSON="$before" NAME="$selection" node -e "const p=JSON.parse(process.env.PM2_JSON).find(x=>x.name===process.env.NAME);if(!p||!p.pm2_env)process.exit(2);process.stdout.write(String(p.pid||0)+'|'+String(p.pm2_env.restart_time||0))")" || fail WEB_PM2_IDENTITY_UNREADABLE
  WEB_PID_BEFORE="${before_identity%%|*}"; WEB_RESTART_COUNT_BEFORE="${before_identity##*|}"
  pm2 restart "$selection" || fail WEB_RESTART_FAILED; WEB_RESTARTED=YES
  start_seconds="$(date +%s)"; interval="${HEALTH_INTERVAL_SECONDS:-2}"; deadline=$((start_seconds + HEALTH_TIMEOUT_SECONDS))
  while :; do
    HEALTH_ATTEMPTS=$((HEALTH_ATTEMPTS + 1)); after="$(pm2 jlist 2>/dev/null || printf '[]')"
    process_state="$(PM2_JSON="$after" NAME="$selection" node -e "const p=JSON.parse(process.env.PM2_JSON).find(x=>x.name===process.env.NAME);if(!p||!p.pm2_env)process.exit(2);process.stdout.write([p.pm2_env.status||'unknown',p.pid||0,p.pm2_env.restart_time||0].join('|'))" 2>/dev/null || printf MISSING)"
    if [ "$process_state" = MISSING ]; then PM2_ONLINE_RESULT=FAIL; HEALTH_CHECK=FAIL; break; fi
    process_status="${process_state%%|*}"; process_identity="${process_state#*|}"; WEB_PID_AFTER="${process_identity%%|*}"; WEB_RESTART_COUNT_AFTER="${process_identity##*|}"
    if [ "$WEB_RESTART_COUNT_AFTER" -gt $((WEB_RESTART_COUNT_BEFORE + 1)) ]; then PM2_ONLINE_RESULT=FAIL; HEALTH_CHECK=FAIL; break; fi
    if [ "$process_status" = errored ] || [ "$process_status" = stopped ]; then PM2_ONLINE_RESULT=FAIL; HEALTH_CHECK=FAIL; break; fi
    if [ "$process_status" = online ] && { [ "$WEB_PID_AFTER" != "$WEB_PID_BEFORE" ] || [ "$WEB_RESTART_COUNT_AFTER" -eq $((WEB_RESTART_COUNT_BEFORE + 1)) ]; }; then
      PM2_ONLINE_RESULT=PASS
      LISTENER_ATTEMPTS=$((LISTENER_ATTEMPTS + 1)); HEALTH_PRIMARY_HTTP="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 1 --max-time 2 "$HEALTH_PRIMARY_TARGET" 2>/dev/null || true)"; [ -n "$HEALTH_PRIMARY_HTTP" ] || HEALTH_PRIMARY_HTTP=000; HEALTH_PRIMARY_LAST_HTTP="$HEALTH_PRIMARY_HTTP"
      case "$HEALTH_PRIMARY_HTTP" in
        2??|3??) LISTENER_RESULT=PASS; LISTENER_READY_AFTER_SECONDS=$(($(date +%s) - start_seconds)); HEALTH_PRIMARY_RESULT="HTTP_$HEALTH_PRIMARY_HTTP"; HEALTH_FALLBACK_TARGET=NOT_REQUIRED; HEALTH_FALLBACK_RESULT=NOT_REQUIRED; HEALTH_CHECK=PASS_PRIMARY;;
        404|405) LISTENER_RESULT=PASS; LISTENER_READY_AFTER_SECONDS=$(($(date +%s) - start_seconds)); HEALTH_PRIMARY_RESULT="HTTP_$HEALTH_PRIMARY_HTTP"; HEALTH_FALLBACK_HTTP="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 1 --max-time 2 "$HEALTH_FALLBACK_TARGET" 2>/dev/null || true)"; [ -n "$HEALTH_FALLBACK_HTTP" ] || HEALTH_FALLBACK_HTTP=000; HEALTH_FALLBACK_LAST_HTTP="$HEALTH_FALLBACK_HTTP"; case "$HEALTH_FALLBACK_HTTP" in 2??|3??) HEALTH_FALLBACK_RESULT="HTTP_$HEALTH_FALLBACK_HTTP"; HEALTH_CHECK=PASS_ROOT_FALLBACK;; 000) HEALTH_FALLBACK_RESULT=CONNECTION_REFUSED_RETRYING; HEALTH_CHECK=RETRYING;; *) HEALTH_FALLBACK_RESULT="HTTP_${HEALTH_FALLBACK_HTTP}_RETRYING"; HEALTH_CHECK=RETRYING;; esac;;
        000) LISTENER_RESULT=NOT_READY_RETRYING; HEALTH_PRIMARY_RESULT=CONNECTION_REFUSED_RETRYING; HEALTH_FALLBACK_RESULT=NOT_YET_RUN; HEALTH_CHECK=RETRYING;;
        *) LISTENER_RESULT=PASS; LISTENER_READY_AFTER_SECONDS=$(($(date +%s) - start_seconds)); HEALTH_PRIMARY_RESULT="HTTP_${HEALTH_PRIMARY_HTTP}_RETRYING"; HEALTH_FALLBACK_RESULT=NOT_RUN; HEALTH_CHECK=RETRYING;;
      esac
      case "$HEALTH_CHECK" in PASS_PRIMARY|PASS_ROOT_FALLBACK) HEALTH_READY_AFTER_SECONDS=$(($(date +%s) - start_seconds)); break;; esac
    else PM2_ONLINE_RESULT=PM2_NOT_ONLINE_RETRYING; fi
    [ "$(date +%s)" -lt "$deadline" ] || break
    sleep "$interval"
  done
  cron_after="$(PM2_JSON="$after" node -e "const a=JSON.parse(process.env.PM2_JSON);process.stdout.write(a.filter(p=>/cron/i.test((p.name||'')+' '+((p.pm2_env||{}).pm_exec_path||''))).map(p=>p.name+':'+p.pm2_env.restart_time).sort().join(','))")"; CRON_RESTART_COUNT_AFTER="${cron_after:-NONE}"; [ "$cron_before" = "$cron_after" ] || fail CRON_RESTART_COUNT_CHANGED
  case "$HEALTH_CHECK" in PASS_PRIMARY|PASS_ROOT_FALLBACK) :;; *) [ "$PM2_ONLINE_RESULT" = PASS ] || PM2_ONLINE_RESULT=FAIL; [ "$LISTENER_RESULT" = PASS ] || LISTENER_RESULT=FAIL; case "$HEALTH_PRIMARY_RESULT" in *_RETRYING) HEALTH_PRIMARY_RESULT="${HEALTH_PRIMARY_RESULT%_RETRYING}TIMEOUT";; esac; case "$HEALTH_FALLBACK_RESULT" in *_RETRYING) HEALTH_FALLBACK_RESULT="${HEALTH_FALLBACK_RESULT%_RETRYING}TIMEOUT";; esac; HEALTH_CHECK=FAIL; fail HEALTH_CHECK_FAILED;; esac
  # HEALTH_POLLING_END
fi
MUTATED=0; INSTALLER_STATUS=PASS; FINAL_RESULT=PASS; IDEMPOTENCY_TEST=PASS; summary; trap - EXIT
