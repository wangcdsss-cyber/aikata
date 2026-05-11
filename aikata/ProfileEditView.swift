import SwiftUI
import PhotosUI
import UIKit

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firestoreService: FirestoreService

    private let user: AppUser

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var profileImageUrl: String
    @State private var mbti: String
    @State private var workLocation: String
    @State private var occupation: String
    @State private var selfIntroduction: String
    @State private var education: String
    @State private var height: String
    @State private var bodyType: String
    @State private var annualIncome: String
    @State private var birthplace: String
    @State private var frequentDrinkingAreas: [String]

    @State private var showImagePickerPopup = false
    @State private var showSystemPhotoPicker = false
    @State private var showMBTISheet = false
    @State private var showLocationSheet = false
    @State private var showOccupationSheet = false
    @State private var showEducationSheet = false
    @State private var showBodyTypeSheet = false
    @State private var showAnnualIncomeSheet = false
    @State private var showBirthplaceSheet = false
    @State private var showFrequentDrinkingAreaSheet = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    init(user: AppUser) {
        self.user = user
        _profileImageUrl = State(initialValue: user.profileImageUrl ?? "")
        _mbti = State(initialValue: Self.mbtiDisplayValue(for: user.mbti ?? ""))
        _workLocation = State(initialValue: user.workplace ?? user.residence ?? "")
        _occupation = State(initialValue: user.job ?? "")
        _selfIntroduction = State(initialValue: user.selfIntroduction ?? "")
        _education = State(initialValue: user.education ?? "")
        _height = State(initialValue: user.height ?? "")
        _bodyType = State(initialValue: user.bodyType ?? "")
        _annualIncome = State(initialValue: user.annualIncome ?? "")
        _birthplace = State(initialValue: user.birthplace ?? "")
        _frequentDrinkingAreas = State(initialValue: Self.parseDrinkingAreas(from: user.frequentDrinkingArea ?? ""))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileImageEditor
                    basicSelectionSection
                    introSection
                    detailsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if hasChanges {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .confirmationDialog(
            "アップロードする画像は適切なものを選択してください",
            isPresented: $showImagePickerPopup,
            titleVisibility: .visible
        ) {
            Button("アルバムから選択") {
                showSystemPhotoPicker = true
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("不適切な画像や個人情報を含む画像のアップロードは禁止されています。")
        }
        .photosPicker(
            isPresented: $showSystemPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            }
        }
        .sheet(isPresented: $showMBTISheet) {
            SelectionSheetView(
                title: "MBTI",
                options: Self.mbtiOptions,
                selectedValue: $mbti
            )
        }
        .sheet(isPresented: $showLocationSheet) {
            SelectionSheetView(
                title: "勤務地",
                options: Self.prefectures,
                selectedValue: $workLocation
            )
        }
        .sheet(isPresented: $showOccupationSheet) {
            SelectionSheetView(
                title: "職業",
                options: Self.occupationOptions,
                selectedValue: $occupation
            )
        }
        .sheet(isPresented: $showEducationSheet) {
            SelectionSheetView(
                title: "最終学歴",
                options: Self.educationOptions,
                selectedValue: $education
            )
        }
        .sheet(isPresented: $showBodyTypeSheet) {
            SelectionSheetView(
                title: "体型",
                options: Self.bodyTypeOptions,
                selectedValue: $bodyType
            )
        }
        .sheet(isPresented: $showAnnualIncomeSheet) {
            SelectionSheetView(
                title: "年収",
                options: Self.annualIncomeOptions,
                selectedValue: $annualIncome
            )
        }
        .sheet(isPresented: $showBirthplaceSheet) {
            SelectionSheetView(
                title: "出身地",
                options: Self.birthplaceOptions,
                selectedValue: $birthplace
            )
        }
        .sheet(isPresented: $showFrequentDrinkingAreaSheet) {
            DrinkingAreaSelectionSheetView(
                title: "よく飲む地域",
                groupedOptions: Self.drinkingAreaGroupedOptions,
                selectedValues: $frequentDrinkingAreas,
                maxSelection: Self.drinkingAreaMaxSelection
            )
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "保存に失敗しました。")
        }
        .overlay {
            if isSaving {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView("保存中...")
                    .foregroundColor(.white)
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
        }
    }

    private var profileImageEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("プロフィール画像")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 14) {
                profilePreview

                Button {
                    showImagePickerPopup = true
                } label: {
                    Text("画像を選択")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                }
            }
        }
    }

    private var profilePreview: some View {
        Group {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url = URL(string: profileImageUrl), !profileImageUrl.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
    }

    private var basicSelectionSection: some View {
        VStack(spacing: 0) {
            pickerRow(title: "MBTI", value: mbti.isEmpty ? "選択してください" : mbti) {
                showMBTISheet = true
            }
            pickerRow(title: "勤務地", value: workLocation.isEmpty ? "選択してください" : workLocation) {
                showLocationSheet = true
            }
            pickerRow(title: "職業", value: occupation.isEmpty ? "選択してください" : occupation) {
                showOccupationSheet = true
            }
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自己紹介（最大500文字）")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            TextEditor(text: $selfIntroduction)
                .frame(minHeight: 120)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black)
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .onChange(of: selfIntroduction) { _, newValue in
                    if newValue.count > 500 {
                        selfIntroduction = String(newValue.prefix(500))
                    }
                }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("詳細情報")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            pickerRow(title: "最終学歴", value: education.isEmpty ? "選択してください" : education) {
                showEducationSheet = true
            }
            heightTextField(title: "身長", text: $height, placeholder: "例: 175")
            pickerRow(title: "体型", value: bodyType.isEmpty ? "選択してください" : bodyType) {
                showBodyTypeSheet = true
            }
            pickerRow(title: "年収", value: annualIncome.isEmpty ? "選択してください" : annualIncome) {
                showAnnualIncomeSheet = true
            }
            pickerRow(title: "出身地", value: birthplace.isEmpty ? "選択してください" : birthplace) {
                showBirthplaceSheet = true
            }
            pickerRow(title: "よく飲む地域", value: frequentDrinkingAreaDisplayText.isEmpty ? "選択してください" : frequentDrinkingAreaDisplayText) {
                showFrequentDrinkingAreaSheet = true
            }
        }
    }

    private func labeledTextField(title: String, text: Binding<String>, placeholder: String = "入力してください") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(Color.white.opacity(0.9))
                .font(.system(size: 14, weight: .medium))
            TextField(
                "",
                text: text,
                prompt: Text(placeholder).foregroundColor(Color.white.opacity(0.7))
            )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }

    private func heightTextField(title: String, text: Binding<String>, placeholder: String = "例: 175") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(Color.white.opacity(0.9))
                .font(.system(size: 14, weight: .medium))
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: text,
                    prompt: Text(placeholder).foregroundColor(Color.white.opacity(0.7))
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .foregroundColor(.white)
                .cornerRadius(10)
                .keyboardType(.numberPad)

                Text("cm")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.9))
            }
        }
    }

    private func pickerRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.8))
                    .lineLimit(2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .overlay(
                Divider().background(Color.white.opacity(0.1)),
                alignment: .bottom
            )
        }
    }

    private var hasChanges: Bool {
        selectedImage != nil ||
        normalize(profileImageUrl) != normalize(user.profileImageUrl ?? "") ||
        normalize(mbti) != normalize(user.mbti ?? "") ||
        normalize(workLocation) != normalize(user.workplace ?? user.residence ?? "") ||
        normalize(occupation) != normalize(user.job ?? "") ||
        normalize(selfIntroduction) != normalize(user.selfIntroduction ?? "") ||
        normalize(education) != normalize(user.education ?? "") ||
        normalize(height) != normalize(user.height ?? "") ||
        normalize(bodyType) != normalize(user.bodyType ?? "") ||
        normalize(annualIncome) != normalize(user.annualIncome ?? "") ||
        normalize(birthplace) != normalize(user.birthplace ?? "") ||
        normalize(frequentDrinkingAreaStoredValue) != normalize(user.frequentDrinkingArea ?? "")
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    @MainActor
    private func saveProfile() async {
        guard let userId = user.id else {
            errorMessage = "ユーザーIDが見つかりません。"
            showErrorAlert = true
            return
        }
        if !mbti.isEmpty && !Self.mbtiOptions.contains(mbti) {
            errorMessage = "MBTIの値が無効です。"
            showErrorAlert = true
            return
        }
        if !workLocation.isEmpty && !Self.prefectures.contains(workLocation) {
            errorMessage = "勤務地の値が無効です。"
            showErrorAlert = true
            return
        }
        if !occupation.isEmpty && !Self.occupationOptions.contains(occupation) {
            errorMessage = "職業の値が無効です。"
            showErrorAlert = true
            return
        }
        if !education.isEmpty && !Self.educationOptions.contains(education) {
            errorMessage = "最終学歴の値が無効です。"
            showErrorAlert = true
            return
        }
        if !bodyType.isEmpty && !Self.bodyTypeOptions.contains(bodyType) {
            errorMessage = "体型の値が無効です。"
            showErrorAlert = true
            return
        }
        if !annualIncome.isEmpty && !Self.annualIncomeOptions.contains(annualIncome) {
            errorMessage = "年収の値が無効です。"
            showErrorAlert = true
            return
        }
        if !birthplace.isEmpty && !Self.birthplaceOptions.contains(birthplace) {
            errorMessage = "出身地の値が無効です。"
            showErrorAlert = true
            return
        }
        if frequentDrinkingAreas.count > Self.drinkingAreaMaxSelection {
            errorMessage = "よく飲む地域は最大\(Self.drinkingAreaMaxSelection)件まで選択できます。"
            showErrorAlert = true
            return
        }
        let invalidDrinkingAreas = frequentDrinkingAreas.filter { !Self.drinkingAreaOptions.contains($0) }
        if !invalidDrinkingAreas.isEmpty {
            errorMessage = "よく飲む地域の値が無効です。"
            showErrorAlert = true
            return
        }
        if frequentDrinkingAreas.contains("非公開"), frequentDrinkingAreas.count > 1 {
            errorMessage = "「非公開」を選ぶ場合は他の地域を選択できません。"
            showErrorAlert = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            var nextImageURL = profileImageUrl
            if let selectedImage {
                nextImageURL = try await firestoreService.uploadProfileImage(userId: userId, image: selectedImage)
            }

            try await firestoreService.saveUserProfile(
                userId: userId,
                profileImageURL: nextImageURL,
                mbti: mbti,
                workLocation: workLocation,
                occupation: occupation,
                selfIntroduction: selfIntroduction,
                education: education,
                height: height,
                bodyType: bodyType,
                annualIncome: annualIncome,
                birthplace: birthplace,
                frequentDrinkingArea: frequentDrinkingAreaStoredValue
            )

            var updated = user
            updated.profileImageUrl = nextImageURL.isEmpty ? nil : nextImageURL
            updated.mbti = normalize(mbti)
            updated.workplace = normalize(workLocation)
            updated.job = normalize(occupation)
            updated.selfIntroduction = normalize(selfIntroduction)
            updated.education = normalize(education)
            updated.height = normalize(height)
            updated.bodyType = normalize(bodyType)
            updated.annualIncome = normalize(annualIncome)
            updated.birthplace = normalize(birthplace)
            updated.frequentDrinkingArea = normalize(frequentDrinkingAreaStoredValue)

            authManager.updateCurrentUser(updated)
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private static let mbtiLabelByType: [String: String] = [
        "INTJ": "建築家",
        "INTP": "論理学者",
        "ENTJ": "指揮官",
        "ENTP": "討論者",
        "INFJ": "提唱者",
        "INFP": "仲介者",
        "ENFJ": "主人公",
        "ENFP": "運動家",
        "ISTJ": "管理者",
        "ISFJ": "擁護者",
        "ESTJ": "幹部",
        "ESFJ": "領事",
        "ISTP": "巨匠",
        "ISFP": "冒険家",
        "ESTP": "起業家",
        "ESFP": "エンターテイナー"
    ]

    private static let mbtiOptions: [String] = [
        "INTJ（建築家）", "INTP（論理学者）", "ENTJ（指揮官）", "ENTP（討論者）",
        "INFJ（提唱者）", "INFP（仲介者）", "ENFJ（主人公）", "ENFP（運動家）",
        "ISTJ（管理者）", "ISFJ（擁護者）", "ESTJ（幹部）", "ESFJ（領事）",
        "ISTP（巨匠）", "ISFP（冒険家）", "ESTP（起業家）", "ESFP（エンターテイナー）"
    ]

    private static func mbtiDisplayValue(for rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if trimmed.contains("（"), mbtiOptions.contains(trimmed) {
            return trimmed
        }
        if let label = mbtiLabelByType[trimmed] {
            return "\(trimmed)（\(label)）"
        }
        return trimmed
    }

    private static let occupationOptions: [String] = [
        "非公開",
        "会社員",
        "経営者・役員",
        "公務員",
        "自営業",
        "フリーランス",
        "学生",
        "主婦・主夫",
        "無職",
        "医師",
        "歯科医師",
        "看護師",
        "薬剤師",
        "理学療法士",
        "作業療法士",
        "介護士",
        "保育士",
        "教員",
        "講師",
        "研究者",
        "エンジニア",
        "プログラマー",
        "Webエンジニア",
        "インフラエンジニア",
        "データサイエンティスト",
        "ITコンサルタント",
        "営業",
        "企画",
        "マーケティング",
        "広報・PR",
        "事務",
        "人事",
        "総務",
        "法務",
        "財務・経理",
        "会計士",
        "税理士",
        "弁護士",
        "司法書士",
        "行政書士",
        "コンサルタント",
        "デザイナー",
        "UI/UXデザイナー",
        "グラフィックデザイナー",
        "建築士",
        "インテリアデザイナー",
        "美容師",
        "理容師",
        "ネイリスト",
        "エステティシャン",
        "販売員",
        "接客業",
        "飲食店スタッフ",
        "シェフ・調理師",
        "パティシエ",
        "ホテルスタッフ",
        "旅行業",
        "客室乗務員",
        "アパレル",
        "ドライバー",
        "配送業",
        "物流・倉庫",
        "警備員",
        "消防士",
        "警察官",
        "自衛官",
        "建設業",
        "土木作業員",
        "製造業",
        "工場勤務",
        "整備士",
        "農業",
        "漁業",
        "林業",
        "不動産",
        "金融",
        "保険",
        "通訳・翻訳",
        "ライター",
        "編集者",
        "カメラマン",
        "動画クリエイター",
        "YouTuber・配信者",
        "声優",
        "俳優・女優",
        "ミュージシャン",
        "スポーツ選手",
        "インストラクター",
        "その他"
    ]

    private static let prefectures: [String] = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
        "岐阜県", "静岡県", "愛知県", "三重県",
        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]

    private static let educationOptions: [String] = [
        "非公開",
        "中学校卒",
        "高校卒",
        "高専卒",
        "専門学校卒",
        "短期大学卒",
        "大学卒",
        "大学院卒（修士）",
        "大学院卒（博士）",
        "その他"
    ]

    private static let bodyTypeOptions: [String] = [
        "非公開",
        "スリム",
        "ややスリム",
        "普通",
        "筋肉質",
        "がっしり",
        "ややぽっちゃり",
        "ぽっちゃり"
    ]

    private static let annualIncomeOptions: [String] = [
        "非公開",
        "200万円未満",
        "200万〜300万円",
        "300万〜400万円",
        "400万〜500万円",
        "500万〜600万円",
        "600万〜800万円",
        "800万〜1000万円",
        "1000万〜1500万円",
        "1500万〜2000万円",
        "2000万円以上"
    ]

    private static let birthplaceOptions: [String] = prefectures + ["海外", "その他"]
    private static let drinkingAreaSeparator = " / "
    private static let drinkingAreaMaxSelection = 3

    private static let drinkingAreaGroupedOptions: [(region: String, areas: [String])] = [
        ("公開設定", ["非公開"]),
        ("関東", [
            "新宿", "渋谷", "恵比寿", "六本木", "銀座", "池袋", "上野", "赤坂",
            "東京駅・丸の内", "有楽町", "神田", "秋葉原", "御茶ノ水", "神楽坂", "飯田橋",
            "大手町", "日本橋", "人形町", "築地", "新橋", "虎ノ門", "浜松町", "田町",
            "品川", "五反田", "目黒", "中目黒", "代官山", "下北沢", "中野", "高円寺",
            "吉祥寺", "三軒茶屋", "二子玉川", "自由が丘", "蒲田", "北千住", "錦糸町",
            "浅草", "町田", "横浜", "桜木町", "関内", "みなとみらい", "川崎", "武蔵小杉",
            "溝の口", "藤沢", "大宮", "浦和", "川越", "柏", "船橋", "千葉", "津田沼",
            "宇都宮", "高崎", "水戸", "つくば"
        ]),
        ("中部", [
            "甲府", "長野", "松本", "名古屋", "栄", "名駅", "金山", "伏見", "今池",
            "豊田", "岐阜", "四日市", "静岡", "浜松", "新潟", "富山", "金沢", "福井"
        ]),
        ("関西", [
            "梅田", "難波", "天王寺", "心斎橋", "京橋（大阪）", "福島（大阪）", "北新地",
            "天満", "新大阪", "堺東", "京都駅周辺", "四条烏丸", "河原町", "祇園", "木屋町",
            "先斗町", "三宮", "元町", "神戸駅周辺", "姫路", "西宮北口", "奈良", "和歌山"
        ]),
        ("九州・沖縄", [
            "博多", "天神", "中洲", "小倉", "久留米", "佐賀", "長崎", "熊本", "大分",
            "宮崎", "鹿児島", "那覇", "国際通り", "松山（沖縄）"
        ]),
        ("北海道・東北", [
            "すすきの", "札幌駅周辺", "函館", "旭川", "帯広", "仙台", "国分町", "青森",
            "盛岡", "秋田", "山形", "郡山", "福島（福島県）", "いわき"
        ]),
        ("中国・四国", [
            "広島", "流川", "岡山", "倉敷", "高松", "松山", "高知", "徳島", "鳥取",
            "松江", "下関", "宇部"
        ]),
        ("その他", ["その他"])
    ]

    private static let drinkingAreaOptions: [String] = drinkingAreaGroupedOptions.flatMap(\.areas)

    private var frequentDrinkingAreaDisplayText: String {
        frequentDrinkingAreas.joined(separator: Self.drinkingAreaSeparator)
    }

    private var frequentDrinkingAreaStoredValue: String {
        frequentDrinkingAreaDisplayText
    }

    private static func parseDrinkingAreas(from rawValue: String) -> [String] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        let normalized = trimmed
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .replacingOccurrences(of: " / ", with: ",")
            .replacingOccurrences(of: "/", with: ",")
        var deduped: [String] = []
        for token in normalized.split(separator: ",") {
            let area = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !area.isEmpty else { continue }
            if !deduped.contains(area) {
                deduped.append(area)
            }
        }
        if deduped.contains("非公開") {
            return ["非公開"]
        }
        return Array(deduped.prefix(drinkingAreaMaxSelection))
    }
}

