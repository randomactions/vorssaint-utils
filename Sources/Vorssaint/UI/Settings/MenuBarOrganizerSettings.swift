// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The three groups are always visible; permission gates actions, not discovery.
struct MenuBarOrganizerEditor: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = MenuBarOrganizerService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.menuBarHiderEnabled) private var hiderEnabled = false
    @State private var pageVisible = false
    @State private var query = ""
    private var text: MenuBarOrganizerStrings { FeatureStrings.menuBarOrganizer(l10n.language) }
    private var labels: MenuBarEditorStrings { FeatureStrings.menuBarEditor(l10n.language) }
    private var hiderText: MenuBarHiderStrings { FeatureStrings.menuBarHider(l10n.language) }
    private var canArrange: Bool { hiderEnabled && service.isRunning && permissions.accessibility && !service.isBusy }

    var body: some View {
        SettingsCard(title: text.arrange) {
            Text(labels.inventory).font(.callout).foregroundStyle(.secondary)
            if !MenuBarOrganizerPolicy.supportsAdvancedBackend {
                Text(text.unsupported).font(.caption).foregroundStyle(.secondary)
            } else if hiderEnabled && !permissions.accessibility {
                PermissionRow(kind: .accessibility)
                Text(text.permission).font(.caption).foregroundStyle(.secondary)
            }
            if !MenuBarOrganizerPolicy.conflictingManagers().isEmpty {
                Text(text.conflict).font(.caption).foregroundStyle(.orange)
            }
            if service.inventoryUnavailable {
                Text(labels.unavailable).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                TextField(text.placeholder, text: $query).textFieldStyle(.roundedBorder)
                Button(text.refresh) { service.refresh() }.disabled(!service.isRunning || service.isBusy)
                Button(text.undo) { service.undoLastMove() }.disabled(!canArrange || !service.canUndo)
            }
            VStack(spacing: 12) {
                ForEach(MenuBarOrganizerSection.allCases) { section in
                    category(section)
                }
            }
            HStack {
                Button(text.drawer) { service.showDrawer() }
                Button(text.search) { service.showDrawer(search: true) }
                if service.isBusy { ProgressView().controlSize(.small) }
                Spacer()
            }
            .disabled(!canArrange)
            if let message = service.message {
                Text(message).font(.caption).foregroundStyle(.secondary).accessibilityLabel(message)
            }
        }
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

    private func caption(_ section: MenuBarOrganizerSection) -> String {
        switch section {
        case .visible: return labels.visible
        case .hidden: return labels.hidden
        case .alwaysHidden: return labels.alwaysHidden
        }
    }

    private func category(_ section: MenuBarOrganizerSection) -> some View {
        let items = MenuBarOrganizerSupport.orderedItems(service.items, in: section)
        let matches = items.filter { MenuBarOrganizerPolicy.searchScore(query: query, name: $0.displayName) != nil }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title(section)).font(.subheadline.weight(.semibold))
                Text(items.count, format: .number).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(caption(section)).font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(matches) { item in itemCell(item, section: section) }
                    Text(matches.isEmpty && !query.isEmpty ? text.empty : labels.drop)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: matches.isEmpty ? 240 : 96, height: 64)
                }
                .padding(.vertical, 4)
            }
            .frame(height: 84)

        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { values, _ in drop(values, before: nil, section: section) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title(section))
    }

    @ViewBuilder private func itemCell(_ item: ManagedMenuBarItem, section: MenuBarOrganizerSection) -> some View {
        let tile = VStack(spacing: 5) {
            MenuBarItemThumbnail(item: item).frame(width: 24, height: 24)
                .overlay(alignment: .bottomTrailing) {
                    if !item.isMovable {
                        Image(systemName: "lock.fill").font(.system(size: 8))
                            .padding(2).background(.background, in: Circle())
                    }
                }
            Text(item.displayName).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(width: 68, height: 64)
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
        .help(item.isMovable ? item.displayName : "\(item.displayName) — \(labels.locked)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.displayName)
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            ForEach(MenuBarOrganizerSection.allCases) { destination in
                Button(title(destination)) { service.move(id: item.id, before: nil, to: destination) }
                    .disabled(!canArrange || !item.isMovable || destination == section)
            }
        }
        if canArrange && item.isMovable {
            tile.draggable(encoded(item.id))
                .dropDestination(for: String.self) { values, _ in drop(values, before: item.id, section: section) }
        } else { tile }
    }

    private func encoded(_ id: MenuBarItemIdentity) -> String {
        (try? JSONEncoder().encode(id)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func drop(_ values: [String], before target: MenuBarItemIdentity?, section: MenuBarOrganizerSection) -> Bool {
        guard canArrange, values.count == 1, let value = values.first?.data(using: .utf8),
              let id = try? JSONDecoder().decode(MenuBarItemIdentity.self, from: value),
              service.items.contains(where: { $0.id == id && $0.isMovable }) else { return false }
        service.move(id: id, before: target, to: section)
        return true
    }
}

struct MenuBarOrganizerOptions: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = MenuBarOrganizerService.shared
    @AppStorage(DefaultsKey.menuBarHiderEnabled) private var hiderEnabled = false
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
    private var text: MenuBarOrganizerStrings { FeatureStrings.menuBarOrganizer(l10n.language) }

    var body: some View {
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
        .onChange(of: appearance) { _, _ in service.syncWithPreferences() }
        .onChange(of: gradient) { _, _ in service.syncWithPreferences() }
        .onChange(of: border) { _, _ in service.syncWithPreferences() }
        .onChange(of: shadow) { _, _ in service.syncWithPreferences() }
        .onChange(of: rounded) { _, _ in service.syncWithPreferences() }
        .onChange(of: split) { _, _ in service.syncWithPreferences() }
        .onChange(of: first) { _, _ in service.syncWithPreferences() }
        .onChange(of: second) { _, _ in service.syncWithPreferences() }
        .onChange(of: opacity) { _, _ in service.syncWithPreferences() }
    }

    private func colorBinding(_ storage: Binding<String>) -> Binding<Color> {
        Binding(get: { MenuBarAppearanceStyle.color(storage.wrappedValue) }, set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
            storage.wrappedValue = MenuBarUsageBarSupport.hex(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
        })
    }
}
