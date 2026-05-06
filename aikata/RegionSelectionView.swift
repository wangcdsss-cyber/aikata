import SwiftUI

struct RegionSelectionView: View {
    @Binding var selectedRegions: [String]
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var tempSelectedRegions: [String]
    
    let allPrefectures = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]
    
    init(selectedRegions: Binding<[String]>) {
        self._selectedRegions = selectedRegions
        self._tempSelectedRegions = State(initialValue: selectedRegions.wrappedValue)
    }
    
    var filteredPrefectures: [String] {
        if searchText.isEmpty {
            return allPrefectures
        } else {
            return allPrefectures.filter { $0.contains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("", text: $searchText, prompt: Text("文字検索...").foregroundColor(.gray))
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color(.darkGray))
                .cornerRadius(10)
                .padding()
                
                Text("最大3つまで選択可能です")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                List {
                    ForEach(filteredPrefectures, id: \.self) { prefecture in
                        Button(action: {
                            toggleSelection(prefecture)
                        }) {
                            HStack {
                                Image(systemName: tempSelectedRegions.contains(prefecture) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(tempSelectedRegions.contains(prefecture) ? .blue : .gray)
                                    .font(.system(size: 20))
                                
                                Text(prefecture)
                                    .foregroundColor(.primary)
                                    .padding(.leading, 8)
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
                
                // Bottom Buttons
                HStack(spacing: 0) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("キャンセル")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.darkGray))
                    }
                    
                    Divider() // Adds a separator line between buttons if needed, or you can just use borders
                        .background(Color.gray)
                    
                    Button(action: {
                        selectedRegions = tempSelectedRegions
                        dismiss()
                    }) {
                        Text("OK")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.darkGray))
                    }
                }
                .background(Color(.darkGray))
            }
            .navigationTitle("地域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func toggleSelection(_ prefecture: String) {
        if tempSelectedRegions.contains(prefecture) {
            tempSelectedRegions.removeAll { $0 == prefecture }
        } else {
            if tempSelectedRegions.count < 3 {
                tempSelectedRegions.append(prefecture)
            }
        }
    }
}

#Preview {
    RegionSelectionView(selectedRegions: .constant([]))
}
