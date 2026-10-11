# Menu bar organizer

The opt-in Menu Bar Hider has advanced controls on the same Settings page.
Basic hiding uses the native dividers from PR #2741 and requires no permission.

## Advanced controls

On macOS 14–26, enable Advanced controls and grant Accessibility to arrange
items from Settings or open the icon drawer. Drag a tile before another tile,
or onto the end of a section. A context menu offers the same section choices.
Undo returns the last successfully moved item to its previous neighbor/section.
The always-hidden section is usable only when its divider is enabled.

The drawer appears below the menu bar and scrolls independently of available
menu bar width. Search supports case/diacritic-insensitive fuzzy matches, arrow
navigation, Return and Escape. Always-hidden items are included only when
explicitly selected. Previews use app icons, not screen captures; Screen
Recording is not required. Some system items therefore use a generic icon.

Activating a hidden item temporarily moves its real status item into the visible
section, opens its native menu, then restores its original position after the
menu closes. Unknown, duplicate, protected, stale or unresolved item identities
are refused. Failed operations leave the bar revealed for manual recovery;
they are reported rather than treated as completed. Disable, uninstall and quit
cancel operations and release pending mouse input and cursor suppression.

The advanced backend is adapted from the earlier #360 proposal. It uses optional
WindowServer queries and synthesized Command-drags, gated before initialization
on macOS 27 and later. Missing private geometry queries disable automatic
operations. The underlying #2741 hider remains usable on newer systems. Stop
other menu bar managers before using advanced controls.

## Spacing

Choose 4–32 points and click Apply to change `NSStatusItemSpacing` and
`NSStatusItemSelectionPadding` in the current-host global preference domain.
Applications pick these preferences up when restarted; signing out updates all
items. Vorssaint does not quit or relaunch other apps automatically.

Restore previous spacing restores both prior values, including removing a key
that was originally absent. The first Apply preserves the original values until
Restore succeeds, even across subsequent Apply operations or app restarts.
Restore remains available when the hider is disabled. This recovery state is
local to this Mac and is excluded from settings backup. The desired spacing and
other organizer preferences participate in normal backups.

## Appearance

Optional decoration adds solid tint or gradient, border, shadow, rounded edges
and separate segments around the camera notch. The overlay ignores mouse input
and sits below the status items. It is removed when the hider or decoration is
disabled. Automatically hidden menu bars are left undecorated.

## Validation boundary

Automated tests cover search, geometry, ambiguity, section/neighbor verification,
platform gates, synchronous input cleanup, spacing transactions and rollback,
settings backup, contextual permission demand and all fifteen locales. These are
isolated tests; they do not synthesize input or modify the host's global spacing.

Before leaving draft, verify the following physically on supported macOS versions:

- Drag between all three sections, reorder within each, and undo including a
  protected neighbor and an empty section.
- Activate items with a native menu and a popover, leave the menu open beyond
  the auto-collapse delay, and check temporary movement and restoration.
- Try a notched display, a display without a notch, multiple displays, Spaces,
  fullscreen, automatic menu bar hiding, wake and a relaunch.
- Revoke Accessibility, disable/uninstall during a drag or click, and check that
  the cursor and mouse button are restored.
- Apply and restore spacing with originally absent/custom values, then restart
  apps and verify the result. No live global preferences were changed by tests.
- Check overlay layering, contrast, notch split, shadow and pointer pass-through
  in light and dark appearance.
- Check macOS 27 basic hiding and that advanced controls stay gated without
  touching the older private backend.

The settings image, if supplied, is a native rendering with sample inventory.
It demonstrates layout only, not successful desktop interaction.

## Attribution

The branch preserves #2741's commits by @0xJJphy. Inventory, identity resolution,
movement and WindowServer query code are adapted from #360 by @ruvelro and
@frogkingg. Ice informed the feature comparison; no Ice source was copied.
