// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

final class DockIndicatorService {
    static let shared = DockIndicatorService()
    private var timer: Timer?
    private var panels: [String: NSPanel] = [:]
    private var colors: [String: NSColor] = [:]
    private var windowed = Set<pid_t>()
    private var lastWindowRead: TimeInterval = 0
    private init() {}

    func syncWithPreferences() {
        guard AppFeature.dockIndicator.isAvailable, DockOption.indicatorEnabled.bool,
              Permissions.shared.accessibility, SessionActivity.shared.isActive else { stop(); return }
        if timer == nil {
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.refresh() }
            timer.tolerance = 0.025
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        refresh()
    }
    func stop() {
        timer?.invalidate(); timer = nil
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll(); colors.removeAll(); windowed.removeAll(); lastWindowRead = 0
    }
    private func refresh() {
        guard SessionActivity.shared.isActive, AXIsProcessTrusted() else {
            panels.values.forEach { $0.orderOut(nil) }; return
        }
        let items = DockAccessibility.items().filter { $0.subrole == "AXApplicationDockItem" }
        let orientation = DockAccessibility.orientation
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let dots = DockOption.indicatorStyle.string == "dots"
        if dots, ProcessInfo.processInfo.systemUptime - lastWindowRead > 0.75 {
            lastWindowRead = ProcessInfo.processInfo.systemUptime
            let metadata = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            windowed = Set(metadata.filter { ($0[kCGWindowLayer as String] as? Int) == 0 }.compactMap { $0[kCGWindowOwnerPID as String] as? pid_t })
        }
        var wanted = Set<String>()
        let rgb = DockEnhancementSupport.hexRGB(DockOption.indicatorColor.string)
        let color = NSColor(srgbRed: Double((rgb >> 16) & 255) / 255,
                            green: Double((rgb >> 8) & 255) / 255,
                            blue: Double(rgb & 255) / 255, alpha: 1)
        for item in items {
            guard let app = DockAccessibility.application(for: item), dots || app.processIdentifier == front,
                  let screen = NSScreen.screens.first(where: { $0.frame.intersects(item.frame) }),
                  screen.frame.contains(item.frame.dockCenter) else { continue }
            // Hidden Dock tiles retain AX frames beyond their screen edge.
            // Intersections alone would leave a colored sliver on that edge.
            let key = String(app.processIdentifier)
            wanted.insert(key)
            let thickness = dots ? 4 : DockOption.indicatorThickness.double
            let frame = DockEnhancementSupport.indicatorFrame(icon: item.frame, orientation: orientation,
                thickness: thickness, length: dots ? 4 : DockOption.indicatorLength.double,
                offset: DockOption.indicatorOffset.double)
            let panel = panels[key] ?? makePanel()
            panels[key] = panel
            panel.setFrame(frame, display: true)
            let tint = app.processIdentifier == front ? color : color.withAlphaComponent(0.4)
            let hollow = dots && app.processIdentifier != front && !windowed.contains(app.processIdentifier)
            panel.contentView?.layer?.borderWidth = hollow ? 1 : 0
            panel.contentView?.layer?.borderColor = tint.cgColor
            let fill = hollow ? NSColor.clear : tint
            if colors[key] != fill {
                panel.contentView?.layer?.backgroundColor = fill.cgColor
                colors[key] = fill
            }
            panel.contentView?.layer?.cornerRadius = min(frame.width, frame.height) / 2
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
        for key in Array(panels.keys) where !wanted.contains(key) {
            panels.removeValue(forKey: key)?.orderOut(nil); colors.removeValue(forKey: key)
        }
    }
    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        panel.contentView = NSView(); panel.contentView?.wantsLayer = true
        return panel
    }
}
