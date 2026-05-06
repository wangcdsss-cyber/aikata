import SwiftUI

struct ReportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firestoreService: FirestoreService
    
    let postId: String
    let reportedUserId: String
    let currentUser: AppUser
    
    @State private var selectedType = "迷惑行為"
    @State private var descriptionText = ""
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    let reportTypes = [
        "迷惑行為",
        "違反行為",
        "詐欺行為",
        "商用利用目的",
        "無断の直前キャンセル",
        "他サービス誘導・直接取引",
        "その他"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("何が起きましたか？")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 8)
                        
                        // 種別
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color(hex: "#3182F6"))
                                    .frame(width: 4, height: 16)
                                Text("種別")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            Menu {
                                ForEach(reportTypes, id: \.self) { type in
                                    Button(type) {
                                        selectedType = type
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedType)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.black)
                                .overlay(
                                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.5)),
                                    alignment: .bottom
                                )
                            }
                        }
                        
                        // 説明
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color(hex: "#3182F6"))
                                    .frame(width: 4, height: 16)
                                Text("説明")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(descriptionText.count)/500")
                                    .font(.caption)
                                    .foregroundColor(descriptionText.count > 500 ? .red : .gray)
                            }
                            
                            TextEditor(text: $descriptionText)
                                .padding(8)
                                .frame(height: 150)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                                .onChange(of: descriptionText) { newValue in
                                    if newValue.count > 500 {
                                        descriptionText = String(newValue.prefix(500))
                                    }
                                }
                        }
                        
                        Spacer(minLength: 40)
                        
                        Button(action: submitReport) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                            } else {
                                Text("送信")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                        }
                        .disabled(isSubmitting || descriptionText.isEmpty || descriptionText.count > 500)
                        .opacity((descriptionText.isEmpty || descriptionText.count > 500) ? 0.5 : 1.0)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(isSuccess ? "報告完了" : "エラー"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if isSuccess {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func submitReport() {
        guard !descriptionText.isEmpty else { return }
        isSubmitting = true
        
        Task {
            do {
                try await firestoreService.submitReport(
                    postId: postId,
                    reportedUserId: reportedUserId,
                    reporter: currentUser,
                    reportType: selectedType,
                    description: descriptionText
                )
                
                await MainActor.run {
                    isSubmitting = false
                    isSuccess = true
                    alertMessage = "違反報告を受け付けました。ご協力ありがとうございます。"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    isSuccess = false
                    alertMessage = "報告の送信に失敗しました: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    ReportView(
        postId: "test_post_id",
        reportedUserId: "test_reported_user_id",
        currentUser: AppUser(name: "TestUser", gender: .male, createdAt: Date())
    )
    .environmentObject(FirestoreService())
}
