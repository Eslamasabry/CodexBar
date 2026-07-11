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
    case up
    case down
    case enter
    case back
    case refresh
    case toggleProviderFocus
    case toggleHelp
    case quit
    case none
}

enum CLITUIKeyDecoder {
    static func action(firstByte: UInt8, escapeBytes: [UInt8] = []) -> CLITUIAction {
        if firstByte == 27 {
            guard escapeBytes.count == 2, escapeBytes[0] == 91 else { return .back }
            return switch escapeBytes[1] {
            case 65: .up
            case 66: .down
            case 67: .next
            case 68: .previous
            default: .none
            }
        }
        return switch firstByte {
        case 3, 113:
            .quit
        case 10, 13:
            .enter
        case 106:
            .next
        case 107:
            .previous
        case 114:
            .refresh
        case 102:
            .toggleProviderFocus
        case 63:
            .toggleHelp
        default:
            .none
        }
    }
}

enum CLITUIScreen: Equatable {
    case overview
    case detail
}

enum CLITUITile: Equatable {
    case card(CLICardModel)
    case stale(CLICardModel, CLICardFailure)
    case failure(CLICardFailure)

    var provider: UsageProvider {
        switch self {
        case let .card(card), let .stale(card, _): card.provider
        case let .failure(failure): failure.provider
        }
    }

    var card: CLICardModel? {
        switch self {
        case let .card(card), let .stale(card, _): card
        case .failure: nil
        }
    }

    var failure: CLICardFailure? {
        switch self {
        case .card: nil
        case let .stale(_, failure), let .failure(failure): failure
        }
    }

    var title: String {
        self.card?.title
            ?? ProviderDescriptorRegistry.descriptor(for: self.provider).metadata.displayName
    }

    var accountLine: String? {
        self.card?.accountLine ?? self.failure?.accountLabel
    }

    var identity: (UsageProvider, String, String?) {
        (self.provider, self.title, self.accountLine)
    }

    var isStale: Bool {
        if case .stale = self { return true }
        return false
    }
}

struct CLITUIState {
    private(set) var tiles: [CLITUITile]
    private(set) var exitCode: ExitCode
    private(set) var selectedIndex: Int = 0
    private(set) var focusedProvider: UsageProvider?
    private(set) var screen: CLITUIScreen = .overview
    private(set) var detailScrollOffset: Int = 0

    init(dashboard: CLICardsDashboard) {
        self.tiles = Self.makeTiles(from: dashboard, previous: [])
        self.exitCode = dashboard.exitCode
    }

    var visibleIndices: [Int] {
        self.tiles.indices.filter { index in
            guard let focusedProvider else { return true }
            return self.tiles[index].provider == focusedProvider
        }
    }

    var selectedTile: CLITUITile? {
        guard self.tiles.indices.contains(self.selectedIndex) else { return nil }
        return self.tiles[self.selectedIndex]
    }

    var selectedCard: CLICardModel? {
        self.selectedTile?.card
    }

    var selectedPosition: Int? {
        self.visibleIndices.firstIndex(of: self.selectedIndex)
    }

