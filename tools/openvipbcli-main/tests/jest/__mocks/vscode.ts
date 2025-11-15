// Jest manual mock for the "vscode" module
export const commands = { executeCommand: jest.fn() };
export const window = {
  createStatusBarItem: () => ({
    text: "",
    show: jest.fn(),
    dispose: jest.fn(),
    tooltip: "",
    command: "",
  }),
  showInformationMessage: jest.fn(),
  showErrorMessage: jest.fn(),
  showInputBox: jest.fn().mockResolvedValue("test-insight-id"),
  showTextDocument: jest.fn(),
};
export const workspace = {
  workspaceFolders: [{ uri: { fsPath: "/mock-root" } }],
  openTextDocument: jest.fn().mockResolvedValue({}),
};
export const extensions = {
  getExtension: jest.fn(() => ({
    id: "mock-extension",
    packageJSON: { version: "1.0.0" },
    exports: {},
  })),
};
