import CodexBarCore
import Testing
@testable import CodexBarCLI

struct CLITUITests {
    @Test
    func `decodes terminal arrows without treating them as quit`() {
        #expect(CLITUIKeyDecoder.action(firstByte: 27, escapeBytes: [91, 65]) == .up)
        #expect(CLITUIKeyDecoder.action(firstByte: 27, escapeBytes: [91, 66]) == .down)
        #expect(CLITUIKeyDecoder.action(firstByte: 27, escapeBytes: [91, 67]) == .next)
        #expect(CLITUIKeyDecoder.action(firstByte: 27, escapeBytes: [91, 68]) == .previous)
        #expect(CLITUIKeyDecoder.action(firstByte: 27) == .back)
    }

    @Test
    func `moves through every provider card and can focus one provider`() {
        var state = CLITUIState(dashboard: self.dashboard())

        #expect(state.selectedCard?.provider == .codex)
        #expect(state.visibleIndices.count == 4)

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
        #expect(state.visibleIndices.count == 4)
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
        let output = CLITUIRenderer.render(
            state: state,
            terminalWidth: 80,
            terminalHeight: 52,
            showsHelp: false,
            isRefreshing: false)

        #expect(output.contains("CodexBar / Usage limits"))
        #expect(output.contains("Codex"))
        #expect(output.contains("Claude"))
        #expect(output.contains("Cursor"))
        #expect(output.contains("source unavailable"))
        #expect(output.contains("j/k: next/previous"))
    }

    @Test
    func `renders a bento grid with every provider metric and inline failure tile`() {
        let state = CLITUIState(dashboard: self.dashboard())
        let output = CLITUIRenderer.render(
            state: state,
            terminalWidth: 99,
            terminalHeight: 52,
            showsHelp: false,
            isRefreshing: false)

        #expect(output.contains("Capacity cue:"))
        #expect(output.contains("● ample (70%+)"))
        #expect(output.contains("┌"))
        #expect(output.contains("["))
        #expect(output.contains(">"))
        #expect(output.contains("reset in 2h"))
        #expect(output.contains("source: oauth"))
        #expect(output.contains("Session"))
        #expect(output.contains("Weekly"))
        #expect(output.contains("Cursor"))
        #expect(output.contains("ACTION NEEDED"))
    }

    @Test
    func `grid navigation and detail mode preserve provider identity`() {
        var state = CLITUIState(dashboard: self.dashboard())
        _ = state.apply(.down, columns: 2)
        #expect(state.selectedCard?.provider == .claude)
        #expect(state.selectedCard?.accountLine == "@ work@example.com")

        _ = state.apply(.enter, columns: 2)
        #expect(state.screen == .detail)
        _ = state.apply(.back, columns: 2)
        #expect(state.screen == .overview)
        #expect(state.selectedCard?.accountLine == "@ work@example.com")
    }

    @Test
    func `refresh failure retains a stale provider tile`() {
        var state = CLITUIState(dashboard: self.dashboard())
        state.replaceDashboard(CLICardsDashboard(
            cards: [],
            failures: [.init(provider: .codex, accountLabel: nil, message: "authentication expired")],
            exitCode: .failure,
            providerOrder: [.codex]))

        #expect(state.selectedTile?.isStale == true)
        #expect(state.selectedTile?.failure?.message == "authentication expired")
    }

    private func dashboard(claudeRemaining: Double = 60) -> CLICardsDashboard {
        CLICardsDashboard(
            cards: [
                self.card(
                    provider: .codex,
                    title: "Codex",
                    accountLine: "@ personal@example.com",
                    remaining: 80,
                    extraMetrics: [.init(label: "Weekly", remainingPercent: 95, resetText: "Reset in 6d")]),
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

    private func card(
        provider: UsageProvider,
        title: String,
        accountLine: String,
        remaining: Double,
        extraMetrics: [CLICardMetric] = []) -> CLICardModel
    {
        CLICardModel(
            provider: provider,
            title: title,
            sourceLabel: "oauth",
            planBadge: nil,
            accountLine: accountLine,
            infoLines: [],
            metrics: [.init(label: "Session", remainingPercent: remaining, resetText: "Resets in 2h")] + extraMetrics,
            extraLines: [],
            statusLine: nil)
    }
}