    mutating func apply(_ action: CLITUIAction, columns: Int = 1) -> Bool {
        switch action {
        case .previous:
            self.moveSelection(by: -1)
        case .next:
            self.moveSelection(by: 1)
        case .up:
            if self.screen == .detail {
                self.detailScrollOffset = max(0, self.detailScrollOffset - 1)
            } else {
                self.moveGrid(by: -1, columns: columns)
            }
        case .down:
            if self.screen == .detail {
                self.detailScrollOffset += 1
            } else {
                self.moveGrid(by: 1, columns: columns)
            }
        case .enter:
            guard self.selectedTile != nil else { return false }
            self.screen = .detail
            self.detailScrollOffset = 0
        case .back:
            if self.screen == .detail {
                self.screen = .overview
                self.detailScrollOffset = 0
            } else {
                return true
            }
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
        let selectedIdentity = self.selectedTile?.identity
        self.tiles = Self.makeTiles(from: dashboard, previous: self.tiles)
        self.exitCode = dashboard.exitCode

        if let selectedIdentity,
           let index = self.tiles.firstIndex(where: { $0.identity == selectedIdentity })
        {
            self.selectedIndex = index
        } else {
            self.selectedIndex = min(self.selectedIndex, max(0, self.tiles.count - 1))
        }

        if let focusedProvider, !self.tiles.contains(where: { $0.provider == focusedProvider }) {
            self.focusedProvider = nil
        }
        self.ensureVisibleSelection()
    }

    private static func makeTiles(from dashboard: CLICardsDashboard, previous: [CLITUITile]) -> [CLITUITile] {
        let previousCards = Dictionary(grouping: previous.compactMap(\.card), by: \.provider)
        let cardsByProvider = Dictionary(grouping: dashboard.cards, by: \.provider)
        let failuresByProvider = Dictionary(grouping: dashboard.failures, by: \.provider)
        var providerOrder = dashboard.providerOrder
        for provider in dashboard.cards.map(\.provider) + dashboard.failures.map(\.provider)
            where !providerOrder.contains(provider)
        {
            providerOrder.append(provider)
        }

        var tiles: [CLITUITile] = []
        for provider in providerOrder {
            let cards = cardsByProvider[provider] ?? []
            let failures = failuresByProvider[provider] ?? []
            if !cards.isEmpty {
                tiles.append(contentsOf: cards.map(CLITUITile.card))
                tiles.append(contentsOf: failures.map(CLITUITile.failure))
                continue
            }
            guard !failures.isEmpty else { continue }
            var retained = previousCards[provider] ?? []
            for failure in failures {
                if let index = retained.firstIndex(where: {
                    failure.accountLabel == nil || $0.accountLine == failure.accountLabel
                }) {
                    tiles.append(.stale(retained.remove(at: index), failure))
                } else {
                    tiles.append(.failure(failure))
                }
            }
        }
        return tiles
    }

    private mutating func moveSelection(by delta: Int) {
        let visibleIndices = self.visibleIndices
        guard !visibleIndices.isEmpty else { return }
        let currentPosition = visibleIndices.firstIndex(of: self.selectedIndex) ?? 0
        let nextPosition = (currentPosition + delta + visibleIndices.count) % visibleIndices.count
        self.selectedIndex = visibleIndices[nextPosition]
        self.detailScrollOffset = 0
    }

    private mutating func moveGrid(by rowDelta: Int, columns: Int) {
        let visibleIndices = self.visibleIndices
        guard !visibleIndices.isEmpty else { return }
        let currentPosition = visibleIndices.firstIndex(of: self.selectedIndex) ?? 0
        let step = max(1, columns)
        let proposed = currentPosition + rowDelta * step
        guard visibleIndices.indices.contains(proposed) else { return }
        self.selectedIndex = visibleIndices[proposed]
        self.detailScrollOffset = 0
    }

    private mutating func toggleProviderFocus() {
        guard let selectedTile else {
            self.focusedProvider = nil
            return
        }
        self.focusedProvider = self.focusedProvider == selectedTile.provider ? nil : selectedTile.provider
        self.ensureVisibleSelection()
    }

    private mutating func ensureVisibleSelection() {
        if let firstVisible = self.visibleIndices.first, !self.visibleIndices.contains(self.selectedIndex) {
            self.selectedIndex = firstVisible
        }
    }
}

enum CLITUIRenderer {
    private static let tileGap = 2

    static func columnCount(terminalWidth: Int) -> Int {
        switch terminalWidth {
        case 140...: 3
        case 92...: 2
        default: 1
        }
    }

    static func render(
        state: CLITUIState,
        terminalWidth: Int,
        terminalHeight: Int = 24,
        showsHelp: Bool,
        isRefreshing: Bool,
        useColor: Bool = false) -> String
    {
        let width = max(36, terminalWidth)
        let height = max(12, terminalHeight)
        let header = self.header(state: state, width: width, isRefreshing: isRefreshing, useColor: useColor)
        if showsHelp {
            return self.viewport(
                lines: [header, "", self.helpText],
                selectedLine: nil,
                width: width,
                height: height)
                .joined(separator: "\n")
        }
        if state.screen == .detail {
            return self.renderDetail(state: state, width: width, height: height, useColor: useColor)
        }

        let capacity = self.capacityCue(state: state, width: width, useColor: useColor)
        let grid = self.renderGrid(state: state, width: width, useColor: useColor)
        let prefix = [header, capacity, ""]
        let bodyHeight = max(8, height - prefix.count - 2)
        let visibleGrid = self.viewport(
            lines: grid.lines,
            selectedLine: grid.selectedLine,
            width: width,
            height: bodyHeight)
        return (prefix + visibleGrid + ["", self.controls]).joined(separator: "\n")
    }

