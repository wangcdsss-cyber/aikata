import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(SafariServices)
import SafariServices
#endif

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firestoreService = FirestoreService()
    @State private var showEdit = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let user = authManager.currentUser {
                    ProfileContentView(
                        user: user,
                        showsEditButton: true,
                        onEditTapped: { showEdit = true }
                    )
                } else {
                    Text("プロフィール情報がありません")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("プロフィール")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            showSettings = true
                        }
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                    .accessibilityLabel("設定")
                }
            }
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .navigationDestination(isPresented: $showEdit) {
                if let user = authManager.currentUser {
                    ProfileEditView(user: user)
                        .environmentObject(firestoreService)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsRootView()
                    .environmentObject(authManager)
            }
        }
    }
}

private struct SettingsRootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firestoreService = FirestoreService()

    @State private var showDeleteEntryConfirm = false
    @State private var showAccountDeletion = false

    private var appVersion: String {
        let short = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        return short
    }

    private var settingsBackground: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SettingsCard {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            SettingsRow(title: "通知設定")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        NavigationLink {
                            EmailConfirmationView()
                        } label: {
                            SettingsRow(title: "メール確認")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        NavigationLink {
                            ThemeColorSelectionView()
                        } label: {
                            SettingsRow(title: "テーマカラー")
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsCard {
                        NavigationLink {
                            TermsOfServiceView()
                        } label: {
                            SettingsRow(title: "利用契約")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            SettingsRow(title: "プライバシーポリシー")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        NavigationLink {
                            ContactUsView()
                        } label: {
                            SettingsRow(title: "お問い合わせ")
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsCard {
                        Button(action: {
                            showDeleteEntryConfirm = true
                        }) {
                            SettingsRow(title: "アカウント削除", titleColor: .red)
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        SettingsRow(title: "バージョン", trailing: appVersion, showsChevron: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(settingsBackground.ignoresSafeArea())
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeStore.selectedTheme.primary)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                }
#if canImport(UIKit)
                ToolbarItem(placement: .principal) {
                    Text("設定")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeStore.selectedTheme.primary)
                }
#endif
            }
            .tint(themeStore.selectedTheme.primary)
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
#endif
            .alert("確認", isPresented: $showDeleteEntryConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("続ける", role: .destructive) {
                    showAccountDeletion = true
                }
            } message: {
                Text("アカウント削除に進みます。よろしいですか？")
            }
            .navigationDestination(isPresented: $showAccountDeletion) {
                AccountDeletionView()
                    .environmentObject(authManager)
            }
        }
    }
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @AppStorage("settings_notifications_enabled") private var notificationsEnabled = true
    @AppStorage("settings_notifications_message") private var messageNotifications = true
    @AppStorage("settings_notifications_board") private var boardNotifications = true
    @AppStorage("settings_notifications_frequency") private var frequency = "通常"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsCard {
                    Toggle(isOn: $notificationsEnabled) {
                        Text("通知を受け取る")
                            .foregroundColor(.black)
                    }
                    .tint(themeStore.selectedTheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    SettingsDivider()

                    Toggle(isOn: $messageNotifications) {
                        Text("メッセージ通知")
                            .foregroundColor(.black)
                    }
                    .tint(themeStore.selectedTheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    SettingsDivider()

                    Toggle(isOn: $boardNotifications) {
                        Text("掲示板通知")
                            .foregroundColor(.black)
                    }
                    .tint(themeStore.selectedTheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                SettingsCard {
                    HStack {
                        Text("通知頻度")
                            .foregroundColor(.black)
                        Spacer()
                        Picker("", selection: $frequency) {
                            Text("通常").tag("通常")
                            Text("少なめ").tag("少なめ")
                            Text("多め").tag("多め")
                        }
                        .pickerStyle(.menu)
                        .tint(themeStore.selectedTheme.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    SettingsDivider()

                    Button(action: {
                        openSystemSettings()
                    }) {
                        SettingsRow(title: "システム通知設定を開く")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(settingsBackground.ignoresSafeArea())
        .navigationTitle("通知設定")
        .tint(themeStore.selectedTheme.primary)
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("通知設定")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeStore.selectedTheme.primary)
            }
        }
#endif
    }

    private var settingsBackground: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    private func openSystemSettings() {
#if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#endif
    }
}

private struct EmailConfirmationView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var isSending = false
    @State private var isRefreshing = false
    @State private var resendCooldownUntil: Date? = nil
    @State private var showMessageAlert = false
    @State private var messageAlertText = ""

    private var emailText: String {
#if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.email ?? "未設定"
#else
        return "未設定"
#endif
    }

    private var isVerified: Bool {
#if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.isEmailVerified ?? false
#else
        return false
#endif
    }

    private var cooldownSecondsRemaining: Int {
        guard let until = resendCooldownUntil else { return 0 }
        let seconds = Int(until.timeIntervalSinceNow.rounded(.up))
        return max(0, seconds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsCard {
                    SettingsRow(title: "メールアドレス", trailing: emailText, showsChevron: false)

                    SettingsDivider()

                    SettingsRow(
                        title: "確認状態",
                        trailing: isVerified ? "確認済み" : "未確認",
                        showsChevron: false
                    )
                }

                SettingsCard {
                    Button(action: {
                        Task { await sendVerificationEmail() }
                    }) {
                        HStack {
                            Text(isVerified ? "確認済み" : (cooldownSecondsRemaining > 0 ? "再送信まで \(cooldownSecondsRemaining)s" : "確認メールを送信"))
                                .foregroundColor(.black)
                            Spacer()
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.gray.opacity(0.55))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isVerified || isSending || cooldownSecondsRemaining > 0)

                    SettingsDivider()

                    Button(action: {
                        Task { await refreshAuthUser() }
                    }) {
                        HStack {
                            Text("確認状態を更新")
                                .foregroundColor(.black)
                            Spacer()
                            if isRefreshing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.gray.opacity(0.55))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(settingsBackground.ignoresSafeArea())
        .navigationTitle("メール確認")
        .tint(themeStore.selectedTheme.primary)
        .alert("メッセージ", isPresented: $showMessageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(messageAlertText)
        }
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("メール確認")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeStore.selectedTheme.primary)
            }
        }
#endif
    }

    private var settingsBackground: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    private func sendVerificationEmail() async {
#if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            await MainActor.run {
                messageAlertText = "ログイン状態を確認できません。"
                showMessageAlert = true
            }
            return
        }
        let trimmedEmail = (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            await MainActor.run {
                messageAlertText = "メールアドレスが未設定です。"
                showMessageAlert = true
            }
            return
        }
        if user.isEmailVerified {
            await MainActor.run {
                messageAlertText = "すでに確認済みです。"
                showMessageAlert = true
            }
            return
        }
        await MainActor.run { isSending = true }
        do {
            try await user.sendEmailVerification()
            await MainActor.run {
                resendCooldownUntil = Date().addingTimeInterval(30)
                messageAlertText = "確認メールを送信しました。数分かかる場合があります。迷惑メール/プロモーションもご確認ください。\n送信先: \(trimmedEmail)"
                showMessageAlert = true
            }
        } catch {
            await MainActor.run {
                messageAlertText = authErrorMessage(error)
                showMessageAlert = true
            }
        }
        await MainActor.run { isSending = false }
#else
        await MainActor.run {
            messageAlertText = "メール確認は未対応です。"
            showMessageAlert = true
        }
#endif
    }

    private func refreshAuthUser() async {
#if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            await MainActor.run {
                messageAlertText = "ログイン状態を確認できません。"
                showMessageAlert = true
            }
            return
        }
        await MainActor.run { isRefreshing = true }
        do {
            try await user.reload()
            await MainActor.run {
                messageAlertText = "更新しました。"
                showMessageAlert = true
            }
        } catch {
            await MainActor.run {
                messageAlertText = "更新に失敗しました: \(error.localizedDescription)"
                showMessageAlert = true
            }
        }
        await MainActor.run { isRefreshing = false }
#else
        await MainActor.run {
            messageAlertText = "確認状態の更新は未対応です。"
            showMessageAlert = true
        }
#endif
    }
}

#if canImport(FirebaseAuth)
private func authErrorMessage(_ error: Error) -> String {
    let nsError = error as NSError
    if let code = AuthErrorCode(rawValue: nsError.code) {
        switch code {
        case .tooManyRequests:
            return "送信回数が多すぎます。しばらく待ってから再度お試しください。"
        case .networkError:
            return "通信エラーが発生しました。ネットワーク状態を確認してください。"
        case .userNotFound:
            return "ユーザーが見つかりません。再ログインしてください。"
        case .invalidRecipientEmail:
            return "メールアドレスが無効です。"
        default:
            return "送信に失敗しました: \(nsError.localizedDescription) (\(nsError.domain) \(nsError.code))"
        }
    }
    return "送信に失敗しました: \(nsError.localizedDescription) (\(nsError.domain) \(nsError.code))"
}
#endif

private struct ThemeColorSelectionView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.colorScheme) private var colorScheme

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        let colors = themeStore.resolvedColors(for: colorScheme)

        ScrollView {
            VStack(spacing: 16) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("テーマカラー")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(AppThemePreset.all) { preset in
                                ThemePresetTile(
                                    preset: preset,
                                    isSelected: preset.id == themeStore.selectedThemeId
                                ) {
                                    themeStore.select(theme: preset)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(settingsBackground.ignoresSafeArea())
        .navigationTitle("テーマカラー")
        .tint(colors.accent)
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("テーマカラー")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colors.accent)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("リセット") {
                    themeStore.reset()
                }
                .font(.system(size: 14, weight: .semibold))
            }
        }
