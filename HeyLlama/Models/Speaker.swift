import Foundation

struct Speaker: Sendable, Equatable {
    let id: UUID
    let name: String
    let embeddings: [[Float]]

    init(id: UUID = UUID(), name: String, embeddings: [[Float]] = []) {
        self.id = id
        self.name = name
        self.embeddings = embeddings
    }
}
