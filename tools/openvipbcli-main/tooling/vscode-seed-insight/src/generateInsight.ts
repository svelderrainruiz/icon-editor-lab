import * as vscode from "vscode";
import * as fs from "fs";
import * as path from "path";

export async function generateInsight(workspacePath: string): Promise<boolean> {
    const id = await vscode.window.showInputBox({ prompt: "Insight ID" });
    if (!id) {
        return false;
    }
    const timestamp = new Date().toISOString();
    const content = { id, timestamp, data: {} };
    const json    = JSON.stringify(content, null, 2);
    const fileName = `${id}.insight.json`;
    const filePath = path.join(workspacePath, fileName);

    try {
        fs.writeFileSync(filePath, json, "utf8");
        const doc = await vscode.workspace.openTextDocument(filePath);
        await vscode.window.showTextDocument(doc);
        // auto-stage the new file
        vscode.commands.executeCommand("git.stage", vscode.Uri.file(filePath));
        vscode.window.showInformationMessage(`Created Insight: ${fileName}`);
        return true;
    } catch (err) {
        vscode.window.showErrorMessage(`Failed to create insight: ${err}`);
        return false;
    }
}
