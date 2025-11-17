# apply-insight-synch-skeleton.ps1
# Writes & applies the Insight Synch v2 T+5 d skeleton PATCH, creating required
# directories, performing a dry-run check, then applying for real.

$patch = @'
diff --git a/.githooks/synch-hook.ps1 b/.githooks/synch-hook.ps1
new file mode 100755
index 0000000..e69de29
--- /dev/null
+++ b/.githooks/synch-hook.ps1
@@
+#!/usr/bin/env pwsh
+<#
+    Validate-only pre-commit hook for Insight Synch v2
+    1. Ensures VS Code extension `labview-community.seed-insight`
+       is present at or above the minimum version.
+    2. Delegates deep validation to scripts/validate-insight.ps1
+#>
+param (
+    [string]$GitRoot = (git rev-parse --show-toplevel)
+)
+
+Set-StrictMode -Version Latest
+$ErrorActionPreference = 'Stop'
+
+function Test-ExtensionInstalled {
+    param(
+        [string]$Id,
+        [string]$MinVersion = "0.0.0"
+    )
+    $extensions = & code --list-extensions --show-versions 2>$null
+    if (-not $extensions) { return $true }      # skip if CLI missing
+    foreach ($line in $extensions) {
+        if ($line -match "^$Id\\s+(?<ver>[0-9\\.]+)$") {
+            return ([version]$Matches.ver -ge [version]$MinVersion)
+        }
+    }
+    return $false
+}
+
+if (-not (Test-ExtensionInstalled -Id 'labview-community.seed-insight')) {
+    Write-Error 'Required VS Code extension labview-community.seed-insight not installed or too old.'
+    exit 1
+}
+
+$files = git diff --cached --name-only | ? { $_ -match '\.insight\.json$' }
+if ($files.Count -eq 0) { exit 0 }
+
+& "$GitRoot/scripts/validate-insight.ps1" -Path $files
+exit $LASTEXITCODE
+
diff --git a/.githooks/synch-hook.sh b/.githooks/synch-hook.sh
new file mode 100755
index 0000000..e69de29
--- /dev/null
+++ b/.githooks/synch-hook.sh
@@
+#!/usr/bin/env sh
+# Validate-only pre-commit hook for Insight Synch v2 (POSIX)
+set -eu
+GIT_ROOT=$(git rev-parse --show-toplevel)
+EXTENSION_ID="labview-community.seed-insight"
+if command -v code >/dev/null 2>&1; then
+  code --list-extensions --show-versions | grep -q "^${EXTENSION_ID}" || {
+    echo "Required VS Code extension ${EXTENSION_ID} not installed." >&2
+    exit 1
+  }
+fi
+FILES=$(git diff --cached --name-only | grep '\.insight\.json$' || true)
+[ -z "$FILES" ] && exit 0
+"$GIT_ROOT/scripts/validate-insight.sh" $FILES
+exit $?
+
diff --git a/scripts/validate-insight.ps1 b/scripts/validate-insight.ps1
new file mode 100755
index 0000000..e69de29
--- /dev/null
+++ b/scripts/validate-insight.ps1
@@
+#!/usr/bin/env pwsh
+<#
+ Validates Insight JSON files:
+  • JSON parse
+  • required fields id/timestamp/sha256
+  • SHA-256 integrity check
+#>
+param([Parameter(ValueFromRemainingArguments)][string[]]$Path)
+Set-StrictMode -Version Latest
+$ErrorActionPreference = 'Stop'
+function Assert($cond,$msg){if(-not $cond){throw $msg}}
+foreach($f in $Path){
+  Assert (Test-Path $f) "File '$f' not found."
+  try{$j=Get-Content $f -Raw|ConvertFrom-Json}catch{throw "JSON error in $f"}
+  foreach($k in 'id','timestamp','sha256'){Assert $j.$k "$f missing $k"}
+  $clone=$j|Select-Object * -Exclude sha256|ConvertTo-Json -Compress
+  $hash=(Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new(
+          [Text.Encoding]::UTF8.GetBytes($clone)))).Hash.ToLower()
+  Assert ($hash -eq $j.sha256.ToLower()) "SHA-256 mismatch in $f"
+}
+Write-Host 'All insight files validated.'
+
diff --git a/scripts/validate-insight.sh b/scripts/validate-insight.sh
new file mode 100755
index 0000000..e69de29
--- /dev/null
+++ b/scripts/validate-insight.sh
@@
+#!/usr/bin/env sh
+set -eu
+pwsh "$(dirname "$0")/validate-insight.ps1" "$@"
+
diff --git a/.github/workflows/ci.yml b/.github/workflows/ci.yml
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/.github/workflows/ci.yml
@@
+name: Insight CI
+on:
+  push:  { branches: [main] }
+  pull_request: { branches: [main] }
+jobs:
+  validate:
+    runs-on: ubuntu-latest
+    steps:
+      - uses: actions/checkout@v4
+      - name: Validate Insight files
+        shell: pwsh
+        run: |
+          $files = git ls-files '*.insight.json'
+          if ($files) { ./scripts/validate-insight.ps1 -Path $files }
+
diff --git a/tooling/vscode-seed-insight/package.json b/tooling/vscode-seed-insight/package.json
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tooling/vscode-seed-insight/package.json
@@
+{
+  "name": "seed-insight",
+  "displayName": "Seed Insight",
+  "publisher": "labview-community",
+  "version": "0.0.1",
+  "engines": { "vscode": "^1.90.0" },
+  "activationEvents": ["onCommand:seedInsight.generate"],
+  "main": "./dist/extension.js",
+  "contributes": {
+    "commands": [
+      { "command": "seedInsight.generate", "title": "Generate Insight" }
+    ]
+  },
+  "scripts": { "build": "tsc -p ./", "package": "vsce package" },
+  "devDependencies": { "typescript": "^5.5.0", "vsce": "^3.17.0" }
+}
+
diff --git a/tooling/vscode-seed-insight/tsconfig.json b/tooling/vscode-seed-insight/tsconfig.json
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tooling/vscode-seed-insight/tsconfig.json
@@
+{ "compilerOptions": { "target": "es2020", "module": "commonjs",
+  "rootDir": "src", "outDir": "dist", "strict": true,
+  "esModuleInterop": true, "skipLibCheck": true } }
+
diff --git a/tooling/vscode-seed-insight/src/extension.ts b/tooling/vscode-seed-insight/src/extension.ts
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tooling/vscode-seed-insight/src/extension.ts
@@
+import * as vscode from 'vscode';
+import { installHooks } from './installHooks';
+export function activate(ctx: vscode.ExtensionContext){
+  const gen = vscode.commands.registerCommand('seedInsight.generate',
+    ()=>vscode.window.showInformationMessage('Generate Insight invoked'));
+  installHooks(ctx);
+  const sb = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left,100);
+  sb.text='Seed Insight: Ready'; sb.show();
+  ctx.subscriptions.push(gen,sb);
+}
+export function deactivate(){}
+
diff --git a/tooling/vscode-seed-insight/src/installHooks.ts b/tooling/vscode-seed-insight/src/installHooks.ts
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tooling/vscode-seed-insight/src/installHooks.ts
@@
+import * as vscode from 'vscode';
+import * as cp from 'child_process';
+import * as path from 'path';
+export function installHooks(ctx:vscode.ExtensionContext){
+  const cmd=vscode.commands.registerCommand('seedInsight.installHooks',()=>{
+    const ws=vscode.workspace.workspaceFolders?.[0]; if(!ws){return;}
+    const gitRoot=ws.uri.fsPath, hookDir=path.join(gitRoot,'.githooks');
+    try{
+      cp.execSync(`mkdir -p "${hookDir}"`);
+      ['ps1','sh'].forEach(ext=>cp.execSync(
+        `cp "${path.join(ctx.extensionPath,'templates',\`synch-hook.\${ext}\`)}" "${hookDir}/synch-hook.${ext}"`));
+      vscode.window.showInformationMessage('Seed Insight hooks installed.');
+    }catch(e){vscode.window.showErrorMessage(String(e));}
+  });
+  ctx.subscriptions.push(cmd);
+}
+
diff --git a/tooling/vscode-seed-insight/templates/synch-hook.ps1 b/tooling/vscode-seed-insight/templates/synch-hook.ps1
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tooling/vscode-seed-insight/templates/synch-hook.ps1
@@
+# Placeholder; real hook lives in repo root.
+
diff --git a/tooling/vscode-seed-insight/templates/synch-hook.sh b/tooling/vscode-seed-insight/templates/synch-hook.sh
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tooling/vscode-seed-insight/templates/synch-hook.sh
@@
+# Placeholder; real hook lives in repo root.
+
diff --git a/knowledge_base/engagements/.gitkeep b/knowledge_base/engagements/.gitkeep
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/knowledge_base/engagements/.gitkeep
@@
+
diff --git a/telemetry/insight.log b/telemetry/insight.log
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/telemetry/insight.log
@@
+
diff --git a/docs/CONTRIBUTING.md b/docs/CONTRIBUTING.md
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/docs/CONTRIBUTING.md
@@
+# Contributing to Insight Synch v2
+Welcome!  
+## Prerequisites
+* PowerShell 7 / POSIX sh  
+* Node 18+  
+* VS Code 1.90+ with **Seed Insight** extension
+## Workflow
+Trunk-based: push to `main`; fix-forward if CI fails.  
+### Hooks
+Run the VS Code command “Seed Insight: Install Hooks” to add/update commit hooks.  
+### Validation
+You can run `scripts/validate-insight.ps1` manually on any `.insight.json` file.  
+## Tests
+* **Pester** (PowerShell)  
+* **Jest** (extension)  
+* **Playwright** (UI) — targets Win/macOS/Linux
+
diff --git a/tests/pester/.gitkeep b/tests/pester/.gitkeep
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tests/pester/.gitkeep
@@
+
diff --git a/tests/jest/.gitkeep b/tests/jest/.gitkeep
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tests/jest/.gitkeep
@@
+
diff --git a/tests/playwright/.gitkeep b/tests/playwright/.gitkeep
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/tests/playwright/.gitkeep
@@
+
'@

