#!/usr/bin/env bash
set -euo pipefail
INSTALLER="$(cd "$(dirname "$0")/.." && pwd -P)/install.sh"
node "$(dirname "$0")/health-discovery.test.js"
SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
TEST_TMP_ROOT="$(mktemp -d -p "$(dirname "$INSTALLER")" installer-fixtures.XXXXXX)"
trap 'rm -rf "$TEST_TMP_ROOT"' EXIT
make_fixture() {
  local kind=$1 root
  root="$(mktemp -d -p "$TEST_TMP_ROOT" fixture.XXXXXX)"; cd "$root"; git init -q; git config user.email fixture@example.test; git config user.name Fixture
  mkdir -p modules/app/helpers modules/dashboard/controllers themes/admin/dashboard sitemaps tmp
  printf '%s\n' '{"name":"affiliatecms","version":"v2.2.3","scripts":{"start":"node server"},"dependencies":{}}' > package.json
  printf '%s\n' "const setAppRoutes=require('./modules/app/helpers/setAppRoutes'); setAppRoutes(app);" > server.js
  printf '%s\n' "const glob=require('glob');" 'async function setExpressRoutes(app) {' '  // load modules' "  const modules = glob.sync(process.cwd() + '/modules/**/*.routes.js');" '  for (const m of modules) app.use(require(m)(app));' '  return app;' '}' 'module.exports=setExpressRoutes;' > modules/app/helpers/setAppRoutes.js
  printf '%s\n' "const x=1;async function DashboardContentList(req,res){return res.render('admin/dashboard/content-list',res.locals)}async function DashboardAdmin(req,res){const activeSection=req.query.section||'overview';const options={activeSection};let dashboard;try{dashboard=await getDashboardHome(res.locals.user,options)}catch(error){dashboard={scheduledItems:[],pagination:{page:1},error:true}}Object.assign(res.locals,{context:{dashboard,breadcrumb:[{text:'Dashboard'}]}});return res.render('admin/dashboard/dashboard-admin',res.locals)}async function DashboardSeoAuditList(req,res){return res.render('admin/dashboard/seo-audit',res.locals)}module.exports={DashboardAdmin,DashboardContentList,DashboardSeoAuditList};" > modules/dashboard/controllers/dashboard.admin.js
  printf '%s\n' 'extends ../admin-layout' '' 'block content' '  .dashboard-shell' '    p Existing scheduled items and pagination' > themes/admin/dashboard/dashboard-admin.pug
  case "$kind" in yarn|dirty|backup|conflict|unsupported|rollback) printf '# fixture\n' > yarn.lock;; npm) printf '%s\n' '{"name":"affiliatecms","version":"v2.2.3","lockfileVersion":2,"requires":true,"packages":{"":{"name":"affiliatecms","version":"2.2.3"}}}' > package-lock.json;; multi) printf '# fixture\n' > yarn.lock; printf '{}' > package-lock.json;; none) :;; esac
  git add .; git commit -qm fixture
  [ "$kind" != backup ] || printf keep > unrelated.bak_2026
  [ "$kind" != dirty ] || printf '\n// local\n' >> modules/app/helpers/setAppRoutes.js
  [ "$kind" != conflict ] || sed -i '1i// /api/google custom route' modules/app/helpers/setAppRoutes.js
  [ "$kind" != unsupported ] || sed -i "s@dashboard-admin',res.locals@dashboard-admin',someOtherObject@" modules/dashboard/controllers/dashboard.admin.js
  printf '%s' "$root"
}
run_fixture() { local root=$1; shift; (cd "$root" && AFFILIATE_INSTALLER_PACKAGE_METADATA_JSON='{"version":"1.4.2"}' "$INSTALLER" --package-sha "$SHA" "$@") 2>&1 || true; }

