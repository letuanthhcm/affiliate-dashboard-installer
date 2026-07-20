#!/usr/bin/env bash
set -euo pipefail
INSTALLER="$(cd "$(dirname "$0")/.." && pwd -P)/install.sh"
SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
make_fixture() {
  local kind=$1 root
  root="$(mktemp -d)"; cd "$root"; git init -q; git config user.email fixture@example.test; git config user.name Fixture
  mkdir -p modules/app/helpers modules/dashboard/controllers themes/admin/dashboard sitemaps tmp
  printf '%s\n' '{"name":"affiliatecms","version":"v2.2.3","scripts":{"start":"node server"},"dependencies":{}}' > package.json
  printf '%s\n' "const setAppRoutes=require('./modules/app/helpers/setAppRoutes'); setAppRoutes(app);" > server.js
  printf '%s\n' 'const x=1; async function setAppRoutes(app) { // load modules' 'return app; }' 'module.exports=setAppRoutes;' > modules/app/helpers/setAppRoutes.js
  printf '%s\n' "const x=1; async function AdminHome(_q,res){const {locals}=res;return res.render('admin/dashboard/dashboard-admin',locals);} module.exports={AdminHome};" > modules/dashboard/controllers/dashboard.admin.js
  printf '%s\n' 'extends ../layout' 'block content' '  p Legacy' > themes/admin/dashboard/dashboard-admin.pug
  case "$kind" in yarn|dirty|backup|conflict) printf '# fixture\n' > yarn.lock;; npm) printf '%s\n' '{"name":"affiliatecms","version":"v2.2.3","lockfileVersion":2,"requires":true,"packages":{"":{"name":"affiliatecms","version":"2.2.3"}}}' > package-lock.json;; multi) printf '# fixture\n' > yarn.lock; printf '{}' > package-lock.json;; none) :;; esac
  git add .; git commit -qm fixture
  [ "$kind" != backup ] || printf keep > unrelated.bak_2026
  [ "$kind" != dirty ] || printf '\n// local\n' >> modules/app/helpers/setAppRoutes.js
  [ "$kind" != conflict ] || sed -i '1i// /api/google custom route' modules/app/helpers/setAppRoutes.js
  printf '%s' "$root"
}
run_fixture() { local root=$1; shift; (cd "$root" && "$INSTALLER" --package-sha "$SHA" "$@") 2>&1 || true; }

r=$(make_fixture yarn); out=$(run_fixture "$r" --verify-only); grep -q '^PRECHECK=PASS$' <<<"$out"; grep -q '^LOCKFILE=yarn.lock$' <<<"$out"; grep -q '^MIGRATION_ELIGIBLE=YES$' <<<"$out"; grep -q '^FINAL_RESULT=MIGRATION_REQUIRED$' <<<"$out"
r=$(make_fixture npm); out=$(run_fixture "$r" --dry-run --migrate-legacy); grep -q '^PACKAGE_MANAGER=NPM$' <<<"$out"; grep -q '^FINAL_RESULT=DRY_RUN$' <<<"$out"
r=$(make_fixture none); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=NO_TRACKED_LOCKFILE$' <<<"$out"
r=$(make_fixture multi); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=MULTIPLE_TRACKED_LOCKFILES$' <<<"$out"
r=$(make_fixture dirty); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=DIRTY_MIGRATION_TARGET$' <<<"$out"
r=$(make_fixture backup); before=$(sha256sum "$r/unrelated.bak_2026"); out=$(run_fixture "$r" --dry-run --migrate-legacy); after=$(sha256sum "$r/unrelated.bak_2026"); [ "$before" = "$after" ]; grep -q '^DIRTY_POLICY_RESULT=PASS$' <<<"$out"
r=$(make_fixture conflict); out=$(run_fixture "$r" --verify-only); grep -q '^FINAL_RESULT=UNSUPPORTED_LEGACY_CONSUMER$' <<<"$out"; grep -q 'CONFLICTING_CUSTOM_GOOGLE_ROUTES' <<<"$out"
echo 'public installer fixture tests passed'
