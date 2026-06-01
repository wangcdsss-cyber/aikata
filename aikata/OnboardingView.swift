import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var showLegalDialog = false
    @State private var activeWebRoute: WebRoute? = nil

    private let termsURL = URL(string: "https://changeable-pegasus-9b4.notion.site/372404b9a4d58099ba66fffe4472eb96?source=copy_link")!
    private let privacyURL = URL(string: "https://changeable-pegasus-9b4.notion.site/372404b9a4d580a2ac45c4baa432a47b?source=copy_link")!

    private var backgroundColor: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text("Aikata")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 14)

                        Text("趣味友アプリ")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 12) {
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("初めて使う方")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)

                                Button(action: {
                                    showLegalDialog = true
                                }) {
                                    Text("利用契約とプライバシーポリシーを確認")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.blue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    showSignUp = true
                                }) {
                                    Text("同意して今すぐ始める")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color(red: 0.98, green: 0.38, blue: 0.43))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 14)
                                }
                                .buttonStyle(PressedScaleButtonStyle())
                            }
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("すでにアカウントをお持ちの方")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)

                                Button(action: {
                                    showSignIn = true
                                }) {
                                    Text("お持ちのアカウントでログイン")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 14)
                                }
                                .buttonStyle(PressedScaleButtonStyle())
                            }
                        }
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(
                    onOpenTerms: { activeWebRoute = WebRoute(url: termsURL, title: "利用契約") },
                    onOpenPrivacy: { activeWebRoute = WebRoute(url: privacyURL, title: "プライバシーポリシー") }
                )
            }
            .navigationDestination(isPresented: $showSignIn) {
                SignInView()
            }
            .sheet(item: $activeWebRoute) { route in
                WebSheet(url: route.url, title: route.title)
            }
            .confirmationDialog("確認", isPresented: $showLegalDialog, titleVisibility: .visible) {
                Button("利用契約") {
                    activeWebRoute = WebRoute(url: termsURL, title: "利用契約")
                }
                Button("プライバシーポリシー") {
                    activeWebRoute = WebRoute(url: privacyURL, title: "プライバシーポリシー")
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("開くページを選択してください。")
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthManager())
}

private struct SignUpView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let onOpenTerms: () -> Void
    let onOpenPrivacy: () -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var birthday = Date()
    @State private var gender: Gender = .male
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var showConfirmAlert = false
    @State private var showErrorAlert = false
    @State private var errorText = ""
    @State private var isSubmitting = false

    private var backgroundColor: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    private var canReview: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("新規会員登録")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)

                            Text("すべての項目を入力して、「内容を確認」ボタンをクリックしてください。")
                                .font(.system(size: 13))
                                .foregroundColor(Color.black.opacity(0.65))
                                .padding(.horizontal, 16)

                            HStack(spacing: 8) {
                                Button(action: onOpenTerms) {
                                    Text("利用契約")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                Button(action: onOpenPrivacy) {
                                    Text("プライバシーポリシー")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }

                    SettingsCard {
                        VStack(spacing: 0) {
                            LabeledField(title: "姓名", required: true) {
                                TextField("姓名", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                            }

                            SettingsDivider()

                            LabeledField(title: "メールアドレス", required: true) {
                                TextField("メールアドレス", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                            }

                            SettingsDivider()

                            LabeledField(title: "生年月日", required: true) {
#if canImport(UIKit)
                                DatePicker("", selection: $birthday, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
#else
                                DatePicker("", selection: $birthday, displayedComponents: .date)
                                    .labelsHidden()
#endif
                            }

                            SettingsDivider()

                            LabeledField(title: "性別", required: true) {
                                Picker("", selection: $gender) {
                                    Text("男性").tag(Gender.male)
                                    Text("女性").tag(Gender.female)
                                }
                                .pickerStyle(.segmented)
                            }

                            SettingsDivider()

                            LabeledField(title: "パスワード", required: true) {
                                SecureField("パスワード", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            SettingsDivider()

                            LabeledField(title: "パスワード（確認）", required: true) {
                                SecureField("パスワード（確認）", text: $confirmPassword)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                    }

                    if passwordMismatch {
                        Text("パスワードが一致しません。")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                    }

                    VStack(spacing: 10) {
                        Button(action: {
                            showConfirmAlert = true
                        }) {
                            Text("内容を確認")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canReview ? Color.orange : Color.gray.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(PressedScaleButtonStyle())
                        .disabled(!canReview || isSubmitting)

                        Button(action: {
                            dismiss()
                        }) {
                            Text("キャンセル")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.75))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PressedScaleButtonStyle())
                        .disabled(isSubmitting)
                    }
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("新規会員登録")
            .tint(Color.orange)
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("戻る")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.orange)
                    }
                }
            }
            .alert("登録内容の確認", isPresented: $showConfirmAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("送信") {
                    Task { await submit() }
                }
            } message: {
                Text(confirmMessage)
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }

            if isSubmitting || authManager.isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("送信中…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.7))
                }
                .padding(18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }

    private var confirmMessage: String {
        let dateText = DateFormatter.jpDate.string(from: birthday)
        let masked = String(repeating: "•", count: max(8, min(password.count, 16)))
        return """
姓名: \(name)
メール: \(email)
生年月日: \(dateText)
性別: \(gender.rawValue)
パスワード: \(masked)
"""
    }

    private func submit() async {
        if password != confirmPassword {
            await MainActor.run {
                errorText = "パスワードが一致しません。"
                showErrorAlert = true
            }
            return
        }

        await MainActor.run { isSubmitting = true }
        do {
            try await authManager.signUp(
                name: name,
                email: email,
                birthday: birthday,
                gender: gender,
                password: password
            )
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                showErrorAlert = true
                isSubmitting = false
            }
            return
        }
        await MainActor.run {
            isSubmitting = false
        }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var showErrorAlert = false
    @State private var errorText = ""

    private var backgroundColor: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("メールアドレス")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            TextField("メールアドレス", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )

                            Text("パスワード")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.top, 4)
                            SecureField("パスワード", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .padding(16)
                    }

                    Button(action: {
                        Task { await submit() }
                    }) {
                        Text("ログイン")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSubmit ? Color.orange : Color.gray.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                    .disabled(!canSubmit || isSubmitting)

                    Button(action: { dismiss() }) {
                        Text("キャンセル")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                    .disabled(isSubmitting)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("ログイン")
            .tint(Color.orange)
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("戻る")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.orange)
                    }
                }
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }

            if isSubmitting || authManager.isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("ログイン中…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.7))
                }
                .padding(18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }

    private func submit() async {
        await MainActor.run { isSubmitting = true }
        do {
            try await authManager.signIn(email: email, password: password)
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                showErrorAlert = true
                isSubmitting = false
            }
            return
        }
        await MainActor.run { isSubmitting = false }
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    let required: Bool
    let content: Content

    init(title: String, required: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.required = required
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                if required {
                    Text("必須")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Spacer()
            }
            content
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct WebRoute: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

private struct WebSheet: View {
    let url: URL
    let title: String

    var body: some View {
#if canImport(SafariServices) && canImport(UIKit)
        SafariView(url: url)
            .ignoresSafeArea()
#else
        NavigationStack {
            VStack(spacing: 12) {
                Text("ブラウザで開いてください")
                    .font(.system(size: 15, weight: .semibold))
                Link(url.absoluteString, destination: url)
            }
            .padding(18)
            .navigationTitle(title)
        }
#endif
    }
}

#if canImport(SafariServices) && canImport(UIKit)
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif

private extension DateFormatter {
    static let jpDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.black.opacity(0.08))
            .padding(.leading, 16)
    }
}

private struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