# --- Ensure required directories exist --------------------------------------
$dirs = @(
  '.githooks','scripts',
  'tooling/vscode-seed-insight/src',
  'tooling/vscode-seed-insight/templates',
  'knowledge_base/engagements',
  'telemetry','docs',
  'tests/pester','tests/jest','tests/playwright'
)
foreach ($d in $dirs){ if(-not (Test-Path $d)){ New-Item -Type Directory -Force -Path $d | Out-Null } }

# --- Write patch to a temp file --------------------------------------------
$patchFile = [System.IO.Path]::GetTempFileName() + '.patch'
$patch | Set-Content -Path $patchFile -Encoding ascii -NoNewline

# --- Dry-run check ----------------------------------------------------------
Write-Host "`n[Dry-run] Verifying patch can apply..."
git apply --check $patchFile
if($LASTEXITCODE -ne 0){
  Write-Host "❌  Patch cannot be applied. Fix the above issues and retry."
  Remove-Item $patchFile; exit 1
}

# --- Apply for real ---------------------------------------------------------
Write-Host "`n[Applying patch...]"
git apply --verbose --allow-empty --directory=. $patchFile
Remove-Item $patchFile

Write-Host "`n✅  Patch applied! Next commands:"
Write-Host "   git add -A"
Write-Host "   git commit -am 'T+5d skeleton scaffolds'"
Write-Host "   git push origin main`n"
