import CodexBarCore
import Commander
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import Foundation

enum CLITUIAction: Equatable {
    case previous
    case next
    case refresh
    case toggleProviderFocus
    case toggleHelp
    case quit
    case none
}

enum CLITUIKeyDecoder {
    static func action(firstByte: UInt8, escapeBytes: [UInt8] = []) -> CLITUIAction {
        switch firstByte {
        case 3, 113:
            return .quit
        case 106:
            return .next
        case 107:
            return .previous
        case 114:
            return .refresh
        case 102:
            return .toggleProviderFocus
        case 63:
            return .toggleHelp
        case 27:
            guard escapeBytes.count == 2, escapeBytes[0] == 91 else { return .quit }
            return switch escapeBytes[1] {
            case 65: .previous
            case 66: .next
            default: .none
            }
        default:
            return .none
        }
    }
}

struct CLITUIState {
    private(set) var cards: [CLICardModel]
    private(set) var failures: [CLICardFailure]
    private(set) var exitCode: ExitCode
    private(set) var selectedIndex: Int = 0
    private(set) var focusedProvider: UsageProvider?

    init(dashboard: CLICardsDashboard) {
        self.cards = dashboard.cards
        self.failures = dashboard.failures
        self.exitCode = dashboard.exitCode
        self.selectedIndex = 0
    }

    var visibleIndices: [Int] {
        self.cards.indices.filter { index in
            guard let focusedProvider else { return true }
            return self.cards[index].provider == focusedProvider
        }
    }

    var selectedCard: CLICardModel? {
        guard self.cards.indices.contains(self.selectedIndex) else { return nil }
        return self.cards[self.selectedIndex]
    }

    var selectedPosition: Int? {
        self.visibleIndices.firstIndex(of: self.selectedIndex)
    }

    mutating func apply(_ action: CLITUIAction) -> Bool {
        switch action {
        case .previous:
            self.moveSelection(by: -1)
        case .next:
            self.moveSelection(by: 1)
        case .toggleProviderFocus:
            self.toggleProviderFocus()
        case .quit:
            return true
        case .refresh, .toggleHelp, .none:
            break
        }
        return false
    }

    mutating func replaceDashboard(_ dashboard: CLICardsDashboard) {
        let selectedIdentity = self.selectedCard.map { ($0.provider, $0.title, $0.accountLine) }
        self.cards = dashboard.cards
        self.failures = dashboard.failures
        self.exitCode = dashboard.exitCode

        if let selectedIdentity,
           let index = self.cards.firstIndex(where: {
               $0.provider == selectedIdentity.0
                   && $0.title == selectedIdentity.1
                   && $0.accountLine == selectedIdentity.2
           })
        {
            self.selectedIndex = index
        } else {
            self.selectedIndex = min(self.selectedIndex, max(0, self.cards.count - 1))
        }

        if let focusedProvider, !self.cards.contains(where: { $0.provider == focusedProvider }) {
            self.focusedProvider = nil
        }
        self.ensureVisibleSelection()
    }

    private mutating func moveSelection(by delta: Int) {
        let visibleIndices = self.visibleIndices
        guard !visibleIndices.isEmpty else { return }
        let currentPosition = visibleIndices.firstIndex(of: self.selectedIndex) ?? 0
        let nextPosition = (currentPosition + delta + visibleIndices.count) % visibleIndices.count
        self.selectedIndex = visibleIndices[nextPosition]
    }

    private mutating func toggleProviderFocus() {
        guard let selectedCard else {
            self.focusedProvider = nil
            return
        }
        self.focusedProvider = self.focusedProvider == selectedCard.provider ? nil : selectedCard.provider
        self.ensureVisibleSelection()
    }

    private mutating func ensureVisibleSelection() {
        if let firstVisible = self.visibleIndices.first, !self.visibleIndices.contains(self.selectedIndex) {
            self.selectedIndex = firstVisible
        }
    }
}

