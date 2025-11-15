import * as vscode from "vscode";
import * as fs from "fs";
import * as path from "path";
import * as cp from "child_process";

/**
 * Copies .githooks/* from the extension’s templates folder
 * into the current workspace root (creates .githooks dir if needed),
 * makes them executable, and warns on overwrite.
 */
export function installHooks(ctx: vscode.ExtensionContext) {
  const disposable = vscode.commands.registerCommand(
    "seedInsight.installHooks",
    async () => {
      const ws = vscode.workspace.workspaceFolders?.[0];
      if (!ws) {
        vscode.window.showWarningMessage("Open a workspace to install commit hooks.");
        return;
      }

      const gitRoot = ws.uri.fsPath;
      const hookDir  = path.join(gitRoot, ".githooks");
      const tplDir   = path.join(ctx.extensionPath, "templates");

      try {
        if (!fs.existsSync(hookDir)) {
          fs.mkdirSync(hookDir, { recursive: true });
        }

        ["synch-hook.ps1", "synch-hook.sh"].forEach(file => {
          const src = path.join(tplDir, file);
          const dst = path.join(hookDir, file);

          if (fs.existsSync(dst)) {
            const choice = vscode.workspace
              .getConfiguration("seedInsight")
              .get<boolean>("overwriteHooks", false);
            if (!choice) {
              vscode.window.showInformationMessage(
                `${file} already exists – skipping (change setting seedInsight.overwriteHooks to true to force overwrite).`
              );
              return;
            }
          }
          fs.copyFileSync(src, dst);
          if (process.platform !== "win32") {
            try { cp.execSync(`chmod +x "${dst}"`); } catch { /* ignore */ }
          }
        });

        vscode.window.showInformationMessage("Seed Insight commit hooks installed.");
      } catch (err) {
        vscode.window.showErrorMessage(`Hook install failed: ${String(err)}`);
      }
    }
  );

  ctx.subscriptions.push(disposable);
}
