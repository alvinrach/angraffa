import Foundation
import Combine

@MainActor
public class ChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var inputText: String = ""
    @Published public var isProcessing: Bool = false

    public init() {
        messages.append(
            ChatMessage(
                sender: .agent,
                text: "👋 Hi! Paste any SmartRecruiters or job posting link here, and I'll auto-fill and prepare the application for you."
            )
        )
    }

    public func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let detectedURL = extractURL(from: trimmed)

        let userMessage = ChatMessage(
            sender: .user,
            text: trimmed,
            jobURL: detectedURL
        )
        messages.append(userMessage)
        inputText = ""

        if let url = detectedURL {
            processJobLink(url: url)
        } else {
            messages.append(
                ChatMessage(
                    sender: .agent,
                    text: "I received your message. Send me a job URL to start auto-filling!"
                )
            )
        }
    }

    private func processJobLink(url: URL) {
        isProcessing = true

        let processingMsgId = UUID()
        let initialAgentMsg = ChatMessage(
            id: processingMsgId,
            sender: .agent,
            text: "🚀 Detected job link: \(url.host ?? url.absoluteString)\nConnecting to backend automation engine...",
            jobURL: url,
            status: .fetching,
            liveLogs: ["Connecting to automation backend..."]
        )
        messages.append(initialAgentMsg)

        Task {
            let currentUser = await SupabaseService.shared.getCurrentUser()
            let userIdString = currentUser?.id.uuidString

            do {
                try await BackendAPIService.shared.streamJobApplication(
                    jobURL: url,
                    userId: userIdString
                ) { [weak self] sse in
                    guard let self = self else { return }
                    guard let idx = self.messages.firstIndex(where: { $0.id == processingMsgId }) else { return }

                    switch sse.event {
                    case "log":
                        if let logMsg = sse.data["message"] as? String {
                            self.messages[idx].liveLogs.append(logMsg)
                        }

                    case "step":
                        let stepName = sse.data["name"] as? String ?? ""
                        let stepStatus = sse.data["status"] as? String ?? ""
                        if stepStatus == "running" {
                            self.messages[idx].status = .filling
                        } else if stepStatus == "completed" && stepName == "screening_questions" {
                            self.messages[idx].status = .reviewReady
                        }

                    case "screenshot":
                        if let urlStr = sse.data["screenshot_url"] as? String, let screenURL = URL(string: urlStr) {
                            self.messages[idx].screenshotURL = screenURL
                        }

                    case "completed":
                        self.messages[idx].status = .completed
                        self.messages[idx].text = "🎉 Application successfully auto-filled and prepared for:\n\(url.absoluteString)"
                        if let urlStr = sse.data["screenshot_url"] as? String, let screenURL = URL(string: urlStr) {
                            self.messages[idx].screenshotURL = screenURL
                        }
                        self.isProcessing = false

                    case "error":
                        self.messages[idx].status = .failed
                        let errorMsg = sse.data["message"] as? String ?? "An error occurred during automation."
                        self.messages[idx].text = "❌ Application failed: \(errorMsg)"
                        self.isProcessing = false

                    default:
                        break
                    }
                }
            } catch {
                if let idx = self.messages.firstIndex(where: { $0.id == processingMsgId }) {
                    self.messages[idx].status = .failed
                    self.messages[idx].text = "❌ Connection failed: \(error.localizedDescription)\nEnsure backend server is running."
                }
                self.isProcessing = false
            }
        }
    }

    private func extractURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.first?.url
    }
}
