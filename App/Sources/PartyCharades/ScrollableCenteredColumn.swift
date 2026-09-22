import SwiftUI

/// PRD §11.1 — Dynamic Type must never clip or truncate. Several screens
/// vertically center their content between `Spacer()`s at normal text
/// sizes; at large accessibility sizes that same layout proposes
/// less-than-ideal height to text, which truncates with an ellipsis instead
/// of wrapping. Wrapping in this instead of a bare `VStack` keeps the exact
/// same centered look at normal sizes (`minHeight` lets the `Spacer`s fill
/// the screen as before) while letting content grow and scroll once it no
/// longer fits, rather than clip.
///
/// Text within still needs `.fixedSize(horizontal: false, vertical: true)`
/// on any element that must never truncate — this container only fixes the
/// *layout's* space pressure, not each view's own truncation default.
struct ScrollableCenteredColumn<Content: View>: View {
    var spacing: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: spacing) {
                    content
                }
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}
