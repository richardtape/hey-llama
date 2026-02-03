import Foundation

struct SkillSummary: Equatable, Sendable {
    enum Status: String, Equatable, Sendable {
        case success
        case failed
    }

    let skillId: String
    let status: Status
    let summary: String
    let details: [String: AnyCodable]

    nonisolated init(
        skillId: String,
        status: Status,
        summary: String,
        details: [String: Any] = [:]
    ) {
        self.skillId = skillId
        self.status = status
        self.summary = summary
        self.details = details.mapValues { AnyCodable($0) }
    }

    func toJSONData() throws -> Data {
        let dict: [String: Any] = [
            "skillId": skillId,
            "status": status.rawValue,
            "summary": summary,
            "details": details.mapValues { $0.value }
        ]
        return try JSONSerialization.data(withJSONObject: dict)
    }
}

struct AnyCodable: Equatable, Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