    private static func renderDetail(
        state: CLITUIState,
        width: Int,
        height: Int,
        useColor: Bool) -> String
    {
        let heading = self.fit("CodexBar / Provider detail", width: width)
        guard let tile = state.selectedTile else {
            return [heading, "", "No provider detail is available.", "", self.detailControls]
                .joined(separator: "\n")
        }
        let detail = self.renderTile(tile, selected: true, width: width, useColor: useColor, detail: true)
        let bodyHeight = max(6, height - 4)
        let offset = min(state.detailScrollOffset, max(0, detail.count - bodyHeight))
        let visible = Array(detail.dropFirst(offset).prefix(bodyHeight))
        let scrollHint = detail.count > bodyHeight ? "↑/↓ scroll" : ""
        return [
            heading,
            "",
            visible.joined(separator: "\n"),
            "",
            self.detailControls + (scrollHint.isEmpty ? "" : " • \(scrollHint)"),
        ]
            .joined(separator: "\n")
    }

    private static func header(state: CLITUIState, width: Int, isRefreshing: Bool, useColor: Bool) -> String {
        let scope = state.focusedProvider.map(\.rawValue) ?? "all providers"
        let activity = isRefreshing ? "refreshing" : "live"
        let left = "CodexBar / Usage limits"
        let right = "\(scope) • \(activity)"
        return self.paired(left, right, width: width)
    }

    private static func capacityCue(state: CLITUIState, width: Int, useColor: Bool) -> String {
        let cards = state.visibleIndices.compactMap { index -> CLICardModel? in
            let tile = state.tiles[index]
            return tile.isStale ? nil : tile.card
        }
        let entries = cards.compactMap { card -> (card: CLICardModel, remaining: Double, metric: CLICardMetric)? in
            guard let metric = card.metrics.min(by: { $0.remainingPercent < $1.remainingPercent }) else { return nil }
            return (card, metric.remainingPercent, metric)
        }
        guard !entries.isEmpty else {
            return "Capacity cue: no fresh quota snapshot yet"
        }

        let strongest = entries.max(by: { $0.remaining < $1.remaining })!
        let lowest = entries.min(by: { $0.remaining < $1.remaining })!
        let reset = cards.flatMap { card in
            card.metrics.compactMap { metric -> (CLICardModel, CLICardMetric)? in
                metric.resetAt == nil ? nil : (card, metric)
            }
        }.min(by: { ($0.1.resetAt ?? .distantFuture) < ($1.1.resetAt ?? .distantFuture) })

        var parts = [
            "Headroom: \(strongest.card.title) \(self.percent(strongest.remaining))",
            "lowest: \(lowest.card.title) \(lowest.metric.label) \(self.percent(lowest.remaining))",
        ]
        if let reset, let resetText = reset.1.resetText {
            parts.append("next reset: \(reset.0.title) \(self.resetLabel(resetText))")
        }
        return self.fit("Capacity cue: " + parts.joined(separator: " • "), width: width)
    }

    private static func renderGrid(
        state: CLITUIState,
        width: Int,
        useColor: Bool) -> (lines: [String], selectedLine: Int?)
    {
        let indices = state.visibleIndices
        guard !indices.isEmpty else {
            return (["No provider snapshots are available. Configure a supported local source, then refresh."], nil)
        }
        if width < 56 {
            let lines = indices.flatMap { index in
                self.renderCompactTile(
                    state.tiles[index],
                    selected: index == state.selectedIndex,
                    width: width,
                    useColor: useColor)
            }
            let selectedLine = indices.firstIndex(of: state.selectedIndex).map { $0 * 2 }
            return (lines, selectedLine)
        }

        let columns = self.columnCount(terminalWidth: width)
        let tileWidth = max(30, (width - (columns - 1) * self.tileGap) / columns)
        var lines: [String] = []
        var selectedLine: Int?
        for rowStart in stride(from: 0, to: indices.count, by: columns) {
            let rowIndices = Array(indices[rowStart..<min(rowStart + columns, indices.count)])
            let renderedTiles = rowIndices.map { index in
                (
                    index,
                    self.renderTile(
                        state.tiles[index],
                        selected: index == state.selectedIndex,
                        width: tileWidth,
                        useColor: useColor,
                        detail: false))
            }
            if rowIndices.contains(state.selectedIndex) {
                selectedLine = lines.count
            }
            let rowHeight = renderedTiles.map(\.1.count).max() ?? 0
            let tiles = renderedTiles.map { index, tileLines in
                self.verticallyCenteredTile(
                    tileLines,
                    targetHeight: rowHeight,
                    width: tileWidth,
                    selected: index == state.selectedIndex,
                    useColor: useColor)
            }
            let occupiedWidth = rowIndices.count * tileWidth + (rowIndices.count - 1) * self.tileGap
            let leadingSpace = String(repeating: " ", count: max(0, (width - occupiedWidth) / 2))
            for lineIndex in 0..<rowHeight {
                let parts = tiles.map { tileLines in
                    lineIndex < tileLines.count ? self.pad(tileLines[lineIndex], width: tileWidth) : String(
                        repeating: " ",
                        count: tileWidth)
                }
                lines.append(leadingSpace + parts.joined(separator: String(repeating: " ", count: self.tileGap)))
            }
            if rowStart + columns < indices.count { lines.append("") }
        }
        return (lines, selectedLine)
    }

