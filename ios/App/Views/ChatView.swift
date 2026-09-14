import SwiftUI

public struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var previewScreenshotURL: URL? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message) { screenURL in
                                    previewScreenshotURL = screenURL
                                }
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        isInputFocused = false
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input Bar
                HStack(spacing: 10) {
                    TextField("Paste job link or type message...", text: $viewModel.inputText, axis: .vertical)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...4)
                        .focused($isInputFocused)

                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Job Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            .sheet(item: Binding<URLIdentifiable?>(
                get: { previewScreenshotURL.map { URLIdentifiable(url: $0) } },
                set: { previewScreenshotURL = $0?.url }
            )) { identifiable in
                NavigationStack {
                    ScrollView([.horizontal, .vertical]) {
                        AsyncImage(url: identifiable.url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                Text("Failed to load verification screenshot.")
                                    .foregroundColor(.red)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .navigationTitle("Verification Receipt")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                previewScreenshotURL = nil
                            }
                        }
                    }
                }
            }
        }
    }
}

public struct URLIdentifiable: Identifiable {
    public var id: String { url.absoluteString }
    public let url: URL
}

public struct MessageBubble: View {
    public let message: ChatMessage
    public var onScreenshotTap: ((URL) -> Void)? = nil
    @State private var isLogsExpanded: Bool = false

    public var isUser: Bool {
        message.sender == .user
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 70) }

            if !isUser {
                Image(systemName: "sparkles.2")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.green)
                    .clipShape(Circle())
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(isUser ? .white : .primary)

                if let status = message.status {
                    statusBadge(status: status)
                }

                // Live Terminal Logs Section
                if !message.liveLogs.isEmpty {
                    DisclosureGroup(
                        isExpanded: $isLogsExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(message.liveLogs.enumerated()), id: \.offset) { _, log in
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(Color(.systemGray))
                                }
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        },
                        label: {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal")
                                Text("Live Execution Logs (\(message.liveLogs.count))")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                        }
                    )
                    .padding(.top, 4)
                }

                // Screenshot Preview Card
                if let screenshotURL = message.screenshotURL {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📸 Application Verification Receipt")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Button(action: {
                            onScreenshotTap?(screenshotURL)
                        }) {
                            AsyncImage(url: screenshotURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 180)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                case .failure:
                                    HStack {
                                        Image(systemName: "photo")
                                        Text("Tap to view screenshot")
                                    }
                                    .font(.caption)
                                    .padding(8)
                                case .empty:
                                    ProgressView()
                                        .frame(height: 100)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isUser ? Color.blue : Color(.systemGray5))
            .cornerRadius(18)

            if !isUser { Spacer(minLength: 30) }
        }
    }

    @ViewBuilder
    private func statusBadge(status: ApplicationStatus) -> some View {
        HStack(spacing: 4) {
            switch status {
            case .fetching:
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Connecting...")
            case .filling:
                Image(systemName: "pencil.and.outline")
                Text("Auto-filling Form...")
            case .reviewReady:
                Image(systemName: "doc.viewfinder.fill")
                    .foregroundColor(.blue)
                Text("Ready for Review")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Completed")
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Failed")
            case .pending:
                Image(systemName: "clock")
                Text("Queued")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.top, 2)
    }
}

#Preview {
    ChatView()
}
