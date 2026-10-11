// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

extension MenuBarOrganizerCapabilities {
    static let unavailable = Self(canEnumerate: false, canMove: false,
                                  hasPrivateWindowList: false, unresolvedItemCount: 0)
}

enum MenuBarOrganizerPolicy {
    static var supportsAdvancedBackend: Bool {
        supportsAdvancedBackend(majorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    static func supportsAdvancedBackend(majorVersion: Int) -> Bool { (14...26).contains(majorVersion) }

    static func validFrame(_ frame: CGRect) -> Bool {
        [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
            && frame.width > 0 && frame.width < 2_048 && frame.height > 0 && frame.height <= 64
    }

    /// Search all words in order within the name, then prefer contiguous matches.
    static func searchScore(query: String, name: String) -> Int? {
        let query = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !query.isEmpty else { return 0 }
        if name.hasPrefix(query) { return 0 }
        if name.contains(query) { return 1 }
        var remaining = name[...]
        var score = 2
        for character in query where !character.isWhitespace {
            guard let index = remaining.firstIndex(of: character) else { return nil }
            score += remaining.distance(from: remaining.startIndex, to: index)
            remaining = remaining[remaining.index(after: index)...]
        }
        return score
    }

    static func uniquelyIdentified(_ id: MenuBarItemIdentity, in items: [ManagedMenuBarItem], allowProtected: Bool = false) -> ManagedMenuBarItem? {
        let matches = items.filter { $0.id.bundleIdentifier == id.bundleIdentifier && $0.id.title == id.title }
        guard matches.count == 1, let item = matches.first, item.id == id,
              item.identityState == .stable, (allowProtected || !item.isProtected),
              validFrame(item.frame) else { return nil }
        return item
    }

    static func verifiedMove(windowID: CGWindowID, before targetID: CGWindowID?,
                             section: MenuBarOrganizerSection, items: [ManagedMenuBarItem]) -> Bool {
        let matches = items.filter { $0.windowID == windowID }
        guard matches.count == 1, let item = matches.first, item.section == section else { return false }
        let ordered = MenuBarOrganizerSupport.orderedItems(items, in: section)
        guard let targetID else { return ordered.last?.windowID == windowID }
        guard let index = ordered.firstIndex(where: { $0.windowID == windowID }),
              index + 1 < ordered.count else { return false }
        return ordered[index + 1].windowID == targetID
    }

    static func isOwnItem(ownerPID: pid_t, sourcePID: pid_t?, bundleIdentifier: String,
                          currentPID: pid_t, currentBundleIdentifier: String?) -> Bool {
        ownerPID == currentPID || sourcePID == currentPID
            || (currentBundleIdentifier.map { $0 == bundleIdentifier } ?? false)
    }

    static let conflictingBundleIDs: Set<String> = [
        "com.jordanbaird.Ice", "com.surteesstudios.Bartender", "com.surteesstudios.Bartender5",
        "com.surteesstudios.Bartender6", "com.matthewpalmer.Vanilla", "com.dwarvesv.minimalbar",
        "com.stonerl.Thaw"
    ]

    static func conflictingManagers() -> [String] {
        NSWorkspace.shared.runningApplications.filter {
            conflictingBundleIDs.contains($0.bundleIdentifier ?? "") && !$0.isTerminated
        }.compactMap(\.localizedName).sorted()
    }
}

/// A pending synthetic button and hidden cursor must be released synchronously
/// on disable/quit, even if the suspended task cannot resume its defer yet.
final class MenuBarInputCleanup {
    var release: (() -> Void)?
    var restoreCursor: (() -> Void)?
    func finish() {
        let release = self.release
        let restore = restoreCursor
        self.release = nil
        restoreCursor = nil
        release?()
        restore?()
    }
}