    private static func renderTile(
        _ tile: CLITUITile,
        selected: Bool,
        width: Int,
        useColor: Bool,
        detail: Bool) -> [String]
    {
        let innerWidth = max(18, width - 4)
        let borderCode = selected ? "36" : "2"
        let top = self.paint(
            "╭" + String(repeating: "─", count: innerWidth + 2) + "╮",
            code: borderCode,
            enabled: useColor)
        let bottom = self.paint(
            "╰" + String(repeating: "─", count: innerWidth + 2) + "╯",
            code: borderCode,
            enabled: useColor)
        var lines = [top]
        let marker = selected ? "●" : " "
        let title = "\(marker) \(tile.title)"
        let plan = tile.card?.planBadge ?? ""
        lines.append(self.side(
            self.paired(title, plan, width: innerWidth),
            innerWidth: innerWidth,
            borderCode: borderCode,
            useColor: useColor))

        if let account = tile.accountLine, !account.isEmpty {
            let normalizedAccount = account.hasPrefix("@") ? String(account.dropFirst())
                .trimmingCharacters(in: .whitespaces) : account
            lines.append(self.side(
                self.centered("@ \(normalizedAccount)", width: innerWidth),
                innerWidth: innerWidth,
                borderCode: borderCode,
                useColor: useColor,
                dim: true))
        }

        if let card = tile.card {
            for metric in card.metrics {
                let right = [self.percent(metric.remainingPercent), metric.resetText.map(self.resetLabel)]
                    .compactMap(\.self)
                    .joined(separator: "  ")
                lines.append(self.side(
                    self.paired(metric.label, right, width: innerWidth),
                    innerWidth: innerWidth,
                    borderCode: borderCode,
                    useColor: useColor,
                    metric: metric.remainingPercent))
                lines.append(self.side(
                    "",
                    innerWidth: innerWidth,
                    borderCode: borderCode,
                    useColor: useColor))
                lines.append(self.side(
                    self.bar(remaining: metric.remainingPercent, width: max(6, innerWidth - 2)),
                    innerWidth: innerWidth,
                    borderCode: borderCode,
                    useColor: useColor,
                    metric: metric.remainingPercent))
                lines.append(self.side(
                    "",
                    innerWidth: innerWidth,
                    borderCode: borderCode,
                    useColor: useColor))
                if detail, let detailText = metric.detailText {
                    lines.append(self.side(
                        detailText,
                        innerWidth: innerWidth,
                        borderCode: borderCode,
                        useColor: useColor,
                        dim: true))
                }
            }

            let support = card.infoLines + card.extraLines + (card.statusLine.map { [$0] } ?? [])
            for line in support {
                lines.append(self.side(
                    self.alignedInfo(line, width: innerWidth),
                    innerWidth: innerWidth,
                    borderCode: borderCode,
                    useColor: useColor,
                    dim: true))
            }
            lines.append(self.side(
                self.paired(card.sourceLabel, self.freshness(card.updatedAt), width: innerWidth),
                innerWidth: innerWidth,
                borderCode: borderCode,
                useColor: useColor,
                dim: true))
        }

        if let failure = tile.failure {
            let label = tile.isStale ? "STALE" : "ACTION NEEDED"
            lines.append(self.side(label, innerWidth: innerWidth, borderCode: "31", useColor: useColor, dim: false))
            lines.append(contentsOf: self.wrapped(failure.message, width: innerWidth).map {
                self.side($0, innerWidth: innerWidth, borderCode: "31", useColor: useColor, dim: true)
            })
            if detail {
                lines.append(self.side(
                    "Run: codexbar diagnose --provider \(failure.provider.rawValue) --redact",
                    innerWidth: innerWidth,
                    borderCode: "31",
                    useColor: useColor,
                    dim: true))
            }
        }

        if tile.card == nil, tile.failure == nil {
            lines.append(self.side(
                "No quota data is available.",
                innerWidth: innerWidth,
                borderCode: borderCode,
                useColor: useColor,
                dim: true))
        }
        lines.append(bottom)
        return lines
    }

