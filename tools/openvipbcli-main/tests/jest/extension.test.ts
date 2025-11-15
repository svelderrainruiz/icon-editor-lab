jest.mock('vscode');
import * as vscode from "vscode";
import { activate } from "../../tooling/vscode-seed-insight/src/extension";

describe("Seed Insight extension", () => {
  it("registers at least one command on activate", () => {
    const ctx = { subscriptions: [] } as unknown as vscode.ExtensionContext;
    activate(ctx);
    expect(ctx.subscriptions.length).toBeGreaterThan(0);
  });
});
