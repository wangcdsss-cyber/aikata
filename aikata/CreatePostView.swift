import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firestoreService: FirestoreService
    let user: AppUser
    
    @State private var selectedRegions: [String] = []
    @State private var content = ""
    @State private var isShowingRegionSelection = false
    @State private var isShowingConfirmation = false
    
    let maxContentLength = 800
    
    var isFormValid: Bool {
        !selectedRegions.isEmpty && !content.isEmpty && content.count <= maxContentLength
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 募集条件
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 16)
                                Text("募集条件")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            // 地域
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("地域")
                                        .foregroundColor(.white)
                                    Text("必須")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Button(action: {
                                    isShowingRegionSelection = true
                                }) {
                                    HStack {
                                        if selectedRegions.isEmpty {
                                            Text("選択してください")
                                                .foregroundColor(.gray)
                                        } else {
                                            Text(selectedRegions.joined(separator: "、"))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.darkGray))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        // 募集内容
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 16)
                                Text("募集内容")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("必須")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Spacer()
                                Text("\(content.count)/\(maxContentLength)")
                                    .font(.caption)
                                    .foregroundColor(content.count > maxContentLength ? .red : .gray)
                            }
                            
                            TextEditor(text: $content)
                                .padding(8)
                                .background(Color(.darkGray))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .frame(height: 200)
                                .scrollContentBackground(.hidden) // For iOS 16+ to show background
                                .onChange(of: content) { newValue in
                                    if newValue.count > maxContentLength {
                                        content = String(newValue.prefix(maxContentLength))
                                    }
                                }
                        }
                        
                        // 注意事項
                        VStack(alignment: .leading, spacing: 4) {
                            Text("【注意事項】")
                            Text("※アイコンがご自身が写った写真に設定していない場合、投稿を削除いたします。")
                            Text("※募集期間を過ぎたものは削除されます。")
                            Text("※宣伝、ネットワークビジネス、パーティー業者と見受けられるものは禁止となっています。見つけ次第、削除退会処置をとります。")
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: PostConfirmationView(
                            user: user,
                            regions: selectedRegions,
                            content: content,
                            rootDismiss: dismiss
                        ).environmentObject(firestoreService),
                        isActive: $isShowingConfirmation
                    ) {
                        Text("投稿内容を確認")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isFormValid ? Color.gray.opacity(0.3) : Color.clear)
                            .foregroundColor(isFormValid ? .white : .gray)
                            .cornerRadius(16)
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $isShowingRegionSelection) {
                RegionSelectionView(selectedRegions: $selectedRegions)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    CreatePostView(user: AppUser(name: "テスト", gender: .female, createdAt: Date()))
        .environmentObject(FirestoreService())
}
