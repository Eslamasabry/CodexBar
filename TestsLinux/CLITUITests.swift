import CodexBarCore
import Testing
@testable import CodexBarCLI

struct CLITUITests {
    @Test
    func `moves through every provider card and can focus one provider`() {
        var state = CLITUIState(dashboard: self.dashboard())

        #expect(state.selectedCard?.provider == .codex)
        #expect(state.visibleIndices.count == 3)

        _ = state.apply(.next)
        #expect(state.selectedCard?.provider == .claude)

        _ = state.apply(.toggleProviderFocus)
        #expect(state.focusedProvider == .claude)
        #expect(state.visibleIndices.count == 2)
        #expect(state.selectedCard?.provider == .claude)

        _ = state.apply(.next)
        #expect(state.selectedCard?.accountLine == "@ work@example.com")

        _ = state.apply(.toggleProviderFocus)
        #expect(state.focusedProvider == nil)
        #expect(state.visibleIndices.count == 3)
    }

    @Test
    func `preserves the selected provider account when refreshed`() {
        var state = CLITUIState(dashboard: self.dashboard())
        _ = state.apply(.next)
        _ = state.apply(.next)

        state.replaceDashboard(self.dashboard(claudeRemaining: 30))

        #expect(state.selectedCard?.provider == .claude)
        #expect(state.selectedCard?.accountLine == "@ work@example.com")
        #expect(state.selectedCard?.metrics.first?.remainingPercent == 30)
    }

    @Test
    func `renders all-provider overview with selected provider detail and failures`() {
        let state = CLITUIState(dashboard: self.dashboard())
        let output = CLITUIRenderer.render(state: state, terminalWidth: 80, showsHelp: false, isRefreshing: false)

        #expect(output.contains("all providers"))
        #expect(output.contains("Codex"))
        #expect(output.contains("Claude"))
        #expect(output.contains("Cursor: source unavailable"))
        #expect(output.contains("j/k: select"))
    }

    private func dashboard(claudeRemaining: Double = 60) -> CLICardsDashboard {
        CLICardsDashboard(
            cards: [
                self.card(provider: .codex, title: "Codex", accountLine: "@ personal@example.com", remaining: 80),
                self.card(provider: .claude, title: "Claude", accountLine: "@ personal@example.com", remaining: 60),
                self.card(
                    provider: .claude,
                    title: "Claude",
                    accountLine: "@ work@example.com",
                    remaining: claudeRemaining),
            ],
            failures: [.init(provider: .cursor, accountLabel: nil, message: "source unavailable")],
            exitCode: .failure)
    }

    private func card(provider: UsageProvider, title: String, accountLine: String, remaining: Double) -> CLICardModel {
        CLICardModel(
            provider: provider,
            title: title,
            sourceLabel: "oauth",
            planBadge: nil,
            accountLine: accountLine,
            infoLines: [],
            metrics: [.init(label: "Session", remainingPercent: remaining, resetText: "Resets in 2h")],
            extraLines: [],
            statusLine: nil)
    }
}
