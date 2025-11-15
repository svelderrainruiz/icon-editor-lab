# VS Code Extension Setup

This guide explains how to build, package, install, and test the **Seed Insight** VS Code extension.

## Building the Extension

1. Open a terminal and navigate to the `tooling/vscode-seed-insight` directory of this repository.
2. Install the extension's dependencies by running:  
   ```bash
   npm install
   ```
3. Build the extension by compiling the TypeScript source into JavaScript:  
   ```bash
   npm run build
   ```
   This will produce the compiled extension files in the `dist` folder.

## Packaging the Extension

4. Package the extension into a VSIX file by running:  
   ```bash
   npm run package
   ```
   This uses the VS Code Extension Manager (**vsce**) to bundle the extension. After this step, you should see a file with the `.vsix` extension (for example, `seed-insight-0.0.1.vsix`) generated in the `tooling/vscode-seed-insight` directory.

## Installing the Extension

5. Open Visual Studio Code and go to the **Extensions** view.
6. Click the **...** (ellipsis) menu at the top-right of the Extensions panel and choose **Install from VSIX...**.
7. Select the generated `.vsix` file. VS Code will install the extension. You may need to **Reload** VS Code after installation if prompted.

## Testing the Extension

8. After installation, activate the extension by opening the Command Palette (`Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
9. Run the command **Generate Insight** (start typing "Insight" to find it in the palette).  
   - If no workspace folder is open, the extension will show an error message prompting you to open a folder.
   - If a folder is open, the command will attempt to generate an "Insight"; you should then see the status bar update to "Seed Insight: Generated" if it succeeds.
10. (Optional) If you have a Git repository open in VS Code, try the **Seed Insight: Stage & Commit** command from the Command Palette. This will stage all changes (or a specific file if you invoked the command on a file) and then open the VS Code source control view to commit, with a pre-filled commit message.

