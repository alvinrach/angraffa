import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isDocumentPickerPresented = false
    @State private var newQuestionKey = ""
    @State private var newQuestionValue = ""

    var body: some View {
        NavigationStack {
            Form {
                // Status / Banner
                if let status = viewModel.statusMessage {
                    Section {
                        HStack {
                            Image(systemName: viewModel.isErrorMessage ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(viewModel.isErrorMessage ? .red : .green)
                            Text(status)
                                .font(.subheadline)
                        }
                    }
                }

                // Resume Upload Section
                Section(header: Text("Resume / CV (PDF)")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.resumeFileName.isEmpty ? "No resume uploaded" : viewModel.resumeFileName)
                                .font(.body)
                                .foregroundColor(viewModel.resumeFileName.isEmpty ? .secondary : .primary)
                            if !viewModel.resumeFileName.isEmpty {
                                Text("Uploaded to Supabase Storage")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        Spacer()
                        Button(action: {
                            isDocumentPickerPresented = true
                        }) {
                            if viewModel.isUploadingResume {
                                ProgressView()
                            } else {
                                Label("Upload PDF", systemImage: "arrow.up.doc")
                            }
                        }
                        .disabled(viewModel.isUploadingResume)
                    }
                }

                // Contact & Basic Info
                Section(header: Text("Contact Information")) {
                    TextField("Full Name", text: $viewModel.fullName)
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $viewModel.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                // Online Profiles
                Section(header: Text("Links")) {
                    TextField("LinkedIn URL", text: $viewModel.linkedinURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    TextField("GitHub URL", text: $viewModel.githubURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                // Custom Q&A for ATS Forms
                Section(
                    header: Text("Custom Q&A Memory"),
                    footer: Text("Common questions asked by job boards (e.g., Work Authorization, Salary Expectations, Notice Period).")
                ) {
                    ForEach(viewModel.customAnswers.keys.sorted(), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.customAnswers[key] ?? "")
                                .font(.body)
                        }
                    }
                    .onDelete { indexSet in
                        let keys = viewModel.customAnswers.keys.sorted()
                        for index in indexSet {
                            viewModel.customAnswers.removeValue(forKey: keys[index])
                        }
                    }

                    // Add new Q&A
                    VStack(spacing: 8) {
                        TextField("Question / Topic (e.g. Visa Status)", text: $newQuestionKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("Your Answer (e.g. Authorized to work)", text: $newQuestionValue)
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            guard !newQuestionKey.isEmpty && !newQuestionValue.isEmpty else { return }
                            viewModel.customAnswers[newQuestionKey] = newQuestionValue
                            newQuestionKey = ""
                            newQuestionValue = ""
                        }) {
                            Label("Add Answer", systemImage: "plus.circle")
                        }
                        .disabled(newQuestionKey.isEmpty || newQuestionValue.isEmpty)
                    }
                    .padding(.vertical, 4)
                }

                // Save Action
                Section {
                    Button(action: {
                        hideKeyboard()
                        Task {
                            await viewModel.saveProfile()
                        }
                    }) {
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Save Profile")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                hideKeyboard()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .navigationTitle("Profile & CV")
            .fileImporter(
                isPresented: $isDocumentPickerPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await viewModel.handleResumeFilePicked(url: url)
                        }
                    }
                case .failure(let error):
                    viewModel.statusMessage = "Picker error: \(error.localizedDescription)"
                    viewModel.isErrorMessage = true
                }
            }
        }
    }
}

// Helper extension to dismiss keyboard globally
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    ProfileView()
}

