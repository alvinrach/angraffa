import Foundation

public struct Profile: Identifiable, Codable {
    public var id: UUID
    public var email: String
    public var firstName: String?
    public var lastName: String?
    public var fullName: String?
    public var phoneCountryCode: String?
    public var phoneNumber: String?
    public var city: String?
    public var country: String?
    public var location: String?
    public var linkedinURL: String?
    public var githubURL: String?
    public var portfolioURL: String?
    public var resumePath: String?
    public var resumeFilename: String?
    public var experiences: [Experience]?
    public var answersJSON: [String: String]?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case phoneCountryCode = "phone_country_code"
        case phoneNumber = "phone_number"
        case city
        case country
        case location
        case linkedinURL = "linkedin_url"
        case githubURL = "github_url"
        case portfolioURL = "portfolio_url"
        case resumePath = "resume_path"
        case resumeFilename = "resume_filename"
        case experiences
        case answersJSON = "answers_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: UUID = UUID(),
        email: String = "",
        firstName: String? = nil,
        lastName: String? = nil,
        fullName: String? = nil,
        phoneCountryCode: String? = "+62",
        phoneNumber: String? = nil,
        city: String? = nil,
        country: String? = nil,
        location: String? = nil,
        linkedinURL: String? = nil,
        githubURL: String? = nil,
        portfolioURL: String? = nil,
        resumePath: String? = nil,
        resumeFilename: String? = nil,
        experiences: [Experience]? = nil,
        answersJSON: [String: String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.phoneCountryCode = phoneCountryCode
        self.phoneNumber = phoneNumber
        self.city = city
        self.country = country
        self.location = location
        self.linkedinURL = linkedinURL
        self.githubURL = githubURL
        self.portfolioURL = portfolioURL
        self.resumePath = resumePath
        self.resumeFilename = resumeFilename
        self.experiences = experiences
        self.answersJSON = answersJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
