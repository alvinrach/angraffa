import SwiftUI
import UniformTypeIdentifiers

public struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isDocumentPickerPresented = false
    @State private var isExperienceSheetPresented = false
    @State private var selectedExperience: Experience? = nil
    
    @State private var newQuestionKey = ""
    @State private var newQuestionValue = ""
    @AppStorage("jobagent_backend_base_url") private var backendBaseURL: String = "http://172.18.11.32:8000"
    @AppStorage("jobagent_auto_submit") private var autoSubmit: Bool = false
    public var onSignOut: (() -> Void)? = nil

    public init(onSignOut: (() -> Void)? = nil) {
        self.onSignOut = onSignOut
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Account Info Section
                Section(header: Text("Account")) {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.blue)
                        Text(viewModel.email.isEmpty ? "Loading..." : viewModel.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

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
                                Text("Stored securely in your Supabase account")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        Spacer()
                        Button(action: {
                            hideKeyboard()
                            isDocumentPickerPresented = true
                        }) {
                            if viewModel.isUploadingResume {
                                ProgressView()
                            } else {
                                Label("Upload PDF", systemImage: "arrow.up.doc")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isUploadingResume)
                    }
                }

                // Name Details (Split for ATS systems)
                Section(header: Text("Name Details")) {
                    TextField("First Name (e.g. Alvin)", text: $viewModel.firstName)
                    TextField("Last Name (e.g. Rachmat)", text: $viewModel.lastName)
                }

                // Contact & Location
                Section(header: Text("Location & Phone")) {
                    TextField("City (e.g. Abu Dhabi / Jakarta)", text: $viewModel.city)
                    TextField("Country (e.g. UAE / Indonesia)", text: $viewModel.country)

                    HStack(spacing: 8) {
                        TextField("+971", text: $viewModel.phoneCountryCode)
                            .frame(width: 65)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)

                        TextField("Phone Number (e.g. 502140290)", text: $viewModel.phoneNumber)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                }

                // Online Profiles
                Section(header: Text("Links")) {
                    TextField("LinkedIn URL", text: $viewModel.linkedinURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    TextField("GitHub URL", text: $viewModel.githubURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    TextField("Portfolio / Website URL", text: $viewModel.portfolioURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                // Work Experiences Section
                Section(
                    header: HStack {
                        Text("Work Experiences")
                        Spacer()
                        Button(action: {
                            hideKeyboard()
                            selectedExperience = nil
                            isExperienceSheetPresented = true
                        }) {
                            Label("Add", systemImage: "plus")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    },
                    footer: Text("Curate once in your phone; reused automatically for applications requiring explicit work history.")
                ) {
                    if viewModel.experiences.isEmpty {
                        Text("No work experiences added yet.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(viewModel.experiences) { exp in
                            Button(action: {
                                hideKeyboard()
                                selectedExperience = exp
                                isExperienceSheetPresented = true
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(exp.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(exp.isCurrent ? "\(exp.startDate) – Present" : "\(exp.startDate) – \(exp.endDate ?? "")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text(exp.company)
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        if let loc = exp.location, !loc.isEmpty {
                                            Text("• \(loc)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    if let desc = exp.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.deleteExperience(at: indexSet)
                        }
                    }
                }

                // Default Screening Answers
                Section(
                    header: Text("Default Screening Q&A"),
                    footer: Text("Auto-populates preliminary screening questions on portals like SmartRecruiters, Greenhouse, and Workday.")
                ) {
                    HStack {
                        Text("Nationality")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. Indonesian", text: $viewModel.nationality)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Visa Status")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. Resident Visa", text: $viewModel.visaStatus)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Notice Period")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. 1 month", text: $viewModel.noticePeriod)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Earliest Start")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. Immediately", text: $viewModel.earliestStartDate)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Current Salary")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. AED 25,000", text: $viewModel.currentSalary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Expected Salary")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. AED 30,000", text: $viewModel.expectedSalary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Marital Status")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. Single / Married", text: $viewModel.maritalStatus)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Gender")
                            .font(.subheadline)
                        Spacer()
                        TextField("e.g. Male / Female", text: $viewModel.gender)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default Skillset Pitch / Summary")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.skillsetPitch)
                            .frame(minHeight: 80)
                    }
                }

                // Custom Extra Q&A Builder
                Section(header: Text("Custom Q&A Memory")) {
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
                        TextField("Question / Topic (e.g. Relatives in Company)", text: $newQuestionKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("Your Answer (e.g. No)", text: $newQuestionValue)
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            guard !newQuestionKey.isEmpty && !newQuestionValue.isEmpty else { return }
                            viewModel.customAnswers[newQuestionKey] = newQuestionValue
                            newQuestionKey = ""
                            newQuestionValue = ""
                        }) {
                            Label("Add Custom Answer", systemImage: "plus.circle")
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

                // Automation Settings
                Section(header: Text("Automation Settings"), footer: Text(autoSubmit ? "⚠️ Live Mode: The agent will fill all details and click Submit automatically." : "🛡️ Dry-Run Mode: The agent will fill all details and capture a full verification screenshot for your review without submitting.")) {
                    Toggle(isOn: $autoSubmit) {
                        HStack {
                            Image(systemName: autoSubmit ? "paperplane.fill" : "eye.fill")
                                .foregroundColor(autoSubmit ? .green : .blue)
                            Text("Auto-Submit Applications")
                        }
                    }
                }

                // Backend Server Connection
                Section(header: Text("Backend Server Connection"), footer: Text("Set the IP/URL of your Mac running the FastAPI backend server (port 8000).")) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.orange)
                        TextField("http://172.18.11.32:8000", text: $backendBaseURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                }

                // Sign Out
                Section {
                    Button(role: .destructive, action: {
                        if let onSignOut = onSignOut {
                            onSignOut()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
                    let nsError = error as NSError
                    if nsError.domain != NSCocoaErrorDomain || nsError.code != 3072 {
                        viewModel.statusMessage = "Picker error: \(error.localizedDescription)"
                        viewModel.isErrorMessage = true
                    }
                }
            }
            .sheet(isPresented: $isExperienceSheetPresented) {
                ExperienceEditView(experience: selectedExperience) { exp in
                    if selectedExperience != nil {
                        viewModel.updateExperience(exp)
                    } else {
                        viewModel.addExperience(exp)
                    }
                    Task {
                        await viewModel.saveProfile()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
