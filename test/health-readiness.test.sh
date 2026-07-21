#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
awk '/HEALTH_POLLING_BEGIN/{copy=1;next}/HEALTH_POLLING_END/{copy=0}copy' "$ROOT/install.sh" > "$TMP/polling.sh"

make_bin() {
  local dir=$1; mkdir -p "$dir"
  cat > "$dir/pm2" <<'PM2'
#!/usr/bin/env bash
if [ "$1" = restart ]; then printf '%s\n' "$2" >> "$FIXTURE_STATE/restarts"; exit 0; fi
[ "$1" = jlist ] || exit 2
n=$(cat "$FIXTURE_STATE/pm2-count" 2>/dev/null || printf 0); n=$((n+1)); printf '%s' "$n" > "$FIXTURE_STATE/pm2-count"
IFS=, read -ra states <<<"$PM2_STATES"; i=$((n-1)); [ "$i" -lt "${#states[@]}" ] || i=$((${#states[@]}-1)); status=${states[$i]}
pid=202; restart=6; [ "$status" != repeat ] || restart=7; [ "$status" != same ] || { status=online; pid=101; }
printf '[{"name":"affiliatecms7","pid":%s,"pm2_env":{"status":"%s","restart_time":%s}},{"name":"affiliatecms7-cron","pid":303,"pm2_env":{"status":"online","restart_time":9,"pm_exec_path":"cronjobs.js"}}]' "$pid" "$status" "$restart"
PM2
  cat > "$dir/curl" <<'CURL'
#!/usr/bin/env bash
url=${!#}; case "$url" in */health) key=primary; sequence=$PRIMARY_SEQUENCE;; */) key=root; sequence=$ROOT_SEQUENCE;; *) exit 2;; esac
file="$FIXTURE_STATE/$key-count"; n=$(cat "$file" 2>/dev/null || printf 0); n=$((n+1)); printf '%s' "$n" > "$file"
IFS=, read -ra values <<<"$sequence"; i=$((n-1)); [ "$i" -lt "${#values[@]}" ] || i=$((${#values[@]}-1)); value=${values[$i]}
printf '%s' "$value"; [ "$value" != 000 ]
CURL
  cat > "$dir/date" <<'DATE'
#!/usr/bin/env bash
n=$(cat "$FIXTURE_STATE/date-count" 2>/dev/null || printf 999); n=$((n+1)); printf '%s' "$n" > "$FIXTURE_STATE/date-count"; printf '%s\n' "$n"
DATE
  printf '#!/usr/bin/env bash\nexit 0\n' > "$dir/sleep"
  chmod +x "$dir/pm2" "$dir/curl" "$dir/date" "$dir/sleep"
}

run_case() {
  local name states primary root timeout state bin
  name=$1; states=$2; primary=$3; root=$4; timeout=${5:-10}
  state="$TMP/$name"; bin="$TMP/$name-bin"
  mkdir -p "$state"; make_bin "$bin"
  FIXTURE_STATE="$state" PM2_STATES="$states" PRIMARY_SEQUENCE="$primary" ROOT_SEQUENCE="$root" PATH="$bin:$PATH" POLLING_FILE="$TMP/polling.sh" HEALTH_TIMEOUT_SECONDS="$timeout" bash <<'RUN' 2>&1 || true
set -u
WEB_PM2_PROCESS=affiliatecms7; selection=affiliatecms7; health_port=8007; HEALTH_PRIMARY_TARGET=http://127.0.0.1:8007/health; HEALTH_FALLBACK_TARGET=http://127.0.0.1:8007/; HEALTH_TARGET=$HEALTH_PRIMARY_TARGET
before='[{"name":"affiliatecms7","pid":101,"pm2_env":{"status":"online","restart_time":5}},{"name":"affiliatecms7-cron","pid":303,"pm2_env":{"status":"online","restart_time":9,"pm_exec_path":"cronjobs.js"}}]'; cron_before='affiliatecms7-cron:9'
WEB_RESTARTED=NO; WEB_PID_BEFORE=UNKNOWN; WEB_PID_AFTER=UNKNOWN; WEB_RESTART_COUNT_BEFORE=UNKNOWN; WEB_RESTART_COUNT_AFTER=UNKNOWN; PM2_ONLINE_RESULT=NOT_RUN
CRON_RESTART_COUNT_AFTER=UNKNOWN; LISTENER_RESULT=NOT_RUN; LISTENER_ATTEMPTS=0; LISTENER_READY_AFTER_SECONDS=NOT_READY
HEALTH_ATTEMPTS=0; HEALTH_INTERVAL_SECONDS=2; HEALTH_CHECK=NOT_RUN; HEALTH_PRIMARY_HTTP=NOT_RUN; HEALTH_PRIMARY_LAST_HTTP=NOT_RUN; HEALTH_PRIMARY_RESULT=NOT_RUN; HEALTH_FALLBACK_HTTP=NOT_RUN; HEALTH_FALLBACK_LAST_HTTP=NOT_RUN; HEALTH_FALLBACK_RESULT=NOT_RUN; HEALTH_READY_AFTER_SECONDS=NOT_READY; FINAL_RESULT=PASS
report(){ for k in WEB_RESTARTED WEB_PID_BEFORE WEB_PID_AFTER WEB_RESTART_COUNT_BEFORE WEB_RESTART_COUNT_AFTER CRON_RESTART_COUNT_AFTER PM2_ONLINE_RESULT LISTENER_RESULT LISTENER_ATTEMPTS HEALTH_ATTEMPTS HEALTH_PRIMARY_RESULT HEALTH_FALLBACK_RESULT HEALTH_CHECK FINAL_RESULT; do eval "v=\${$k}"; printf '%s=%s\n' "$k" "$v"; done; }
fail(){ FINAL_RESULT=$1; report; exit 1; }
. "$POLLING_FILE"
report
RUN
}

out=$(run_case delayed 'starting,online,online' '000,404' '200'); grep -q '^HEALTH_CHECK=PASS_ROOT_FALLBACK$' <<<"$out"; grep -q '^FINAL_RESULT=PASS$' <<<"$out"; echo DELAYED_STARTUP_FIXTURE=PASS
out=$(run_case missing_health 'online' '404' '200'); grep -q '^HEALTH_CHECK=PASS_ROOT_FALLBACK$' <<<"$out"; echo HEALTH_404_ROOT_200_FIXTURE=PASS
out=$(run_case primary 'online' '200' '500'); grep -q '^HEALTH_CHECK=PASS_PRIMARY$' <<<"$out"; [ ! -f "$TMP/primary/root-count" ]; echo HEALTH_200_PRIMARY_FIXTURE=PASS
out=$(run_case no_listener 'online' '000' '500' 4); grep -q '^HEALTH_CHECK=FAIL$' <<<"$out"; grep -q '^FINAL_RESULT=HEALTH_CHECK_FAILED$' <<<"$out"; echo PERMANENT_STARTUP_FAILURE_FIXTURE=PASS
out=$(run_case root_failure 'online' '404' '500' 4); grep -q '^HEALTH_CHECK=FAIL$' <<<"$out"; echo ROOT_FAILURE_FIXTURE=PASS
out=$(run_case crash 'errored' '200' '200'); grep -q '^PM2_ONLINE_RESULT=FAIL$' <<<"$out"; echo PROCESS_CRASH_FIXTURE=PASS
out=$(run_case cron 'online' '200' '500'); grep -q '^WEB_RESTART_COUNT_AFTER=6$' <<<"$out"; grep -q '^CRON_RESTART_COUNT_AFTER=affiliatecms7-cron:9$' <<<"$out"; [ "$(cat "$TMP/cron/restarts")" = affiliatecms7 ]; echo CRON_PRESERVATION_FIXTURE=PASS
