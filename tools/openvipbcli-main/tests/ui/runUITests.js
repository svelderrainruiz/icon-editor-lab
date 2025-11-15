const path = require('path');
const { runTests } = require('@vscode/test-electron');

async function main() {
    try {
        const extensionDevelopmentPath = path.resolve(__dirname, '../../tooling/vscode-seed-insight');
        const extensionTestsPath = path.resolve(__dirname, 'basic.test.js');
        await runTests({ extensionDevelopmentPath, extensionTestsPath });
    } catch (err) {
        console.error('Failed to run VS Code UI tests', err);
        process.exit(1);
    }
}

main();
