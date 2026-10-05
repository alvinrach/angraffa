import Foundation

public struct SSEEvent {
    public let event: String
    public let data: [String: Any]
}

public class BackendAPIService: ObservableObject {
    public static let shared = BackendAPIService()

    private let baseURLKey = "jobagent_backend_base_url"

    // Default backend URL: 172.18.11.32 for LAN physical device, 127.0.0.1 for simulator
    public var baseURL: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: baseURLKey), !saved.isEmpty {
                return saved
            }
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:8000"
            #else
            return "http://172.18.11.32:8000"
            #endif
        }
        set {
            UserDefaults.standard.set(newValue, forKey: baseURLKey)
        }
    }

    private init() {}

    public func streamJobApplication(
        jobURL: URL,
        userId: String?,
        autoSubmit: Bool = false,
        onEvent: @escaping @MainActor (SSEEvent) -> Void
    ) async throws {
        let cleanBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let endpoint = URL(string: "\(cleanBase)/api/apply") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 180

        var payload: [String: Any] = [
            "job_url": jobURL.absoluteString,
            "auto_submit": autoSubmit
        ]
        if let uid = userId {
            payload["user_id"] = uid
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "BackendAPI", code: status, userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP status \(status)"])
        }

        var currentEvent = "message"

        for try await line in asyncBytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                currentEvent = "message"
                continue
            }

            if trimmed.hasPrefix("event:") {
                currentEvent = trimmed.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("data:") {
                let dataString = trimmed.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                if let data = dataString.data(using: .utf8),
                   let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    let event = SSEEvent(event: currentEvent, data: json)
                    await onEvent(event)
                }
            }
        }
    }

    public func convertCVToMarkdown(userId: String?) async throws -> [String: Any] {
        let cleanBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let endpoint = URL(string: "\(cleanBase)/api/cv/convert-md") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let uid = userId {
            payload["user_id"] = uid
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "BackendAPI", code: status, userInfo: [NSLocalizedDescriptionKey: "Conversion failed with status \(status)"])
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return json
    }
}