#else
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("リセット") {
                    themeStore.reset()
                }
            }
        }
#endif
    }

    private var settingsBackground: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }
}

private struct ThemePresetTile: View {
    let preset: AppThemePreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(preset.primary)
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(preset.secondary)
                        .frame(width: 18, height: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(preset.primary)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.18))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TermsOfServiceView: View {
    private let urlString = "https://changeable-pegasus-9b4.notion.site/372404b9a4d58099ba66fffe4472eb96?source=copy_link"

    var body: some View {
        WebRouteView(urlString: urlString, title: "利用契約")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("利用契約")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.orange)
                }
            }
#endif
    }
}

private struct PrivacyPolicyView: View {
    private let urlString = "https://changeable-pegasus-9b4.notion.site/372404b9a4d580a2ac45c4baa432a47b?source=copy_link"

    var body: some View {
        WebRouteView(urlString: urlString, title: "プライバシーポリシー")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("プライバシーポリシー")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.orange)
                }
            }
#endif
    }
}

private struct ContactUsView: View {
    private let urlString = "https://forms.gle/K8NMfZg1yL6y7Su39"

    var body: some View {
        WebRouteView(urlString: urlString, title: "お問い合わせ")
            .tint(Color.orange)
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("お問い合わせ")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.orange)
                }
            }
