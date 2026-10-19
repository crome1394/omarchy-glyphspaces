# Omarchy GlyphSpaces

A bar widget for [Omarchy](https://omarchy.org/) that shows Hyprland workspaces as colored dots with their numbers. The focused workspace is a rounded pill. The plugin id is `crome.workspaces`.

Install and remove it with the Omarchy plugin commands.

Specials stay in front of the numbered workspaces. Order inside each group is the order on the bar: left to right on a top or bottom bar, top to bottom on a side bar. An occupied workspace that is not in the list still appears after the numbered pills.

Left-click focuses a workspace. Scrolling walks specials in order, then the numbered workspaces. Scrolling forward from the last special closes it. Scrolling back from the lowest numbered workspace opens the last special. Right-click opens settings.

Empty numbered pills stay hidden while **Show only active workspace** is on. The focused workspace still shows. A fresh install starts with that on, and with eight colored dots. A saved row from an earlier install is used when one is already on disk.

## Screenshot

![Omarchy GlyphSpaces settings](settings.png)

## Install

```bash
omarchy plugin add https://github.com/crome1394/omarchy-glyphspaces.git
omarchy plugin enable crome.workspaces --section left
```

The stock workspace widget and this one both draw workspaces. Turn the stock one off if you only want these dots:

```bash
omarchy plugin disable omarchy.workspaces
```

Move it with `omarchy bar move crome.workspaces --section <left|center|right>`.

Disable it from the Omarchy menu under Setup, Plugins, or with `omarchy plugin disable crome.workspaces`. Remove it with `omarchy plugin remove crome.workspaces`. While the plugin is enabled, the saved row lives on its entry in `~/.config/omarchy/shell.json`. Disabling drops that entry. A copy stays at `~/.local/state/omarchy/crome.workspaces.json`, and enabling the plugin writes the copy back onto the bar. Removing the plugin deletes its files. That copy stays in the state directory, so a later install brings the same row back.

## Settings

Right-click the widget, or open it over Quickshell IPC. The bar keeps its current look until **Apply**. **Show only active workspace** applies on the click.

**Default workspaces** sets how many numbered pills to keep, from 1 to 10. Specials stay in front of them.

**Set special** turns a numbered row into a special and moves it in front. **Name** is the label in this list. **Workspace** is the Hyprland special name. A different name opens an empty special. **×** removes the row. The last numbered workspace stays. The font and size change the icon only.

**Undo** drops an unapplied draft. With a clean draft, it reverts the last Apply. **Refresh** reloads fonts and the current Hyprland state.

Arrows follow the list. Enter activates or edits a field. Esc leaves a field, then closes the panel. `x` removes the selected row. Left and right change the workspace count.

### IPC

Pass `-p /usr/share/omarchy/shell` so the call reaches Omarchy. `open`, `close`, `show`, `hide`, and `toggle` open or close the settings panel on the focused monitor. `setShowOnlyActive` and `toggleShowOnlyActive` print `on` or `off`.

```bash
qs -p /usr/share/omarchy/shell ipc call crome.workspaces toggle
qs -p /usr/share/omarchy/shell ipc call crome.workspaces open
qs -p /usr/share/omarchy/shell ipc call crome.workspaces close
qs -p /usr/share/omarchy/shell ipc call crome.workspaces setShowOnlyActive true
qs -p /usr/share/omarchy/shell ipc call crome.workspaces toggleShowOnlyActive
```

`show` and `hide` are the same as `open` and `close`.

## Tests

```bash
node --test test/model.test.js
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" -I /usr/lib/qt6/qml BarWidget.qml Panel.qml
```

## License

MIT. See [LICENSE](LICENSE).
