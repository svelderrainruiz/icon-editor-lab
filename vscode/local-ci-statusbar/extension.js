const vscode = require('vscode');

function runTask(label) {
  return vscode.commands.executeCommand('workbench.action.tasks.runTask', label);
}

function createButton(text, tooltip, commandId, alignment = vscode.StatusBarAlignment.Right, priority = 100) {
  const item = vscode.window.createStatusBarItem(alignment, priority);
  item.text = text;
  item.tooltip = tooltip;
  item.command = commandId;
  item.show();
  return item;
}

/**
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  const enableLabel = 'Local CI: Stage 25 DevMode (enable)';
  const disableLabel = 'Local CI: Stage 25 DevMode (disable)';
  const toggleLabel = 'Local CI: Stage 25 DevMode (debug)';

  const cmdEnable = vscode.commands.registerCommand('localci.enableDevMode', async () => {
    await runTask(enableLabel);
  });
  const cmdDisable = vscode.commands.registerCommand('localci.disableDevMode', async () => {
    await runTask(disableLabel);
  });
  const cmdToggle = vscode.commands.registerCommand('localci.toggleDevMode', async () => {
    await runTask(toggleLabel);
  });

  context.subscriptions.push(cmdEnable, cmdDisable, cmdToggle);

  // Status bar buttons
  const btnEnable = createButton("$(debug-start) DevMode", "Enable Dev Mode (Stage 25)", 'localci.enableDevMode', vscode.StatusBarAlignment.Left, 100);
  const btnDisable = createButton("$(debug-stop) DevMode", "Disable Dev Mode (Stage 25)", 'localci.disableDevMode', vscode.StatusBarAlignment.Left, 99);
  const btnToggle = createButton("$(sync) DevMode", "Toggle Dev Mode (Stage 25)", 'localci.toggleDevMode', vscode.StatusBarAlignment.Left, 98);

  context.subscriptions.push(btnEnable, btnDisable, btnToggle);
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
}

