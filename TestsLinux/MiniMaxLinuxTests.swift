#if os(Linux)
import Testing
@testable import CodexBarCLI
@testable import CodexBarCore

struct MiniMaxLinuxTests {
    @Test
    func `MiniMax API token lets automatic source run on Linux`() {
        #expect(!CodexBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .minimax,
            environment: [MiniMaxAPISettingsReader.apiTokenKey: "test-token"]))
    }
}
#endif