enum CLITUIRenderer {
    static func render(
        state: CLITUIState,
        terminalWidth: Int,
        showsHelp: Bool,
        isRefreshing: Bool) -> String
    {
        let width = max(36, terminalWidth)
        let header = self.header(state: state, isRefreshing: isRefreshing)
        if showsHelp {
            return [header, "", self.helpText].joined(separator: "\n")
        }

        var lines = [header, "", self.overview(state: state, width: width)]
        guard let card = state.selectedCard else {
            if !state.failures.isEmpty {
                lines.append(self.safe(CLICardsRenderer.renderFailuresOnly(state.failures, useColor: false)))
            }
            lines.append("")
            lines.append(self.controls)
            return lines.joined(separator: "\n")
        }

        let selection = state.selectedPosition.map { "\($0 + 1)/\(state.visibleIndices.count)" } ?? "0/0"
        lines.append("")
        lines.append("Selected \(selection)")
        lines.append(contentsOf: CLICardsRenderer.renderCard(card, width: width, useColor: false).map(self.safe))
        if !state.failures.isEmpty {
            lines.append("")
            lines.append(self.safe(CLICardsRenderer.renderFailuresOnly(state.failures, useColor: false)))
        }
        lines.append("")
        lines.append(self.controls)
        return lines.joined(separator: "\n")
    }

    private static func header(state: CLITUIState, isRefreshing: Bool) -> String {
        let scope = state.focusedProvider.map { " • \($0.rawValue)" } ?? " • all providers"
        let refresh = isRefreshing ? " • refreshing" : ""
        return "CodexBar Usage TUI\(scope)\(refresh)"
    }

    private static func overview(state: CLITUIState, width: Int) -> String {
        let indices = state.visibleIndices
        guard !indices.isEmpty else {
            return "No provider snapshots are available. Refresh after configuring a supported local source."
        }
        let rows = indices.map { index in
            self.overviewRow(card: state.cards[index], selected: index == state.selectedIndex, width: width)
        }
        return (["Provider overview"] + rows).joined(separator: "\n")
    }

    private static func overviewRow(card: CLICardModel, selected: Bool, width: Int) -> String {
        let marker = selected ? ">" : " "
        let metric: String = if let firstMetric = card.metrics.first {
            "\(firstMetric.label) \(Int(firstMetric.remainingPercent.rounded()))% left"
        } else if let firstInfo = card.infoLines.first {
            firstInfo
        } else {
            "Limits unavailable"
        }
        let account = card.accountLine.map { " \($0)" } ?? ""
        let raw = "\(marker) \(card.title) [\(card.sourceLabel)]\(account) — \(metric)"
        return self.fit(raw, width: width)
    }

    private static func fit(_ value: String, width: Int) -> String {
        let safeValue = self.safe(value)
        guard safeValue.count > width else { return safeValue }
        return String(safeValue.prefix(max(1, width - 1))) + "…"
    }

    private static func safe(_ value: String) -> String {
        String(value.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar)
        })
    }

    private static let controls = "j/k: select • f: provider focus • r: refresh • ?: help • q: quit"

    private static let helpText = [
        "Keyboard shortcuts",
        "",
        "  j         Select next provider account",
        "  k         Select previous provider account",
        "  f         Show only the selected provider's accounts; press again for all providers",
        "  r         Re-fetch selected providers using the existing configured sources",
        "  ?         Toggle this help",
        "  q / Esc   Quit",
        "",
        "The TUI uses the same provider registry and fetch pipeline as `codexbar cards`.",
        "It does not read provider credentials itself, and unavailable providers remain explicit failures.",
    ].joined(separator: "\n")
}

final class CLIRawTerminal {
    private var originalAttributes: termios?
    private var isActive = false

    static var isInteractive: Bool {
        isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    }