private struct SelectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let options: [String]
    @Binding var selectedValue: String

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                List(options, id: \.self) { option in
                    Button {
                        selectedValue = option
                        dismiss()
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundColor(.white)
                            Spacer()
                            if option == selectedValue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .listRowBackground(Color.black)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("戻る")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

private struct DrinkingAreaSelectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let groupedOptions: [(region: String, areas: [String])]
    @Binding var selectedValues: [String]
    let maxSelection: Int
    @State private var searchText = ""

    private var filteredGroupedOptions: [(region: String, areas: [String])] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty {
            return groupedOptions
        }
        return groupedOptions.compactMap { group in
            let filteredAreas = group.areas.filter { $0.localizedCaseInsensitiveContains(keyword) }
            return filteredAreas.isEmpty ? nil : (group.region, filteredAreas)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(filteredGroupedOptions, id: \.region) { group in
                        Section(group.region) {
                            ForEach(group.areas, id: \.self) { option in
                                Button {
                                    toggleSelection(of: option)
                                } label: {
                                    HStack {
                                        Text(option)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if selectedValues.contains(option) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .disabled(isDisabled(option: option))
                                .opacity(isDisabled(option: option) ? 0.45 : 1)
                                .listRowBackground(Color.black)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "地域を検索")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("戻る")
                        }
                        .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func toggleSelection(of option: String) {
        if option == "非公開" {
            if selectedValues.contains(option) {
                selectedValues.removeAll { $0 == option }
            } else {
                selectedValues = [option]
            }
            return
        }

        if let index = selectedValues.firstIndex(of: option) {
            selectedValues.remove(at: index)
            return
        }

        selectedValues.removeAll { $0 == "非公開" }
        guard selectedValues.count < maxSelection else { return }
        selectedValues.append(option)
    }

    private func isDisabled(option: String) -> Bool {
        if selectedValues.contains(option) { return false }
        if option == "非公開" { return false }
        return !selectedValues.contains("非公開") && selectedValues.count >= maxSelection
    }
}
