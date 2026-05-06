import SwiftUI

// A simple FlowLayout to wrap tags (Regions) since standard HStack doesn't wrap automatically.
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return computeSize(rows: rows)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        guard !subviews.isEmpty else { return [] }
        
        var rows: [[LayoutSubview]] = []
        var currentRow: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentWidth + size.width > maxWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [subview]
                currentWidth = size.width + spacing
            } else {
                currentRow.append(subview)
                currentWidth += size.width + spacing
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private func computeSize(rows: [[LayoutSubview]]) -> CGSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        for (index, row) in rows.enumerated() {
            let rowWidth = row.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0))
            width = max(width, rowWidth)
            
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            
            if index < rows.count - 1 {
                height += spacing
            }
        }
        
        return CGSize(width: width, height: height)
    }
}
