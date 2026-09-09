import Foundation

enum MessageSender: String, Codable {
    case user
    case agent
}

enum ApplicationStatus: String, Codable {
    case pending
    case fetching
    case filling
    case completed
    case failed
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let sender: MessageSender
    let text: String
    let timestamp: Date
    var jobURL: URL?
    var status: ApplicationStatus?

    init(
        id: UUID = UUID(),
        sender: MessageSender,
        text: String,
        timestamp: Date = Date(),
        jobURL: URL? = nil,
        status: ApplicationStatus? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.jobURL = jobURL
        self.status = status
    }
}
