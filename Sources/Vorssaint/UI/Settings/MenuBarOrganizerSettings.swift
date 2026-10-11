// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Advanced settings remain in the existing hider destination and share the
/// same cards, rows, spacing and permission controls as other Vorssaint pages.
struct MenuBarOrganizerSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = MenuBarOrganizerService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.menuBarHiderEnabled) private var hiderEnabled = false
    @AppStorage(DefaultsKey.menuBarOrganizerAdvanced) private var advanced = false
    @AppStorage(DefaultsKey.menuBarOrganizerSpacing) private var spacing = 16
    @AppStorage(DefaultsKey.menuBarOrganizerAppearance) private var appearance = false
    @AppStorage(DefaultsKey.menuBarOrganizerGradient) private var gradient = false
    @AppStorage(DefaultsKey.menuBarOrganizerBorder) private var border = false
    @AppStorage(DefaultsKey.menuBarOrganizerShadow) private var shadow = false
    @AppStorage(DefaultsKey.menuBarOrganizerRounded) private var rounded = true
    @AppStorage(DefaultsKey.menuBarOrganizerSplit) private var split = true
    @AppStorage(DefaultsKey.menuBarOrganizerFirstColor) private var first = "#303038"
    @AppStorage(DefaultsKey.menuBarOrganizerSecondColor) private var second = "#606070"
    @AppStorage(DefaultsKey.menuBarOrganizerOpacity) private var opacity = 0.25
    @State private var pageVisible = false
    private var text: MenuBarOrganizerStrings { FeatureStrings.menuBarOrganizer(l10n.language) }
    private var hiderText: MenuBarHiderStrings { FeatureStrings.menuBarHider(l10n.language) }

    var body: some View {
        SettingsCard(title: text.advanced) {
            SettingsRow(symbol: "slider.horizontal.3", title: text.advanced, caption: text.advancedCaption) {
                Toggle(text.enable, isOn: $advanced).labelsHidden()
            }
            if !MenuBarOrganizerPolicy.supportsAdvancedBackend {
                Text(text.unsupported).font(.caption).foregroundStyle(.secondary)
            } else if advanced {
                PermissionRow(kind: .accessibility)
                if !MenuBarOrganizerPolicy.conflictingManagers().isEmpty {
                    Text(text.conflict).font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button(text.drawer) { service.showDrawer() }
                    Button(text.search) { service.showDrawer(search: true) }
                    Spacer()
                    Button(text.refresh) { service.refresh() }
                    Button(text.undo) { service.undoLastMove() }.disabled(!service.canUndo)
                }
                .disabled(!service.isRunning || service.isBusy)
                Text(text.arrange).font(.headline)
                ForEach(MenuBarOrganizerSection.allCases) { section in sectionEditor(section) }
            }
            if let message = service.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel(message)
            }
        }
        .disabled(!hiderEnabled)
        SettingsCard(title: text.spacing) {
            Text(text.spacingCaption).font(.caption).foregroundStyle(.secondary)
            HStack {
                Slider(value: Binding(get: { Double(spacing) }, set: { spacing = Int($0.rounded()) }), in: 4...32, step: 1)
                    .accessibilityLabel(text.spacing)
                Text("\(MenuBarGlobalSpacing.sanitized(spacing)) pt").monospacedDigit().frame(width: 48)
                Button(text.apply) { service.applySpacing() }
                    .disabled(!hiderEnabled || !MenuBarOrganizerPolicy.supportsAdvancedBackend)
                Button(text.restore) { service.applySpacing(restore: true) }
                    .disabled(!service.canRestoreSpacing)
            }
        }
        SettingsCard(title: text.appearance) {
            SettingsRow(symbol: "paintpalette", title: text.appearance) {
                Toggle(text.enable, isOn: $appearance).labelsHidden()
            }
            if appearance {
                MenuBarAppearancePreview(style: MenuBarAppearanceStyle()).frame(height: 28)
                HStack {
                    ColorPicker(text.firstColor, selection: colorBinding($first), supportsOpacity: false)
                    if gradient { ColorPicker(text.secondColor, selection: colorBinding($second), supportsOpacity: false) }
                }
                HStack {
                    Text(text.opacity)
                    Slider(value: $opacity, in: 0...1).accessibilityLabel(text.opacity)
                }
                HStack {
                    Toggle(text.gradient, isOn: $gradient)
                    Toggle(text.border, isOn: $border)
                    Toggle(text.shadow, isOn: $shadow)
                }
                HStack {
                    Toggle(text.rounded, isOn: $rounded)
                    Toggle(text.split, isOn: $split)
                }
            }
        }
        .disabled(!hiderEnabled)
        .onChange(of: advanced) { _, _ in service.syncWithPreferences() }
        .onChange(of: appearance) { _, _ in service.syncWithPreferences() }
        .onChange(of: gradient) { _, _ in service.syncWithPreferences() }
        .onChange(of: border) { _, _ in service.syncWithPreferences() }
        .onChange(of: shadow) { _, _ in service.syncWithPreferences() }
        .onChange(of: rounded) { _, _ in service.syncWithPreferences() }
        .onChange(of: split) { _, _ in service.syncWithPreferences() }
        .onChange(of: first) { _, _ in service.syncWithPreferences() }
        .onChange(of: second) { _, _ in service.syncWithPreferences() }
        .onChange(of: opacity) { _, _ in service.syncWithPreferences() }
        .onAppear { pageVisible = true; service.setEditorVisible(true) }
        .onDisappear { pageVisible = false; service.setEditorVisible(false) }
        .onReceive(SettingsWindowVisibility.shared.$isVisible) { if pageVisible { service.setEditorVisible($0) } }
    }

    private func title(_ section: MenuBarOrganizerSection) -> String {
        switch section {
        case .visible: return hiderText.diagramVisible
        case .hidden: return hiderText.diagramHidden
        case .alwaysHidden: return hiderText.diagramAlwaysHidden
        }
    }

    private func sectionEditor(_ section: MenuBarOrganizerSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title(section)).font(.subheadline.weight(.medium))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MenuBarOrganizerSupport.orderedItems(service.items, in: section)) { item in
                        VStack(spacing: 4) {
                            MenuBarItemThumbnail(item: item).frame(width: 22, height: 22)
                            Text(item.displayName).font(.caption2).lineLimit(2)
                        }
                        .frame(width: 88, height: 64)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        .opacity(item.isMovable ? 1 : 0.4)
                        .draggable(encoded(item.id))
                        .dropDestination(for: String.self) { values, _ in
                            drop(values, before: item.id, section: section)
                        }
                        .help(item.displayName)
                        .accessibilityLabel(item.displayName)
                        .contextMenu {
                            ForEach(MenuBarOrganizerSection.allCases) { destination in
                                Button(title(destination)) { service.move(id: item.id, before: nil, to: destination) }
                                    .disabled(!item.isMovable)
                            }
                        }
                    }
                    Text(service.items.contains(where: { $0.section == section }) ? "+" : text.empty)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(minWidth: 88, minHeight: 64)
                        .dropDestination(for: String.self) { values, _ in drop(values, before: nil, section: section) }
                }
                .padding(4)
            }
        }
        .disabled(!service.isRunning || service.isBusy)
    }

    private func encoded(_ id: MenuBarItemIdentity) -> String {
        (try? JSONEncoder().encode(id)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func drop(_ values: [String], before target: MenuBarItemIdentity?, section: MenuBarOrganizerSection) -> Bool {
        guard values.count == 1, let value = values.first?.data(using: .utf8),
              let id = try? JSONDecoder().decode(MenuBarItemIdentity.self, from: value),
              service.items.contains(where: { $0.id == id && $0.isMovable }) else { return false }
        service.move(id: id, before: target, to: section)
        return true
    }

    private func colorBinding(_ storage: Binding<String>) -> Binding<Color> {
        Binding(get: { MenuBarAppearanceStyle.color(storage.wrappedValue) }, set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
            storage.wrappedValue = MenuBarUsageBarSupport.hex(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
        })
    }
}