r=$(make_fixture yarn); out=$(run_fixture "$r" --verify-only); grep -q '^PRECHECK=PASS$' <<<"$out"; grep -q '^LOCKFILE=yarn.lock$' <<<"$out"; grep -q '^MIGRATION_ELIGIBLE=YES$' <<<"$out"; grep -q '^LEGACY_STRATEGY=AFFILIATECMS_V223_DASHBOARD_RENDER$' <<<"$out"; grep -q '^DASHBOARD_LOCALS_VARIANT=DIRECT_RES_LOCALS$' <<<"$out"; grep -q '^REQUESTED_PACKAGE_VERSION=1.4.2$' <<<"$out"; grep -q '^FINAL_RESULT=MIGRATION_REQUIRED$' <<<"$out"
r=$(make_fixture yarn); sed -i "s@Object.assign(res.locals@const {locals}=res;Object.assign(locals@;s@dashboard-admin',res.locals@dashboard-admin',locals@" "$r/modules/dashboard/controllers/dashboard.admin.js"; git -C "$r" add .; git -C "$r" commit -qm alias; out=$(run_fixture "$r" --verify-only); grep -q '^DASHBOARD_LOCALS_VARIANT=LOCALS_ALIAS$' <<<"$out"
r=$(make_fixture npm); out=$(run_fixture "$r" --dry-run --migrate-legacy); grep -q '^PACKAGE_MANAGER=NPM$' <<<"$out"; grep -q '^FINAL_RESULT=DRY_RUN$' <<<"$out"
r=$(make_fixture none); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=NO_TRACKED_LOCKFILE$' <<<"$out"
r=$(make_fixture multi); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=MULTIPLE_TRACKED_LOCKFILES$' <<<"$out"
r=$(make_fixture dirty); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=DIRTY_MIGRATION_TARGET$' <<<"$out"
r=$(make_fixture backup); before=$(sha256sum "$r/unrelated.bak_2026"); out=$(run_fixture "$r" --dry-run --migrate-legacy); after=$(sha256sum "$r/unrelated.bak_2026"); [ "$before" = "$after" ]; grep -q '^DIRTY_POLICY_RESULT=PASS$' <<<"$out"
r=$(make_fixture conflict); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=UNSUPPORTED_LEGACY_CONSUMER$' <<<"$out"; grep -q 'CONFLICTING_CUSTOM_GOOGLE_ROUTES' <<<"$out"
r=$(make_fixture unsupported); before_package=$(sha256sum "$r/package.json"); before_lock=$(sha256sum "$r/yarn.lock"); out=$(run_fixture "$r" --migrate-legacy); grep -q '^PRECHECK=PASS$' <<<"$out"; grep -q '^MIGRATION_REQUIRED=YES$' <<<"$out"; grep -q '^MIGRATION_ELIGIBLE=NO$' <<<"$out"; grep -q '^COMPATIBILITY_REASON=DASHBOARD_CONTROLLER_UNSUPPORTED$' <<<"$out"; grep -q '^FINAL_RESULT=UNSUPPORTED_LEGACY_CONSUMER$' <<<"$out"; grep -q '^INSTALL_RESULT=NOT_RUN$' <<<"$out"; grep -q '^ROLLBACK_AVAILABLE=NO$' <<<"$out"; grep -q '^ROLLBACK_RESULT=NOT_REQUIRED$' <<<"$out"; [ "$before_package" = "$(sha256sum "$r/package.json")" ]; [ "$before_lock" = "$(sha256sum "$r/yarn.lock")" ]; [ ! -d "$r/.git/affiliate-dashboard-integrations-backups" ]

