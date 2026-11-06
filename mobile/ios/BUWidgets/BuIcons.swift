// BuIcons.swift
// Lucide cizgi ikonlari (SF Symbols DEGIL). Veri: BuIconData.swift (uretilmis, 24x24 uzayi).
// Tek renkli sablon cizim: yalniz vurus, rol rengi `foregroundColor` ile verilir.

import SwiftUI

/// 24x24 uzayindaki operasyon dizisini verilen dikdortgene olcekleyen sekil.
struct BuIconShape: Shape {
    let ops: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height) / 24
        let ox = rect.minX
        let oy = rect.minY
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            return CGPoint(x: ox + CGFloat(x) * s, y: oy + CGFloat(y) * s)
        }
        var i = 0
        let n = ops.count
        while i < n {
            let code = Int(ops[i])
            switch code {
            case 0:
                if i + 2 >= n { return path }
                path.move(to: pt(ops[i + 1], ops[i + 2]))
                i += 3
            case 1:
                if i + 2 >= n { return path }
                path.addLine(to: pt(ops[i + 1], ops[i + 2]))
                i += 3
            case 2:
                if i + 6 >= n { return path }
                path.addCurve(to: pt(ops[i + 5], ops[i + 6]),
                              control1: pt(ops[i + 1], ops[i + 2]),
                              control2: pt(ops[i + 3], ops[i + 4]))
                i += 7
            case 3:
                path.closeSubpath()
                i += 1
            default:
                return path
            }
        }
        return path
    }
}

/// Lucide ikonu: `size` pt kare, vurus 1.5 (24 uzayinda; boyutla orantili olceklenir, SVG `width` davranisi).
struct BuIcon: View {
    let name: String
    let size: CGFloat
    let color: Color
    /// RTL'de aynalanacak ikonlar (chevron-right).
    var mirrorsInRTL: Bool = false

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        let shape = BuIconShape(ops: BuIconData.ops(for: name))
            .stroke(color, style: StrokeStyle(lineWidth: BuWidgetTokens.iconStroke * size / 24,
                                              lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
        return shape
            .scaleEffect(x: (mirrorsInRTL && layoutDirection == .rightToLeft) ? -1 : 1, y: 1)
            .accessibilityHidden(true)
    }
}
