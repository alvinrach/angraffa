import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Header Icon & Title
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    Text("Welcome to Job Agent")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Sign in with your email to access your personal profile, CV, and applications.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Error / Status Messages
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                } else if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal)
                }

                // Input Card
                VStack(spacing: 16) {
                    if !viewModel.isCodeSent {
                        // Email Step
                        TextField("Enter your email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .focused($isEmailFocused)

                        Button(action: {
                            hideKeyboard()
                            Task {
                                await viewModel.sendOTP()
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                            } else {
                                Text("Send Login Code")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                        .disabled(viewModel.isLoading || viewModel.email.isEmpty)
                    } else {
                        // OTP Code Step
                        VStack(spacing: 14) {
                            Text("Code sent to: **\(viewModel.email)**")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                TextField("Enter 8-digit code", text: $viewModel.otpCode)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .multilineTextAlignment(.center)
                                    .font(.title3)
                                    .padding(14)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .focused($isCodeFocused)

                                Button(action: {
                                    if let clipboard = UIPasteboard.general.string {
                                        let digitsOnly = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                                        viewModel.otpCode = digitsOnly
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.clipboard")
                                        Text("Paste")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                                }
                            }

                            Button(action: {
                                hideKeyboard()
                                Task {
                                    await viewModel.verifyOTP()
                                }
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(14)
                                } else {
                                    Text("Verify & Sign In")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(14)
                                        .foregroundColor(.white)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            }
                            .disabled(viewModel.isLoading || viewModel.otpCode.isEmpty)

                            Button("Use different email") {
                                viewModel.isCodeSent = false
                                viewModel.otpCode = ""
                                viewModel.errorMessage = nil
                                viewModel.statusMessage = nil
                            }
                            .font(.caption)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .onTapGesture {
                hideKeyboard()
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
