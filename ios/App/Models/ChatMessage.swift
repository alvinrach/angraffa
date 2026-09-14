import Foundation

public enum MessageSender: String, Codable {
    case user
    case agent
}

public enum ApplicationStatus: String, Codable {
    case pending
    case fetching
    case filling
    case reviewReady = "review_ready"
    case completed
    case failed
}

public struct ChatMessage: Identifiable, Codable {
    public let id: UUID
    public let sender: MessageSender
    public var text: String
    public let timestamp: Date
    public var jobURL: URL?
    public var status: ApplicationStatus?
    public var screenshotURL: URL?
    public var liveLogs: [String]
    public var applicationId: String?

    public init(
        id: UUID = UUID(),
        sender: MessageSender,
        text: String,
        timestamp: Date = Date(),
        jobURL: URL? = nil,
        status: ApplicationStatus? = nil,
        screenshotURL: URL? = nil,
        liveLogs: [String] = [],
        applicationId: String? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.jobURL = jobURL
        self.status = status
        self.screenshotURL = screenshotURL
        self.liveLogs = liveLogs
        self.applicationId = applicationId
    }
}
