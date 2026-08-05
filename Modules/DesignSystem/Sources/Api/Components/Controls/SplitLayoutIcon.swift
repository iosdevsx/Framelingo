import SwiftUI

struct SplitLayoutIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16.0
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: s)
            }
            func filled(_ path: Path, alpha: CGFloat) {
                var c = ctx; c.opacity = alpha; c.fill(path, with: .foreground)
            }
            ctx.stroke(rect(0.5, 0.5, 5.2, 7.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(5.9, 0.5, 4.2, 7.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(10.3, 0.5, 5.2, 7.5), with: .foreground, lineWidth: s)
            let timeline = rect(0.5, 8.5, 15, 3)
            filled(timeline, alpha: 0.25)
            ctx.stroke(timeline, with: .foreground, lineWidth: s)
        }
    }
}
