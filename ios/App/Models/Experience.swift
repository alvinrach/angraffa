import Foundation

public struct Experience: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var company: String
    public var location: String?
    public var startDate: String
    public var endDate: String?
    public var isCurrent: Bool
    public var description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case company
        case location
        case startDate = "start_date"
        case endDate = "end_date"
        case isCurrent = "is_current"
        case description
    }

    public init(
        id: UUID = UUID(),
        title: String = "",
        company: String = "",
        location: String? = nil,
        startDate: String = "",
        endDate: String? = nil,
        isCurrent: Bool = false,
        description: String? = nil
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
        self.description = description
    }
}
