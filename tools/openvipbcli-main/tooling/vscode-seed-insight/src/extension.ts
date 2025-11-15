import * as vscode from "vscode";
import { generateInsight } from "./generateInsight";

export function activate(context: vscode.ExtensionContext) {
    vscode.window.showInformationMessage("Seed Insight extension activated.");
    // Status-bar item
    const statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
    statusBar.text = "Seed Insight: Ready";
    statusBar.command = "seedInsight.generate";
    statusBar.tooltip = "Generate a new Insight";
    statusBar.show();
    context.subscriptions.push(statusBar);

    // Generate Insight command
    const gen = vscode.commands.registerCommand("seedInsight.generate", async () => {
        const folders = vscode.workspace.workspaceFolders;
        if (!folders) {
            vscode.window.showErrorMessage("Open a workspace folder to generate insights.");
            return;
        }
        const root = folders[0].uri.fsPath;
        const ok = await generateInsight(root);
        if (ok) {
            statusBar.text = "Seed Insight: Generated";
        }
    });
    context.subscriptions.push(gen);

    // Stage & Commit macro
    const stage = vscode.commands.registerCommand(
      "seedInsight.stageCommit",
      async (uri?: vscode.Uri) => {
        const gitExt = vscode.extensions.getExtension("vscode.git")?.exports;
        const api    = gitExt.getAPI(1);
        const repo   = api.repositories[0];
        if (!repo) {
            vscode.window.showErrorMessage("Git repository not found.");
            return;
        }
        if (uri) {
            await repo.stage(uri);
        } else {
            await repo.stageAll();
        }
        // Open commit UI with a default message
        vscode.commands.executeCommand("git.commit", {
            message: `Add insight ${uri?.path.split("/").pop() ?? ""}`,
            noVerify: false,
            all: false
        });
      }
    );
    context.subscriptions.push(stage);
}

export function deactivate() {}
