# SemVer Guard Import Checklist

1. Copy src/tools/priority/validate-semver.mjs and the docs in docs/ into your repo.
2. Add "semver:check": "node ./src/tools/priority/validate-semver.mjs" to package.json and pin Node to >=20.11.0.
3. Run 
pm install then 
pm run semver:check locally to confirm the guard works.
4. Drop .github/workflows/semver-guard.yml into your repo (customize triggers as needed).
5. Verify the bundle integrity via undle.json (SHA256 hashes).
6. Comment on the tracking issue with the steps you completed.
