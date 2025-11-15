const vscode = require('vscode');
const assert = require('assert');

(async () => {
    try {
        const ext = vscode.extensions.getExtension('labview-community.seed-insight');
        assert.ok(ext, 'Extension not found');
        await ext.activate();
        assert.ok(ext.isActive, 'Extension activation failed');
        await vscode.commands.executeCommand('seedInsight.generate');
        console.log('✅ Extension command executed successfully');
    } catch (err) {
        console.error('UI Test failed:', err);
        process.exit(1);
    }
})();
