import SwiftUI

struct TranscriptLayoutIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16.0
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: s)
            }
            func filled(_ path: Path, alpha: CGFloat) {
                var c = ctx; c.opacity = alpha; c.fill(path, with: .foreground)
            }
            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
                var p = Path()
                p.move(to: CGPoint(x: x1 * s, y: y1 * s))
                p.addLine(to: CGPoint(x: x2 * s, y: y2 * s))
                ctx.stroke(p, with: .foreground, lineWidth: 0.8 * s)
            }
            let video = rect(0.5, 0.5, 7, 3.5)
            filled(video, alpha: 0.18)
            ctx.stroke(video, with: .foreground, lineWidth: s)
            ctx.stroke(rect(0.5, 4.5, 7, 3.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(7.7, 0.5, 7.8, 7.5), with: .foreground, lineWidth: s)
            line(9, 2.5, 14, 2.5)
            line(9, 4.5, 14, 4.5)
            line(9, 6.5, 13, 6.5)
            ctx.stroke(rect(0.5, 8.5, 15, 3), with: .foreground, lineWidth: s)
        }
    }
}

