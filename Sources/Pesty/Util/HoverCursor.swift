import AppKit
import SwiftUI

extension View {
    func hoverCursor(_ cursor: NSCursor) -> some View {
        // Track the complete SwiftUI bounds, including transparent padding.
        contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    cursor.set()
                case .ended:
                    NSCursor.arrow.set()
                }
            }
    }
}