    init() throws {
        guard Self.isInteractive else {
            throw CLIArgumentError("codexbar tui requires an interactive terminal; use codexbar cards for a snapshot.")
        }

        var attributes = termios()
        guard tcgetattr(STDIN_FILENO, &attributes) == 0 else {
            throw CLIArgumentError("Could not read terminal settings for interactive mode.")
        }
        self.originalAttributes = attributes

        var raw = attributes
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG)
        withUnsafeMutableBytes(of: &raw.c_cc) { bytes in
            bytes[Int(VMIN)] = 1
            bytes[Int(VTIME)] = 0
        }
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw CLIArgumentError("Could not enable terminal input for interactive mode.")
        }
        self.isActive = true
        self.write("\u{001B}[?1049h\u{001B}[?25l")
    }

    deinit {
        self.restore()
    }

    func render(_ content: String) {
        self.write("\u{001B}[H\u{001B}[2J\(content)")
    }

    func readAction() -> CLITUIAction {
        guard let firstByte = self.readByte() else { return .quit }
        guard firstByte == 27 else {
            return CLITUIKeyDecoder.action(firstByte: firstByte)
        }
        let escapeBytes = [
            self.readByte(timeoutMilliseconds: 25),
            self.readByte(timeoutMilliseconds: 25),
        ].compactMap(\.self)
        return CLITUIKeyDecoder.action(firstByte: firstByte, escapeBytes: escapeBytes)
    }

    func restore() {
        guard self.isActive else { return }
        if var originalAttributes = self.originalAttributes {
            _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalAttributes)
        }
        self.write("\u{001B}[?25h\u{001B}[?1049l")
        self.isActive = false
    }

    private func write(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func readByte(timeoutMilliseconds: Int32? = nil) -> UInt8? {
        if let timeoutMilliseconds {
            var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            guard poll(&descriptor, 1, timeoutMilliseconds) > 0 else { return nil }
        }
        var byte: UInt8 = 0
        let readCount = withUnsafeMutableBytes(of: &byte) { buffer in
            read(STDIN_FILENO, buffer.baseAddress, 1)
        }
        return readCount == 1 ? byte : nil
    }
}

extension CodexBarCLI {
    static func runTUI(_ values: ParsedValues) async {
        let output = CLIOutputPreferences.from(values: values)
        if values.flags.contains("brief") {
            Self.exit(
                code: .failure,
                message: "--brief is only available with codexbar cards.",
                output: output,
                kind: .args)
        }
        guard CLIRawTerminal.isInteractive else {
            Self.exit(
                code: .failure,
                message: "codexbar tui requires an interactive terminal; use codexbar cards for a snapshot.",
                output: output,
                kind: .args)
        }

        let initialDashboard = await Self.fetchCardsDashboard(values)
        var state = CLITUIState(dashboard: initialDashboard)
        var terminal: CLIRawTerminal?
        do {
            terminal = try CLIRawTerminal()
        } catch {
            Self.exit(code: .failure, message: error.localizedDescription, output: output, kind: .runtime)
        }

        defer { terminal?.restore() }
        var showsHelp = false
        var isRefreshing = false

        while true {
            guard let activeTerminal = terminal else { break }
            activeTerminal.render(CLITUIRenderer.render(
                state: state,
                terminalWidth: CLICardsRenderer.terminalColumnCount(),
                showsHelp: showsHelp,
                isRefreshing: isRefreshing))

            let action = activeTerminal.readAction()
            if action == .refresh {
                isRefreshing = true
                activeTerminal.render(CLITUIRenderer.render(
                    state: state,
                    terminalWidth: CLICardsRenderer.terminalColumnCount(),
                    showsHelp: showsHelp,
                    isRefreshing: isRefreshing))
                activeTerminal.restore()
                let dashboard = await Self.fetchCardsDashboard(values)
                state.replaceDashboard(dashboard)
                isRefreshing = false
                do {
                    terminal = try CLIRawTerminal()
                } catch {
                    Self.exit(code: .failure, message: error.localizedDescription, output: output, kind: .runtime)
                }
                continue
            }
            if action == .toggleHelp {
                showsHelp.toggle()
                continue
            }
            if state.apply(action) {
                activeTerminal.restore()
                Self.exit(
                    code: state.exitCode,
                    output: output,
                    kind: state.exitCode == ExitCode.success ? .runtime : .provider)
            }
        }
    }
}