r=$(make_fixture rollback); mkdir -p "$r/node_modules/@robus/affiliate-dashboard-integrations/bin" "$r/node_modules/@robus/affiliate-dashboard-integrations/test" "$r/fake-bin"; printf '%s\n' '{"name":"@robus/affiliate-dashboard-integrations","version":"1.4.0","stale":true}' > "$r/node_modules/@robus/affiliate-dashboard-integrations/package.json"; printf '%s\n' 'process.exit(1);' > "$r/node_modules/@robus/affiliate-dashboard-integrations/bin/verify.js"; printf '%s\n' 'process.exit(0);' > "$r/node_modules/@robus/affiliate-dashboard-integrations/test/syntax-check.test.js"; printf '%s\n' 'process.exit(0);' > "$r/node_modules/@robus/affiliate-dashboard-integrations/test/package-smoke.test.js"; cat > "$r/node_modules/@robus/affiliate-dashboard-integrations/bin/migrate-affiliatecms-consumer.js" <<'MIGRATE'
const fs=require('fs');
for(const f of ['modules/app/helpers/setAppRoutes.js','modules/dashboard/controllers/dashboard.admin.js','themes/admin/dashboard/dashboard-admin.pug']) fs.appendFileSync(f,'\n// migrated\n');
fs.mkdirSync('config',{recursive:true});fs.writeFileSync('config/analytics-package.js','module.exports={};\n');
process.stdout.write('MIGRATION_PLAN=forced-rollback-fixture\nMIGRATION_RESULT=PASS\n');
MIGRATE
  cat > "$r/fake-bin/yarn" <<'YARN'
#!/usr/bin/env bash
if [ "$1" = add ]; then node -e "const fs=require('fs'),p=require('./package.json');p.dependencies['@robus/affiliate-dashboard-integrations']='git+https://github.com/letuanthhcm/affiliate-dashboard-integrations.git#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';fs.writeFileSync('package.json',JSON.stringify(p,null,2)+'\n');fs.appendFileSync('yarn.lock','# migrated\n')"; fi
exit 0
YARN
  chmod +x "$r/fake-bin/yarn"; rollback_files='package.json yarn.lock modules/app/helpers/setAppRoutes.js modules/dashboard/controllers/dashboard.admin.js themes/admin/dashboard/dashboard-admin.pug'; before_manifest=''; for f in $rollback_files; do before_manifest="$before_manifest$f:$(sha256sum "$r/$f" | awk '{print $1}');"; done; stale_before=$(sha256sum "$r/node_modules/@robus/affiliate-dashboard-integrations/package.json"); out=$(cd "$r" && AFFILIATE_INSTALLER_PACKAGE_METADATA_JSON='{"version":"1.4.2"}' PATH="$r/fake-bin:$PATH" "$INSTALLER" --package-sha "$SHA" --migrate-legacy 2>&1 || true); grep -q '^FINAL_RESULT=PACKAGE_VERIFY_FAILED$' <<<"$out"; grep -q '^ROLLBACK_AVAILABLE=YES$' <<<"$out"; grep -q '^ROLLBACK_RESULT=PASS$' <<<"$out"; grep -q '^SOURCE_ROLLBACK_RESULT=PASS$' <<<"$out"; grep -q '^LOCKFILE_ROLLBACK_RESULT=PASS$' <<<"$out"; grep -q '^CREATED_FILES_ROLLBACK_RESULT=PASS$' <<<"$out"; grep -q '^NODE_MODULES_ROLLBACK_RESULT=PASS$' <<<"$out"; grep -q '^OVERALL_ROLLBACK_RESULT=PASS$' <<<"$out"; grep -q '^INSTALL_RESULT=ROLLED_BACK$' <<<"$out"; grep -q '^WEB_RESTARTED=NO$' <<<"$out"; [ ! -e "$r/config/analytics-package.js" ]; [ "$stale_before" = "$(sha256sum "$r/node_modules/@robus/affiliate-dashboard-integrations/package.json")" ]; after_manifest=''; for f in $rollback_files; do after_manifest="$after_manifest$f:$(sha256sum "$r/$f" | awk '{print $1}');"; done; [ "$before_manifest" = "$after_manifest" ]; git -C "$r" diff --quiet; rm -rf "$r"
echo 'public installer fixture tests passed'
