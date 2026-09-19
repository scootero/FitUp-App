import Foundation

enum DeletedPlayer {
    static let id = UUID(uuidString: "00000000-0000-0000-0000-00000000DEAD")!
    static func matches(_ profileId: UUID) -> Bool { profileId == id }
}

