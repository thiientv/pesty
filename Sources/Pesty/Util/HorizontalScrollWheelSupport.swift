import AppKit
import SwiftUI

/// Converts a vertical mouse-wheel gesture into horizontal movement while the
/// pointer is over a horizontal SwiftUI scroll view. Trackpad horizontal
/// gestures continue through SwiftUI unchanged.
struct HorizontalScrollWheelSupport: NSViewRepresentable {
    func makeNSView(context: Context) -> HorizontalScrollWheelView {
        HorizontalScrollWheelView()
    }

    func updateNSView(_ nsView: HorizontalScrollWheelView, context: Context) {}

    static func dismantleNSView(_ nsView: HorizontalScrollWheelView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

final class HorizontalScrollWheelView: NSView {
    private var monitor: Any?

    private func descendantScrollViews(of view: NSView) -> [NSScrollView] {
        view.subviews.flatMap { child in
            let own = (child as? NSScrollView).map { [$0] } ?? []
            return own + descendantScrollViews(of: child)
        }
    }

    private func targetScrollView(for event: NSEvent) -> NSScrollView? {
        guard let contentView = window?.contentView else { return nil }
        return descendantScrollViews(of: contentView)
            .filter { scrollView in
                guard let documentView = scrollView.documentView,
                      documentView.bounds.width > scrollView.contentView.bounds.width + 1 else { return false }
                let point = scrollView.convert(event.locationInWindow, from: nil)
                return scrollView.visibleRect.contains(point)
            }
            .min { lhs, rhs in
                lhs.visibleRect.width * lhs.visibleRect.height
                    < rhs.visibleRect.width * rhs.visibleRect.height
            }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }
        let localPoint = convert(event.locationInWindow, from: nil)
        guard bounds.contains(localPoint),
              abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX),
              event.scrollingDeltaY != 0,
              let scrollView = targetScrollView(for: event),
              let documentView = scrollView.documentView else { return event }

        let clipView = scrollView.contentView
        let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 24
        let minX = documentView.bounds.minX
        let maxX = max(minX, documentView.bounds.maxX - clipView.bounds.width)
        let targetX = min(maxX, max(minX, clipView.bounds.origin.x - event.scrollingDeltaY * scale))
        guard targetX != clipView.bounds.origin.x else { return event }
        clipView.scroll(to: NSPoint(x: targetX, y: clipView.bounds.origin.y))
        scrollView.reflectScrolledClipView(clipView)
        return nil
    }

    fileprivate func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    deinit {
        stopMonitoring()
    }
}
