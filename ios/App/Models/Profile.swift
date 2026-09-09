import Foundation

struct Profile: Identifiable, Codable {
    var id: UUID
    var fullName: String?
    var email: String?
    var phone: String?
    var linkedinURL: String?
    var githubURL: String?
    var resumePath: String?
    var answersJSON: [String: String]?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phone
        case linkedinURL = "linkedin_url"
        case githubURL = "github_url"
        case resumePath = "resume_path"
        case answersJSON = "answers_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        fullName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        linkedinURL: String? = nil,
        githubURL: String? = nil,
        resumePath: String? = nil,
        answersJSON: [String: String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.linkedinURL = linkedinURL
        self.githubURL = githubURL
        self.resumePath = resumePath
        self.answersJSON = answersJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
