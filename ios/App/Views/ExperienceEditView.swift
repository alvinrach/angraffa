import SwiftUI

public struct ExperienceEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var company: String
    @State private var location: String
    @State private var startDate: String
    @State private var endDate: String
    @State private var isCurrent: Bool
    @State private var descriptionText: String
    
    private var experienceId: UUID
    private var onSave: (Experience) -> Void

    public init(
        experience: Experience? = nil,
        onSave: @escaping (Experience) -> Void
    ) {
        self.experienceId = experience?.id ?? UUID()
        _title = State(initialValue: experience?.title ?? "")
        _company = State(initialValue: experience?.company ?? "")
        _location = State(initialValue: experience?.location ?? "")
        _startDate = State(initialValue: experience?.startDate ?? "")
        _endDate = State(initialValue: experience?.endDate ?? "")
        _isCurrent = State(initialValue: experience?.isCurrent ?? false)
        _descriptionText = State(initialValue: experience?.description ?? "")
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Role Details")) {
                    TextField("Job Title (e.g. Senior Data Scientist)*", text: $title)
                    TextField("Company Name (e.g. Talabat)*", text: $company)
                    TextField("Location (e.g. Dubai, UAE)", text: $location)
                }

                Section(header: Text("Timeline")) {
                    TextField("Start Date (e.g. 2023-01)*", text: $startDate)
                    
                    Toggle("I currently work in this role", isOn: $isCurrent)
                        .onChange(of: isCurrent) { _, newValue in
                            if newValue {
                                endDate = "Present"
                            } else if endDate == "Present" {
                                endDate = ""
                            }
                        }

                    if !isCurrent {
                        TextField("End Date (e.g. 2024-05)", text: $endDate)
                    }
                }

                Section(header: Text("Role Highlights / Summary")) {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(title.isEmpty ? "Add Experience" : "Edit Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exp = Experience(
                            id: experienceId,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            company: company.trimmingCharacters(in: .whitespacesAndNewlines),
                            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
                            startDate: startDate.trimmingCharacters(in: .whitespacesAndNewlines),
                            endDate: isCurrent ? "Present" : (endDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : endDate.trimmingCharacters(in: .whitespacesAndNewlines)),
                            isCurrent: isCurrent,
                            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onSave(exp)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
