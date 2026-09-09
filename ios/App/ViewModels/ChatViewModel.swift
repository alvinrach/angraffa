import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isProcessing: Bool = false

    init() {
        // Welcome message
        messages.append(
            ChatMessage(
                sender: .agent,
                text: "👋 Hi! Paste any job posting link here, and I'll extract the details and auto-fill the application for you."
            )
        )
    }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Detect if the message contains a URL
        let detectedURL = extractURL(from: trimmed)

        // Add user message
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
            // General query response placeholder
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
        messages.append(
            ChatMessage(
                id: processingMsgId,
                sender: .agent,
                text: "🔍 Detected job link: \(url.host ?? url.absoluteString)\nFetching job application form...",
                jobURL: url,
                status: .fetching
            )
        )

        // Simulate fetching & form filling (To be replaced with backend/agent API)
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            if let idx = messages.firstIndex(where: { $0.id == processingMsgId }) {
                messages[idx] = ChatMessage(
                    id: processingMsgId,
                    sender: .agent,
                    text: "📝 Form fetched! Filling fields (Name, Resume, Experience, Cover Letter)...",
                    jobURL: url,
                    status: .filling
                )
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            if let idx = messages.firstIndex(where: { $0.id == processingMsgId }) {
                messages[idx] = ChatMessage(
                    id: processingMsgId,
                    sender: .agent,
                    text: "✅ Application successfully prepared and submitted for:\n\(url.absoluteString)",
                    jobURL: url,
                    status: .completed
                )
            }

            isProcessing = false
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