    private static func renderCompactTile(_ tile: CLITUITile, selected: Bool, width: Int, useColor: Bool) -> [String] {
        let marker = selected ? ">" : " "
        guard let card = tile.card else {
            return [self.fit(
                "\(marker) \(tile.title): action needed — \(tile.failure?.message ?? "unavailable")",
                width: width)]
        }
        let header = self.fit(
            "\(marker) \(card.title) [\(card.sourceLabel)] • \(self.freshness(card.updatedAt))",
            width: width)
        let metrics = card.metrics.map { metric in
            self.fit(
                "  \(metric.label): \(self.percent(metric.remainingPercent)) \(metric.resetText.map(self.resetLabel) ?? "")",
                width: width)
        }
        return [header] + metrics
    }

    private static func verticallyCenteredTile(
        _ lines: [String],
        targetHeight: Int,
        width: Int,
        selected: Bool,
        useColor: Bool) -> [String]
    {
        guard targetHeight > lines.count, let top = lines.first, let bottom = lines.last else { return lines }
        let missing = targetHeight - lines.count
        let upperPadding = missing / 2
        let lowerPadding = missing - upperPadding
        let empty = self.side(
            "",
            innerWidth: max(18, width - 4),
            borderCode: selected ? "36" : "2",
            useColor: useColor)
        return [top]
            + Array(repeating: empty, count: upperPadding)
            + lines.dropFirst().dropLast()
            + Array(repeating: empty, count: lowerPadding)
            + [bottom]
    }

    private static func viewport(
        lines: [String],
        selectedLine: Int?,
        width: Int,
        height: Int) -> [String]
    {
        guard lines.count > height else { return lines }
        let selected = selectedLine ?? 0
        let start = min(max(0, selected - height / 2), max(0, lines.count - height))
        let end = min(lines.count, start + height)
        var visible = Array(lines[start..<end])
        if start > 0 { visible[0] = self.fit("↑ more", width: width) }
        if end < lines.count { visible[visible.count - 1] = self.fit("↓ more", width: width) }
        return visible
    }

    private static func side(
        _ content: String,
        innerWidth: Int,
        borderCode: String,
        useColor: Bool,
        dim: Bool = false,
        metric: Double? = nil) -> String
    {
        let clipped = self.fit(content, width: innerWidth)
        let padding = String(repeating: " ", count: max(0, innerWidth - self.visibleLength(clipped)))
        let body: String = if let metric {
            self.paint(clipped, code: self.metricCode(metric), enabled: useColor)
        } else if dim {
            self.paint(clipped, code: "2", enabled: useColor)
        } else {
            clipped
        }
        let border = self.paint("│", code: borderCode, enabled: useColor)
        return "\(border) \(body)\(padding) \(border)"
    }

    private static func paired(_ left: String, _ right: String, width: Int) -> String {
        guard !right.isEmpty else { return self.fit(left, width: width) }
        let gap = max(1, width - self.visibleLength(left) - self.visibleLength(right))
        return self.fit(left + String(repeating: " ", count: gap) + right, width: width)
    }

    private static func centered(_ value: String, width: Int) -> String {
        let fitted = self.fit(value, width: width)
        return String(repeating: " ", count: max(0, (width - self.visibleLength(fitted)) / 2)) + fitted
    }

    private static func alignedInfo(_ value: String, width: Int) -> String {
        let plain = TextParsing.stripANSICodes(value)
        let parts = plain.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return self.fit(plain, width: width) }
        return self.paired(
            parts[0].trimmingCharacters(in: .whitespaces) + ":",
            parts[1].trimmingCharacters(in: .whitespaces),
            width: width)
    }

    private static func bar(remaining: Double, width: Int) -> String {
        let filled = Int((max(0, min(100, remaining)) / 100 * Double(width)).rounded())
        return "[" + String(repeating: "━", count: filled) + String(repeating: "─", count: max(0, width - filled)) + "]"
    }

