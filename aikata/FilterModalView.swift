import SwiftUI

struct FilterModalView: View {
    @Binding var filter: PostFilter
    @Binding var isPresented: Bool
    var onApply: () -> Void
    
    // Local state for editing before applying
    @State private var tempFilter: PostFilter
    @State private var isShowingRegionSelection = false
    
    init(filter: Binding<PostFilter>, isPresented: Binding<Bool>, onApply: @escaping () -> Void) {
        self._filter = filter
        self._isPresented = isPresented
        self.onApply = onApply
        self._tempFilter = State(initialValue: filter.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("絞り込み")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                // Region Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("地域")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        isShowingRegionSelection = true
                    }) {
                        HStack {
                            Text(tempFilter.regions.isEmpty ? "全地域" : tempFilter.regions.joined(separator: "、"))
                                .foregroundColor(tempFilter.regions.isEmpty ? .gray : .white)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // Age Range
                VStack(alignment: .leading, spacing: 8) {
                    Text("年齢層")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Picker("Min Age", selection: $tempFilter.minAge) {
                            ForEach(18...100, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.white)
                        
                        Text("-")
                            .foregroundColor(.white)
                        
                        Picker("Max Age", selection: $tempFilter.maxAge) {
                            ForEach(18...100, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.white)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Only my posts toggle
                HStack {
                    Text("自分の投稿のみを表示")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: $tempFilter.onlyMyPosts)
                        .labelsHidden()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Bottom Buttons
                HStack {
                    Button(action: {
                        tempFilter = PostFilter() // Reset to default
                    }) {
                        Text("クリア")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    
                    Button(action: {
                        filter = tempFilter
                        isPresented = false
                        onApply()
                    }) {
                        Text("検索")
                            .foregroundColor(.gray) // Or blue based on preference
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .background(Color(hex: "#2C2C2E")) // Dark gray background similar to image
            .cornerRadius(20)
            .padding(.horizontal, 40)
            .shadow(radius: 10)
        }
        .sheet(isPresented: $isShowingRegionSelection) {
            RegionSelectionView(selectedRegions: $tempFilter.regions)
        }
    }
}

#Preview {
    FilterModalView(filter: .constant(PostFilter()), isPresented: .constant(true), onApply: {})
}