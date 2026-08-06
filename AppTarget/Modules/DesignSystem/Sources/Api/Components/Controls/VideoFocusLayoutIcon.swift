import SwiftUI

struct VideoFocusLayoutIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16.0
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: s)
            }
            func filled(_ path: Path, alpha: CGFloat) {
                var c = ctx; c.opacity = alpha; c.fill(path, with: .foreground)
            }
            let video = rect(0.5, 0.5, 9, 7.5)
            filled(video, alpha: 0.18)
            ctx.stroke(video, with: .foreground, lineWidth: s)
            ctx.stroke(rect(9.7, 0.5, 5.8, 3.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(9.7, 4.5, 5.8, 3.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(0.5, 8.5, 15, 3), with: .foreground, lineWidth: s)
        }
    }
}