    private static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))% left"
    }

    private static func resetLabel(_ text: String) -> String {
        text
            .replacingOccurrences(of: "⏳ ", with: "")
            .replacingOccurrences(of: "Reset in ", with: "")
            .replacingOccurrences(of: "Resets in ", with: "")
            .replacingOccurrences(of: "Reset ", with: "")
            .replacingOccurrences(of: "Resets ", with: "")
    }

    private static func freshness(_ date: Date?) -> String {
        guard let date else { return "updated unknown" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        return switch seconds {
        case 0..<10: "updated now"
        case 10..<60: "updated \(seconds)s"
        case 60..<3600: "updated \(seconds / 60)m"
        default: "updated \(seconds / 3600)h"
        }
    }

    private static func wrapped(_ value: String, width: Int) -> [String] {
        guard value.count > width else { return [value] }
        var lines: [String] = []
        var current = ""
        for word in value.split(separator: " ").map(String.init) {
            let proposed = current.isEmpty ? word : current + " " + word
            if proposed.count > width, !current.isEmpty {
                lines.append(current)
                current = word
            } else {
                current = proposed
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private static func pad(_ value: String, width: Int) -> String {
        value + String(repeating: " ", count: max(0, width - self.visibleLength(value)))
    }

    private static func fit(_ value: String, width: Int) -> String {
        let plain = self.safe(TextParsing.stripANSICodes(value))
        guard plain.count > width else { return plain }
        guard width > 1 else { return String(plain.prefix(max(0, width))) }
        return String(plain.prefix(width - 1)) + "…"
    }

    private static func visibleLength(_ value: String) -> Int {
        TextParsing.stripANSICodes(value).count
    }

    private static func safe(_ value: String) -> String {
        String(value.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar)
        })
    }

    private static func paint(_ value: String, code: String, enabled: Bool) -> String {
        guard enabled else { return value }
        return "\u{001B}[\(code)m\(value)\u{001B}[0m"
    }

    private static func metricCode(_ remaining: Double) -> String {
        switch remaining {
        case ..<20: "31"
        case ..<50: "33"
        default: "32"
        }
    }

    private static let controls = "arrows: grid • j/k: next/previous • Enter: detail • f: focus • r: refresh • ?: help • q: quit"
    private static let detailControls = "Esc: grid • j/k: previous/next provider • ↑/↓: scroll • r: refresh • q: quit"
    private static let helpText = [
        "Keyboard shortcuts",
        "",
        "  arrows    Move across the provider grid; in detail, scroll long provider data",
        "  j / k     Select next / previous provider account",
        "  Enter     Open provider detail",
        "  Esc       Return from detail or help; exits from the overview",
        "  f         Show only the selected provider's accounts; press again for all providers",
        "  r         Re-fetch using the existing configured provider sources",
        "  ?         Toggle this help",
        "  q         Quit",
        "",
        "The grid renders every provider-authentic quota window returned by the existing registry.",
        "Failures remain visible and stale values are marked rather than presented as fresh.",
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
        let useColor = Self.shouldUseColor(noColor: values.flags.contains("noColor"), format: .text)

        while true {
            guard let activeTerminal = terminal else { break }
            let terminalWidth = CLICardsRenderer.terminalColumnCount()
            let terminalHeight = CLICardsRenderer.terminalRowCount()
            activeTerminal.render(CLITUIRenderer.render(
                state: state,
                terminalWidth: terminalWidth,
                terminalHeight: terminalHeight,
                showsHelp: showsHelp,
                isRefreshing: isRefreshing,
                useColor: useColor))

            let action = activeTerminal.readAction()
            if action == .refresh {
                isRefreshing = true
                activeTerminal.render(CLITUIRenderer.render(
                    state: state,
                    terminalWidth: terminalWidth,
                    terminalHeight: terminalHeight,
                    showsHelp: showsHelp,
                    isRefreshing: isRefreshing,
                    useColor: useColor))
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
            if showsHelp, action == .back {
                showsHelp = false
                continue
            }
            if state.apply(action, columns: CLITUIRenderer.columnCount(terminalWidth: terminalWidth)) {
                activeTerminal.restore()
                Self.exit(
                    code: state.exitCode,
                    output: output,
                    kind: state.exitCode == ExitCode.success ? .runtime : .provider)
            }
        }
    }
}
