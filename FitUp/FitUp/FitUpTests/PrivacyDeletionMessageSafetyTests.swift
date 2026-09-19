import Foundation
import Testing
@testable import FitUp

struct PrivacyDeletionMessageSafetyTests {
    @Test func moderationReasonsRemainFixedAndComplete() {
        #expect(Set(ModerationReason.allCases.map(\.rawValue)) == Set([
            "harassment_bullying", "hate_offensive", "sexual_inappropriate",
            "spam", "threat_safety", "other",
        ]))
    }

    @Test func deletionFailureAlwaysIncludesOperationIdentifier() {
        let operationId = UUID()
        let failure = AccountDeletionFailure(operationId: operationId, code: "cleanup_failed")
        #expect(failure.errorDescription?.contains(operationId.uuidString) == true)
        #expect(failure.errorDescription?.contains("cleanup_failed") == false)
    }

    @Test func deletedPlayerIdentifierIsStable() {
        #expect(DeletedPlayer.id.uuidString.lowercased() == "00000000-0000-0000-0000-00000000dead")
        #expect(DeletedPlayer.matches(DeletedPlayer.id))
    }
}

