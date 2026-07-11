#if os(Linux)
import Testing
@testable import CodexBarCLI
@testable import CodexBarCore

struct ClaudeOAuthLinuxTests {
    @Test
    func `Claude environment OAuth token selects OAuth in automatic mode`() throws {
        let context = try TokenAccountCLIContext(
            selection: .init(label: nil, index: nil, allAccounts: false),
            config: .makeDefault(),
            verbose: false,
            baseEnvironment: [ClaudeOAuthCredentialsStore.environmentTokenKey: "sk-ant-oat-test"])

        #expect(context.effectiveSourceMode(base: .auto, provider: .claude, account: nil) == .oauth)
    }
}
#endif
