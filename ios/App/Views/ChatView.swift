import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
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
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool {
        message.sender == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 90) }

            if !isUser {
                Image(systemName: "sparkles.2")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.green)
                    .clipShape(Ellipse())
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(isUser ? .white : .primary)

                if let status = message.status {
                    statusBadge(status: status)
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
                Text("Fetching Form...")
            case .filling:
                Image(systemName: "pencil.and.outline")
                Text("Auto-filling Details...")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Submitted")
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