#endif
    }
}

private struct WebRouteView: View {
    let urlString: String
    let title: String

    private var url: URL? {
        URL(string: urlString)
    }

    private var settingsBackground: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    var body: some View {
        Group {
            if let url {
#if canImport(SafariServices)
                SafariView(url: url)
                    .ignoresSafeArea()
#else
                VStack(spacing: 12) {
                    Text("ブラウザで開いてください")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Link(url.absoluteString, destination: url)
                        .font(.system(size: 14))
                }
                .padding(16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .background(settingsBackground.ignoresSafeArea())
#endif
            } else {
                VStack(spacing: 10) {
                    Text("リンクが無効です")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text(urlString)
                        .font(.system(size: 12))
                        .foregroundColor(Color.black.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .background(settingsBackground.ignoresSafeArea())
            }
        }
        .navigationTitle(title)
    }
}

#if canImport(SafariServices)
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif

private struct AccountDeletionView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var showFinalConfirm = false
    @State private var isDeleting = false
    @State private var showResultAlert = false
    @State private var resultText = ""

    private var settingsBackground: Color {
#if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return Color.gray.opacity(0.08)
#endif
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("アカウント削除")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)

                        Text("アカウントを削除すると、復元できない場合があります。よくご確認の上、削除を進めてください。")
                            .font(.system(size: 14))
                            .foregroundColor(Color.black.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }

                SettingsCard {
                    Button(action: {
                        showFinalConfirm = true
                    }) {
                        HStack {
                            Text("アカウントを削除する")
                                .foregroundColor(.red)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.gray.opacity(0.55))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(settingsBackground.ignoresSafeArea())
        .navigationTitle("アカウント削除")
        .tint(Color.orange)
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("アカウント削除")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.orange)
            }
        }
#endif
        .alert("最終確認", isPresented: $showFinalConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("本当にアカウントを削除しますか？")
        }
        .alert("結果", isPresented: $showResultAlert) {
            Button("OK", role: .cancel) {
                if resultText.contains("完了") {
                    dismiss()
                }
            }
        } message: {
            Text(resultText)
        }
    }

    private func deleteAccount() async {
        await MainActor.run {
            isDeleting = true
        }

        let localUserId = authManager.currentUser?.id ?? ""

#if canImport(FirebaseFirestore)
        if !localUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                try await Firestore.firestore().collection("users").document(localUserId).delete()
            } catch {
                await MainActor.run {
                    resultText = "ユーザーデータ削除に失敗しました: \(error.localizedDescription)"
                    showResultAlert = true
                    isDeleting = false
                }
                return
            }
        }
#endif

#if canImport(FirebaseAuth)
        if let firebaseUser = Auth.auth().currentUser {
            do {
                try await firebaseUser.delete()
                try? Auth.auth().signOut()
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: "app_user")
                    authManager.currentUser = nil
                    resultText = "削除が完了しました。"
                    showResultAlert = true
                    isDeleting = false
                }
                return
            } catch {
                await MainActor.run {
                    resultText = "アカウント削除に失敗しました: \(error.localizedDescription)"
                    showResultAlert = true
                    isDeleting = false
                }
                return
            }
        }
#endif

        await MainActor.run {
            UserDefaults.standard.removeObject(forKey: "app_user")
            authManager.currentUser = nil
            resultText = "削除が完了しました。"
            showResultAlert = true
            isDeleting = false
        }
    }
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

private struct SettingsRow: View {
    let title: String
    var trailing: String? = nil
    var titleColor: Color = .black
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(titleColor)
            Spacer()
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 15))
                    .foregroundColor(Color.gray.opacity(0.7))
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.gray.opacity(0.55))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
