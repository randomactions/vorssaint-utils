// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import AppKit

/// A scoped local monitor reads two-finger scrolling without stealing clicks
/// from SwiftUI controls, dragging, or scrolling elsewhere on the panel.
struct PreviewSwipeReader: NSViewRepresentable {
    let enabled: Bool
    let orientation: DockPreviewOrientation
    let action: (WindowEnhancementAction) -> Void
    func makeNSView(context: Context) -> Reader { Reader() }
    func updateNSView(_ view: Reader, context: Context) { view.enabled = enabled; view.orientation = orientation; view.action = action }
    static func dismantleNSView(_ view: Reader, coordinator: ()) { view.stop() }
    final class Reader: NSView {
        var enabled = false
        var orientation: DockPreviewOrientation = .bottom
        var action: ((WindowEnhancementAction) -> Void)?
        private var monitor: Any?
        private var travel: CGFloat = 0
        private var spent = false
        override func viewDidMoveToWindow() {
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.enabled, event.window === self.window, event.hasPreciseScrollingDeltas,
                      self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
                if event.phase == .began { self.travel = 0; self.spent = false }
                if event.momentumPhase != [] { return event }
                let delta = self.orientation == .bottom ? event.scrollingDeltaY : event.scrollingDeltaX
                self.travel += delta
                if abs(self.travel) > 50, !self.spent {
                    self.spent = true
                    let away = self.orientation == .left ? self.travel < 0 : self.travel > 0
                    self.action?(away ? .maximize : .minimize)
                }
                if event.phase == .ended || event.phase == .cancelled { self.travel = 0; self.spent = false }
                return nil
            }
        }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
        deinit { stop() }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
