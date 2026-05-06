import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var name = ""
    @State private var selectedGender: Gender = .female
    
    var body: some View {
        VStack(spacing: 30) {
            Text("AIKATAへようこそ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("まずはあなたのプロフィールを教えてください。性別は後から変更できません。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("名前")
                    .font(.headline)
                TextField("名前を入力", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("性別")
                    .font(.headline)
                Picker("性別", selection: $selectedGender) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            Button(action: {
                authManager.registerUser(name: name, gender: selectedGender)
            }) {
                Text("はじめる")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(name.isEmpty)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 50)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthManager())
}
