import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as Model

// Colored workspace dots for the Omarchy bar.
//
// Specials stay in front of the numbered workspaces. The focused chip is a
// rounded pill; the others stay bare. Right-click, or Quickshell IPC, opens
// settings. Nothing here reads the Cachy Quickshell config.
Panel {
  id: root
  moduleName: "crome.workspaces"
  ipcTarget: "crome.workspaces"
  manageIpc: false

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : (vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal)
  readonly property int inner: Math.max(12, barSize - 4)
  readonly property color muted: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.7)
  readonly property color cardFill: Qt.rgba(1, 1, 1, 0.04)
  readonly property color cardEdge: Qt.rgba(1, 1, 1, 0.08)
  readonly property bool twoColumns: panel.contentWidth >= 720

  property var shownEntries: []
  property string activeSpecial: ""
  property bool showOnlyActive: true
  property string savedSig: ""
  property var draftRows: []
  property var undoSlots: null
  property var fontFamilies: []
  property var fontOptions: [{ value: "", label: "Bar font" }]
  property bool fontsLoaded: false
  property int focusPolls: 0
  property string navZone: "toggle"
  property int navIndex: 0
  property string navAction: "label"
  property int navFooter: 0
  property string editKey: ""
  property bool fieldLock: false
  property bool fontMenuOpen: false
  property int fontOpenIndex: -1
  property int fontOpenTick: 0

  component MiniButton: Button {
    property bool danger: false
    focusable: false
    bordered: true
    fontSize: Style.font.bodySmall
    horizontalPadding: Style.space(8)
    verticalPadding: Style.space(4)
    foreground: danger ? Color.urgent : Color.popups.text
  }

  function savedRows() {
    return Model.rowsFromSettings(root.settings || {})
  }

  function draftDirty() {
    return Model.signature(root.draftRows) !== Model.signature(root.savedRows())
  }

  function workspaceSnapshots() {
    var out = []
    try {
      var values = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : []
      for (var i = 0; i < values.length; i++) {
        var workspace = values[i]
        if (!workspace || !(workspace.id > 0)) continue
        var occupied = false
        var tops = workspace.toplevels
        if (tops) {
          if (typeof tops.count === "number") occupied = tops.count > 0
          else if (tops.values && typeof tops.values.length === "number") occupied = tops.values.length > 0
        }
        out.push({
          id: workspace.id,
          occupied: occupied,
          active: !!workspace.active,
          focused: !!workspace.focused
        })
      }
    } catch (e) {}
    return out
  }

  function focusedId() {
    try {
      var focused = Hyprland.focusedWorkspace
      return (focused && focused.id > 0) ? focused.id : 0
    } catch (e) {
      return 0
    }
  }

  function rebuild() {
    var next = []
    try {
      next = Model.visibleEntries({
        slots: root.savedRows(),
        workspaces: root.workspaceSnapshots(),
        focusedId: root.focusedId(),
        showOnlyActive: root.showOnlyActive,
        activeSpecial: root.activeSpecial
      })
    } catch (e) {
      return
    }
    if (JSON.stringify(next) === JSON.stringify(root.shownEntries)) return
    root.shownEntries = next
  }

  function specialFromMonitor() {
    try {
      var mon = Hyprland.focusedMonitor
      if (!mon || !mon.lastIpcObject) return root.activeSpecial
      var sw = mon.lastIpcObject.specialWorkspace
      if (!sw) return ""
      var name = typeof sw === "string" ? sw : (sw.name || "")
      return Model.bareSpecial(name)
    } catch (e) {
      return root.activeSpecial
    }
  }

  function syncSpecial() {
    var name = root.specialFromMonitor()
    if (name !== root.activeSpecial) root.activeSpecial = name
    root.rebuild()
  }

  function requestSpecialSync() {
    try { Hyprland.refreshMonitors() } catch (e) {}
    specialSync.restart()
  }

  function monitorMatches(monName) {
    if (!monName) return true
    try {
      var mon = Hyprland.focusedMonitor
      if (!mon || !mon.name) return true
      return String(monName) === String(mon.name)
    } catch (e) {
      return true
    }
  }

  function onHyprEvent(event) {
    if (!event) return
    var name = String(event.name || "")
    if (name === "activespecial" || name === "activespecialv2") {
      var args = []
      try { args = event.parse(name === "activespecialv2" ? 3 : 2) || [] } catch (e) { args = [] }
      var copied = []
      for (var i = 0; i < args.length; i++) copied.push(String(args[i] || ""))
      var wsName = name === "activespecialv2" ? (copied[1] || "") : (copied[0] || "")
      var monName = name === "activespecialv2" ? (copied[2] || "") : (copied[1] || "")
      if (!root.monitorMatches(monName)) return
      root.activeSpecial = Model.bareSpecial(wsName)
      root.requestSpecialSync()
      root.rebuild()
      return
    }
    if (name === "workspace" || name === "workspacev2"
        || name === "focusedmon" || name === "focusedmonv2"
        || name === "createworkspace" || name === "createworkspacev2"
        || name === "destroyworkspace" || name === "destroyworkspacev2"
        || name === "moveworkspace" || name === "moveworkspacev2"
        || name === "activewindow" || name === "activewindowv2"
        || name === "openwindow" || name === "closewindow") {
      root.rebuild()
    }
  }

  function dispatchAll(actions) {
    var list = actions || []
    var parts = []
    for (var i = 0; i < list.length; i++) {
      if (!list[i]) continue
      parts.push("hyprctl dispatch " + Util.shellQuote(list[i]))
    }
    if (!parts.length) return
    if (root.bar && root.bar.run) root.bar.run(parts.join(" && "))
    else {
      for (var j = 0; j < list.length; j++) {
        if (!list[j]) continue
        try { Hyprland.dispatch(list[j]) } catch (e) {}
      }
    }
  }

  function liveState() {
    return {
      slots: root.savedRows(),
      activeSpecial: root.activeSpecial,
      focusedId: root.focusedId()
    }
  }

  function activate(entry) {
    root.dispatchAll(Model.activateActions(entry, root.liveState()))
  }

  function switchRelative(delta) {
    root.dispatchAll(Model.relativeActions(root.liveState(), delta))
  }

  function chipTip(entry) {
    var base = "Right-click for workspace settings"
    if (entry && entry.isSpecial && entry.title) return entry.title + " · " + base
    return base
  }

  function persistSettings(showOnly, slots) {
    var clean = Model.sanitize(slots)
    var entry = {
      id: root.moduleName,
      showOnlyActive: !!showOnly,
      slots: clean
    }
    root.savedSig = Model.signature(clean)
    root.showOnlyActive = !!showOnly
    root.settings = entry
    if (root.bar && root.bar.shell && root.bar.shell.updateEntryInline)
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    root.rebuild()
  }

  function setShowOnly(on) {
    var next = !!on
    if (next === root.showOnlyActive) return
    root.persistSettings(next, root.savedRows())
  }

  function resetDraft() {
    root.editKey = ""
    root.draftRows = root.savedRows()
    root.clampNav()
  }

  function commitDraft(rows) {
    var next = Model.sanitize(rows)
    if (Model.signature(next) === Model.signature(root.draftRows)) return
    root.editKey = ""
    root.fontMenuOpen = false
    root.draftRows = next
    root.clampNav()
  }

  function setDraftCount(count) {
    var n = Math.round(Number(count))
    if (!(n >= 1)) n = 1
    if (n > 10) n = 10
    if (n === Model.numberedCount(root.draftRows)) return
    root.commitDraft(Model.resizeNumbered(root.draftRows, n))
  }

  function applyDraft() {
    if (!root.draftDirty()) return
    root.undoSlots = root.savedRows()
    root.persistSettings(root.showOnlyActive, root.draftRows)
  }

  function undoDraft() {
    if (root.draftDirty()) {
      root.resetDraft()
      return
    }
    if (!root.undoSlots) return
    var previous = root.undoSlots
    root.undoSlots = root.savedRows()
    root.persistSettings(root.showOnlyActive, previous)
    root.resetDraft()
  }

  function addWorkspace() {
    if (Model.numberedCount(root.draftRows) >= 10) return
    root.commitDraft(Model.addNumbered(root.draftRows))
    root.revealNav()
  }

  function ensureFonts(force) {
    if (root.fontsLoaded && !force) return
    var fams = []
    try { fams = Qt.fontFamilies() } catch (e) { fams = [] }
    root.fontFamilies = fams
    var options = []
    var list = Model.fontList(fams, Model.defaultFont())
    for (var i = 0; i < list.length; i++) {
      options.push({ value: list[i], label: list[i] ? list[i] : "Bar font" })
    }
    root.fontOptions = options
    root.fontsLoaded = true
  }

  function refreshPanel() {
    root.ensureFonts(true)
    root.requestSpecialSync()
    try { Hyprland.refreshWorkspaces() } catch (e) {}
    root.rebuild()
    if (!root.draftDirty()) root.resetDraft()
  }

  function ingestSettings() {
    var rows = root.savedRows()
    var sig = Model.signature(rows)
    var slotsChanged = sig !== root.savedSig
    root.savedSig = sig
    var show = Model.truthy(root.setting("showOnlyActive", true))
    if (show !== root.showOnlyActive) root.showOnlyActive = show
    root.rebuild()
    if (slotsChanged && (!root.opened || !root.draftDirty())) root.resetDraft()
  }

  function firstAction(index) {
    var slot = root.draftRows[index]
    if (!slot) return "label"
    var actions = Model.rowActions(slot)
    return actions.length ? actions[0] : "label"
  }

  function clampNav() {
    var rows = root.draftRows || []
    if (root.navFooter < 0) root.navFooter = 0
    if (root.navFooter > 3) root.navFooter = 3
    if (root.navZone !== "row") return
    if (!rows.length) {
      root.navZone = "count"
      return
    }
    if (root.navIndex < 0) root.navIndex = 0
    if (root.navIndex >= rows.length) root.navIndex = rows.length - 1
    var actions = Model.rowActions(rows[root.navIndex])
    var found = false
    for (var i = 0; i < actions.length; i++) if (actions[i] === root.navAction) found = true
    if (!found) root.navAction = actions.length ? actions[0] : "label"
  }

  function rowHot(index, action) {
    return root.navZone === "row" && root.navIndex === index && root.navAction === action
  }

  function revealItem(item) {
    if (!item || !settingsFlick) return
    var pt = item.mapToItem(settingsFlick.contentItem, 0, 0)
    var top = pt.y
    var bottom = top + item.height
    var viewTop = settingsFlick.contentY
    var viewBottom = viewTop + settingsFlick.height
    var margin = 8
    if (top < viewTop + margin) settingsFlick.contentY = Math.max(0, top - margin)
    else if (bottom > viewBottom - margin) settingsFlick.contentY = Math.max(0, bottom + margin - settingsFlick.height)
  }

  function revealNav() {
    Qt.callLater(function() {
      if (root.navZone === "row") root.revealItem(rowRepeater.itemAt(root.navIndex))
      else if (root.navZone === "footer") root.revealItem(footerRow)
      else if (root.navZone === "toggle") root.revealItem(toggleCard)
      else if (root.navZone === "count") root.revealItem(countCard)
    })
  }

  function moveCursor(dx, dy) {
    if (root.navZone === "toggle") {
      if (dy > 0) root.navZone = "count"
      root.revealNav()
      return
    }
    if (root.navZone === "count") {
      if (dy < 0) root.navZone = "toggle"
      else if (dy > 0) {
        if (root.draftRows.length) {
          root.navZone = "row"
          root.navIndex = 0
          root.navAction = root.firstAction(0)
        } else root.navZone = "footer"
      } else if (dx !== 0) root.setDraftCount(Model.numberedCount(root.draftRows) + dx)
      root.revealNav()
      return
    }
    if (root.navZone === "footer") {
      if (dy < 0) {
        if (root.draftRows.length) {
          root.navZone = "row"
          root.navIndex = root.draftRows.length - 1
          root.navAction = root.firstAction(root.navIndex)
        } else root.navZone = "count"
      } else if (dx < 0) root.navFooter = Math.max(0, root.navFooter - 1)
      else if (dx > 0) root.navFooter = Math.min(3, root.navFooter + 1)
      root.revealNav()
      return
    }
    var slot = root.draftRows[root.navIndex]
    var actions = slot ? Model.rowActions(slot) : ["label"]
    var at = 0
    for (var i = 0; i < actions.length; i++) if (actions[i] === root.navAction) at = i
    if (dx !== 0) {
      var next = at + dx
      if (next < 0) next = 0
      if (next >= actions.length) next = actions.length - 1
      root.navAction = actions[next]
      root.revealNav()
      return
    }
    if (dy < 0 && root.navIndex <= 0) {
      root.navZone = "count"
      root.revealNav()
      return
    }
    if (dy > 0 && root.navIndex >= root.draftRows.length - 1) {
      root.navZone = "footer"
      root.navFooter = 0
      root.revealNav()
      return
    }
    root.navIndex = root.navIndex + dy
    var moved = root.draftRows[root.navIndex]
    var movedActions = moved ? Model.rowActions(moved) : ["label"]
    var keep = false
    for (var k = 0; k < movedActions.length; k++) if (movedActions[k] === root.navAction) keep = true
    if (!keep) root.navAction = movedActions.length ? movedActions[0] : "label"
    root.revealNav()
  }

  function removeNavRow() {
    if (root.navZone !== "row") return
    if (!Model.canRemove(root.draftRows, root.navIndex)) return
    root.commitDraft(Model.removeAt(root.draftRows, root.navIndex))
    root.revealNav()
  }

  function activateCursor() {
    if (root.navZone === "toggle") {
      root.setShowOnly(!root.showOnlyActive)
      return
    }
    if (root.navZone === "count") return
    if (root.navZone === "footer") {
      if (root.navFooter === 0) root.addWorkspace()
      else if (root.navFooter === 1) root.applyDraft()
      else if (root.navFooter === 2) root.undoDraft()
      else root.refreshPanel()
      return
    }
    var index = root.navIndex
    var action = root.navAction
    var slot = root.draftRows[index]
    if (!slot) return
    if (action === "title" || action === "label" || action === "workspace") {
      root.editKey = index + ":" + action
      return
    }
    if (action === "up" || action === "down") {
      var delta = action === "up" ? -1 : 1
      if (!Model.canMove(root.draftRows, index, delta)) return
      root.commitDraft(Model.moveWithin(root.draftRows, index, delta))
      root.navIndex = index + delta
      root.navAction = action
      root.clampNav()
      root.revealNav()
      return
    }
    if (action === "special") {
      if (!Model.canSetSpecial(root.draftRows, index)) return
      var turned = Model.setSpecial(root.draftRows, index, slot.kind !== "special")
      root.commitDraft(turned.slots)
      root.navIndex = turned.index
      root.navAction = "special"
      root.clampNav()
      root.revealNav()
      return
    }
    if (action === "remove") {
      root.removeNavRow()
      return
    }
    if (action === "font") {
      root.fontOpenIndex = index
      root.fontOpenTick++
      Qt.callLater(root.openFontMenu)
      return
    }
    if (action === "fontPrev" || action === "fontNext") {
      var font = Model.stepFont(slot.font, action === "fontNext" ? 1 : -1, root.fontFamilies)
      root.commitDraft(Model.setFace(root.draftRows, index, null, font, null))
      return
    }
    if (action === "sizeDown" || action === "sizeUp")
      root.commitDraft(Model.stepSize(root.draftRows, index, action === "sizeUp" ? 1 : -1))
  }

  function commitField(index, action, text, restoreFocus) {
    if (root.fieldLock) return
    root.fieldLock = true
    var before = Model.signature(root.draftRows)
    var rows = root.draftRows
    if (action === "label") rows = Model.setFace(rows, index, text, null, null)
    else if (action === "title") rows = Model.setMeta(rows, index, text, null)
    else if (action === "workspace") rows = Model.setMeta(rows, index, null, text)
    root.editKey = ""
    root.commitDraft(rows)
    if (Model.signature(root.draftRows) === before) {
      var card = rowRepeater.itemAt(index)
      var slot = root.draftRows[index]
      if (card && slot) {
        if (action === "label" && card.labelField) card.labelField.text = slot.label
        if (action === "title" && card.titleField) card.titleField.text = slot.title
        if (action === "workspace" && card.workspaceField) card.workspaceField.text = slot.specialName
      }
    }
    root.fieldLock = false
    if (restoreFocus) {
      Qt.callLater(function() {
        if (root.opened && !root.fontMenuOpen) keyCatcher.forceActiveFocus()
      })
    }
  }

  function fieldFor(card, action) {
    if (!card) return null
    if (action === "label") return card.labelField
    if (action === "title") return card.titleField
    if (action === "workspace") return card.workspaceField
    return null
  }

  function finishEditing(restoreFocus) {
    if (root.fieldLock || !root.editKey) return
    var parts = root.editKey.split(":")
    var index = Math.round(Number(parts[0]))
    var action = parts.length > 1 ? parts[1] : ""
    var card = rowRepeater.itemAt(index)
    var field = root.fieldFor(card, action)
    if (!field) {
      root.editKey = ""
      return
    }
    root.commitField(index, action, field.text, restoreFocus)
  }

  function focusEditor() {
    if (!root.editKey) return
    var parts = root.editKey.split(":")
    var index = Math.round(Number(parts[0]))
    var action = parts.length > 1 ? parts[1] : ""
    var field = root.fieldFor(rowRepeater.itemAt(index), action)
    if (!field) return
    field.forceActiveFocus()
    field.selectAll()
  }

  function openFontMenu() {
    var card = rowRepeater.itemAt(root.fontOpenIndex)
    if (card && card.fontDrop) card.fontDrop.open()
  }

  function cancelEdit(field, original) {
    root.fieldLock = true
    root.editKey = ""
    if (field) field.text = original
    root.fieldLock = false
    keyCatcher.forceActiveFocus()
  }

  function close() {
    root.finishEditing(false)
    if (root.bar) root.bar.hideTooltip(root)
    root.controller.hide()
  }

  function hideTips() {
    if (root.bar) root.bar.hideTooltip(root)
  }

  onEditKeyChanged: if (root.editKey) Qt.callLater(root.focusEditor)

  onSettingsChanged: root.ingestSettings()

  onOpenedChanged: {
    root.hideTips()
    if (root.opened) {
      root.ensureFonts(false)
      if (!root.draftDirty()) root.resetDraft()
      root.navZone = "toggle"
      root.navIndex = 0
      root.navFooter = 0
      root.editKey = ""
      Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
    } else {
      root.finishEditing(false)
      root.editKey = ""
      root.fontMenuOpen = false
    }
  }

  Component.onCompleted: {
    root.savedSig = Model.signature(root.savedRows())
    root.showOnlyActive = Model.truthy(root.setting("showOnlyActive", true))
    root.resetDraft()
    root.rebuild()
    root.requestSpecialSync()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function setShowOnlyActive(enabled: string): string {
      root.setShowOnly(Model.truthy(enabled))
      return root.showOnlyActive ? "on" : "off"
    }
    function toggleShowOnlyActive(): string {
      root.setShowOnly(!root.showOnlyActive)
      return root.showOnlyActive ? "on" : "off"
    }
  }

  Timer {
    id: specialSync
    interval: 80
    repeat: false
    onTriggered: root.syncSpecial()
  }

  Timer {
    interval: 200
    repeat: true
    running: root.focusPolls < 6
    onTriggered: {
      root.focusPolls += 1
      try { Hyprland.refreshWorkspaces() } catch (e) {}
      root.requestSpecialSync()
    }
  }

  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: {
      try { Hyprland.refreshWorkspaces() } catch (e) {}
      root.requestSpecialSync()
    }
  }

  Connections {
    target: Hyprland.workspaces
    function onValuesChanged() { root.rebuild() }
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      root.requestSpecialSync()
      root.rebuild()
    }
    function onFocusedMonitorChanged() {
      root.requestSpecialSync()
      root.rebuild()
    }
    function onRawEvent(event) { root.onHyprEvent(event) }
  }

  Connections {
    target: Hyprland.focusedMonitor
    function onLastIpcObjectChanged() { root.syncSpecial() }
  }

  HoverHandler {
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered && !root.opened) root.bar.showTooltip(root, "Right-click for workspace settings")
      else root.hideTips()
    }
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) {
      var delta = event.angleDelta.y
      if (delta === 0) delta = event.angleDelta.x
      if (delta === 0) delta = event.pixelDelta.y
      if (delta === 0) delta = event.pixelDelta.x
      if (delta === 0) return
      root.switchRelative(delta > 0 ? 1 : -1)
      event.accepted = true
    }
  }

  implicitWidth: root.vertical ? root.barSize : Math.max(root.barSize, chipGrid.implicitWidth)
  implicitHeight: root.vertical ? Math.max(root.barSize, chipGrid.implicitHeight) : root.barSize

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    z: 0
    onClicked: root.toggle()
  }

  GridLayout {
    id: chipGrid
    z: 1
    anchors.centerIn: parent
    columns: root.vertical ? 1 : Math.max(1, root.shownEntries.length)
    columnSpacing: root.vertical ? 0 : Style.space(2)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      id: chipRepeater
      model: root.shownEntries

      Item {
        id: chip
        required property var modelData
        required property int index

        readonly property var layout: Model.chipLayout({
          vertical: root.vertical,
          inner: root.inner,
          fontPx: Model.effectivePx(modelData ? modelData.fontPx : 0),
          showNumber: !!(modelData && modelData.showNumber)
        })

        Layout.alignment: Qt.AlignCenter
        Layout.preferredWidth: layout.width
        Layout.preferredHeight: layout.height
        implicitWidth: layout.width
        implicitHeight: layout.height

        Rectangle {
          anchors.fill: parent
          radius: Math.max(4, Math.round(Math.min(width, height) * 0.45))
          color: {
            if (chipMouse.containsMouse && !(modelData && modelData.selected))
              return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
            if (modelData && modelData.selected)
              return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
            return "transparent"
          }
          border.width: (modelData && modelData.selected) || chipMouse.containsMouse ? 1 : 0
          border.color: Color.accent
        }

        Item {
          id: pair
          anchors.centerIn: parent
          readonly property bool stacked: chip.layout.stack
          width: stacked
            ? Math.max(iconBox.width, numberBox.width)
            : iconBox.width + ((modelData && modelData.showNumber) ? chip.layout.gap + numberBox.width : 0)
          height: stacked
            ? iconBox.height + ((modelData && modelData.showNumber) ? chip.layout.gap + numberBox.height : 0)
            : Math.max(iconBox.height, numberBox.height)

          Item {
            id: iconBox
            width: chip.layout.icon
            height: chip.layout.icon
            x: pair.stacked ? (pair.width - width) / 2 : 0
            y: pair.stacked ? 0 : (pair.height - height) / 2
            Text {
              anchors.centerIn: parent
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              textFormat: Text.PlainText
              text: modelData ? modelData.label : ""
              color: "#ffffff"
              font.family: (modelData && modelData.font) ? modelData.font : root.fontFamily
              font.pixelSize: chip.layout.icon
              font.bold: false
            }
          }

          Item {
            id: numberBox
            visible: !!(modelData && modelData.showNumber)
            width: chip.layout.numberW
            height: Math.max(chip.layout.number, 1)
            x: pair.stacked ? (pair.width - width) / 2 : chip.layout.icon + chip.layout.gap
            y: pair.stacked ? chip.layout.icon + chip.layout.gap : (pair.height - height) / 2
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: modelData ? modelData.number : ""
              color: chipMouse.containsMouse ? Color.accent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Math.max(chip.layout.number, 1)
              font.bold: true
            }
          }
        }

        HoverHandler {
          onHoveredChanged: {
            if (!hovered || !root.bar || root.opened) return
            root.bar.showTooltip(root, root.chipTip(modelData))
          }
        }

        MouseArea {
          id: chipMouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
              root.hideTips()
              root.toggle()
            } else root.activate(modelData)
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(panel.availableCardWidth >= 760 ? 920 : 480)
    contentHeight: panel.fittedContentHeight(settingsColumn.implicitHeight, 760)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editKey !== "" || root.fontMenuOpen
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onDeleteRequested: root.removeNavRow()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: settingsFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        ColumnLayout {
          id: settingsColumn
          width: settingsFlick.width
          spacing: Style.space(12)

          Text {
            textFormat: Text.PlainText
            text: "Workspaces"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            Layout.fillWidth: true
          }

          Text {
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "Saved with this widget. Specials stay in front of the numbered workspaces. Order inside each group is the order on the bar. A top or bottom bar reads it left to right, and a side bar reads it top to bottom. Occupied workspaces outside the list still appear after the numbered pills."
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }

          Rectangle {
            id: toggleCard
            Layout.fillWidth: true
            implicitHeight: toggleRow.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.cardFill
            border.width: 1
            border.color: root.navZone === "toggle" ? Color.accent : root.cardEdge

            RowLayout {
              id: toggleRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                  textFormat: Text.PlainText
                  text: "Show only active workspace"
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: "Hide empty numbered pills"
                  color: root.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              Rectangle {
                Layout.preferredWidth: Style.space(22)
                Layout.preferredHeight: Style.space(22)
                radius: Style.space(4)
                color: root.showOnlyActive ? "#3ddc97" : "transparent"
                border.width: 1
                border.color: root.showOnlyActive ? "#3ddc97" : Color.urgent
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: root.showOnlyActive ? "✓" : "✕"
                  color: root.showOnlyActive ? "#101315" : Color.urgent
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.navZone = "toggle"
                root.setShowOnly(!root.showOnlyActive)
              }
            }
          }

          Rectangle {
            id: countCard
            Layout.fillWidth: true
            implicitHeight: countCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.cardFill
            border.width: 1
            border.color: root.navZone === "count" ? Color.accent : root.cardEdge

            ColumnLayout {
              id: countCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Default workspaces"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: "Numbered pills only. Specials stay in front."
                color: root.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)
                PanelSlider {
                  Layout.fillWidth: true
                  bar: root.bar
                  integer: true
                  minimum: 1
                  maximum: 10
                  step: 1
                  value: Math.max(1, Model.numberedCount(root.draftRows))
                  fillColor: Color.accent
                  knobColor: "#ffffff"
                  trackColor: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.18)
                  onMoved: function(value) {
                    root.navZone = "count"
                    root.setDraftCount(value)
                  }
                  onReleased: function(value) { root.setDraftCount(value) }
                }
                MiniButton {
                  text: "‹"
                  onClicked: {
                    root.navZone = "count"
                    root.setDraftCount(Model.numberedCount(root.draftRows) - 1)
                  }
                }
                MiniButton {
                  text: "›"
                  onClicked: {
                    root.navZone = "count"
                    root.setDraftCount(Model.numberedCount(root.draftRows) + 1)
                  }
                }
                Rectangle {
                  Layout.preferredWidth: Style.space(36)
                  Layout.preferredHeight: Style.space(28)
                  radius: Style.cornerRadius
                  color: Qt.rgba(1, 1, 1, 0.06)
                  border.width: 1
                  border.color: root.cardEdge
                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: String(Math.max(1, Model.numberedCount(root.draftRows)))
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "Set special turns a numbered row into a special and moves it in front. Name is the label in this list. Workspace is the Hyprland special name. A different name opens an empty special. Windows stay on their current workspace. × removes the row. The last numbered workspace stays. The font and size change the icon only. The bar keeps its current look until Apply."
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }

          GridLayout {
            id: rowGrid
            Layout.fillWidth: true
            columns: root.twoColumns ? 2 : 1
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)

            Repeater {
              id: rowRepeater
              model: root.draftRows

              Rectangle {
                id: card
                required property var modelData
                required property int index
                property alias labelField: labelField
                property alias titleField: titleField
                property alias workspaceField: workspaceField
                property alias fontDrop: fontDrop

                readonly property bool special: modelData.kind === "special"
                readonly property bool marked: special || (root.navZone === "row" && root.navIndex === index)

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: cardCol.implicitHeight + Style.space(16)
                radius: Style.cornerRadius
                color: root.cardFill
                border.width: 1
                border.color: marked ? Color.accent : root.cardEdge

                ColumnLayout {
                  id: cardCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    Text {
                      visible: !card.special
                      textFormat: Text.PlainText
                      text: String(modelData.id)
                      color: Color.popups.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                      Layout.preferredWidth: Style.space(22)
                      Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                      id: titleField
                      visible: card.special
                      activeFocusOnTab: card.special
                      text: modelData.title
                      placeholderText: "Name"
                      hasCursor: root.rowHot(index, "title")
                      Layout.preferredWidth: Style.space(120)
                      Layout.alignment: Qt.AlignVCenter
                      font.pixelSize: Style.font.body
                      onActiveFocusChanged: {
                        if (root.fieldLock) return
                        if (activeFocus) {
                          root.navZone = "row"
                          root.navIndex = index
                          root.navAction = "title"
                          root.editKey = index + ":title"
                          return
                        }
                        if (root.editKey !== index + ":title") return
                        root.commitField(index, "title", text, false)
                      }
                      Keys.onEscapePressed: function(event) {
                        root.cancelEdit(titleField, modelData.title)
                        event.accepted = true
                      }
                      Keys.onReturnPressed: function(event) {
                        root.commitField(index, "title", text, true)
                        event.accepted = true
                      }
                      Keys.onEnterPressed: function(event) {
                        root.commitField(index, "title", text, true)
                        event.accepted = true
                      }
                    }

                    TextField {
                      id: labelField
                      text: modelData.label
                      hasCursor: root.rowHot(index, "label")
                      horizontalAlignment: Text.AlignHCenter
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      color: "#ffffff"
                      font.family: modelData.font ? modelData.font : root.fontFamily
                      font.pixelSize: Model.effectivePx(modelData.fontPx)
                      font.bold: false
                      onActiveFocusChanged: {
                        if (root.fieldLock) return
                        if (activeFocus) {
                          root.navZone = "row"
                          root.navIndex = index
                          root.navAction = "label"
                          root.editKey = index + ":label"
                          return
                        }
                        if (root.editKey !== index + ":label") return
                        root.commitField(index, "label", text, false)
                      }
                      Keys.onEscapePressed: function(event) {
                        root.cancelEdit(labelField, modelData.label)
                        event.accepted = true
                      }
                      Keys.onReturnPressed: function(event) {
                        root.commitField(index, "label", text, true)
                        event.accepted = true
                      }
                      Keys.onEnterPressed: function(event) {
                        root.commitField(index, "label", text, true)
                        event.accepted = true
                      }
                    }

                    MiniButton {
                      text: "↑"
                      hasCursor: root.rowHot(index, "up")
                      opacity: Model.canMove(root.draftRows, index, -1) ? 1 : 0.35
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "up"
                        root.activateCursor()
                      }
                    }
                    MiniButton {
                      text: "↓"
                      hasCursor: root.rowHot(index, "down")
                      opacity: Model.canMove(root.draftRows, index, 1) ? 1 : 0.35
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "down"
                        root.activateCursor()
                      }
                    }
                    MiniButton {
                      text: card.special ? "Special" : "Set special"
                      hasCursor: root.rowHot(index, "special")
                      opacity: Model.canSetSpecial(root.draftRows, index) ? 1 : 0.35
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "special"
                        root.activateCursor()
                      }
                    }
                    MiniButton {
                      text: "✕"
                      danger: true
                      hasCursor: root.rowHot(index, "remove")
                      opacity: Model.canRemove(root.draftRows, index) ? 1 : 0.35
                      background: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.14)
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "remove"
                        root.activateCursor()
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    SearchableDropdown {
                      id: fontDrop
                      property bool sawFontPopup: false
                      showLabel: false
                      value: modelData.font || ""
                      options: root.fontOptions
                      hasCursor: root.rowHot(index, "font")
                      placeholderText: "Search fonts..."
                      Layout.fillWidth: true
                      Layout.minimumWidth: Style.space(120)
                      onChanged: function(value) {
                        var picked = value
                        var row = index
                        root.fontMenuOpen = false
                        root.navZone = "row"
                        root.navIndex = row
                        root.navAction = "font"
                        Qt.callLater(function() {
                          root.commitDraft(Model.setFace(root.draftRows, row, null, picked, null))
                          if (root.opened && !root.editKey) keyCatcher.forceActiveFocus()
                        })
                      }
                      onPopupOpenChanged: {
                        if (popupOpen) {
                          sawFontPopup = true
                          root.fontMenuOpen = true
                          return
                        }
                        if (!sawFontPopup) return
                        sawFontPopup = false
                        root.fontMenuOpen = false
                        if (root.opened) {
                          Qt.callLater(function() {
                            if (root.opened && !root.editKey) keyCatcher.forceActiveFocus()
                          })
                        }
                      }
                    }

                    MiniButton {
                      text: "‹"
                      hasCursor: root.rowHot(index, "fontPrev")
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "fontPrev"
                        root.activateCursor()
                      }
                    }
                    MiniButton {
                      text: "›"
                      hasCursor: root.rowHot(index, "fontNext")
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "fontNext"
                        root.activateCursor()
                      }
                    }
                    MiniButton {
                      text: "−"
                      hasCursor: root.rowHot(index, "sizeDown")
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "sizeDown"
                        root.activateCursor()
                      }
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: String(Model.effectivePx(modelData.fontPx))
                      color: Color.popups.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      horizontalAlignment: Text.AlignHCenter
                      Layout.preferredWidth: Style.space(24)
                      Layout.alignment: Qt.AlignVCenter
                    }
                    MiniButton {
                      text: "+"
                      hasCursor: root.rowHot(index, "sizeUp")
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "sizeUp"
                        root.activateCursor()
                      }
                    }
                  }

                  RowLayout {
                    visible: card.special
                    Layout.fillWidth: true
                    spacing: Style.space(6)
                    Text {
                      textFormat: Text.PlainText
                      text: "Workspace"
                      color: root.muted
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      Layout.alignment: Qt.AlignVCenter
                    }
                    TextField {
                      id: workspaceField
                      visible: card.special
                      activeFocusOnTab: card.special
                      text: modelData.specialName
                      placeholderText: "Hyprland name"
                      hasCursor: root.rowHot(index, "workspace")
                      Layout.fillWidth: true
                      font.pixelSize: Style.font.body
                      onActiveFocusChanged: {
                        if (root.fieldLock) return
                        if (activeFocus) {
                          root.navZone = "row"
                          root.navIndex = index
                          root.navAction = "workspace"
                          root.editKey = index + ":workspace"
                          return
                        }
                        if (root.editKey !== index + ":workspace") return
                        root.commitField(index, "workspace", text, false)
                      }
                      Keys.onEscapePressed: function(event) {
                        root.cancelEdit(workspaceField, modelData.specialName)
                        event.accepted = true
                      }
                      Keys.onReturnPressed: function(event) {
                        root.commitField(index, "workspace", text, true)
                        event.accepted = true
                      }
                      Keys.onEnterPressed: function(event) {
                        root.commitField(index, "workspace", text, true)
                        event.accepted = true
                      }
                    }
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "Arrows follow the list. Enter activates or edits a field. Esc leaves a field, then closes the panel. x removes the selected row. Left and right change the workspace count."
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            Layout.fillWidth: true
          }

          RowLayout {
            id: footerRow
            Layout.fillWidth: true
            spacing: Style.space(8)
            Item { Layout.fillWidth: true }
            MiniButton {
              text: "Add workspace"
              hasCursor: root.navZone === "footer" && root.navFooter === 0
              opacity: Model.numberedCount(root.draftRows) < 10 ? 1 : 0.35
              onClicked: {
                root.navZone = "footer"
                root.navFooter = 0
                root.addWorkspace()
              }
            }
            MiniButton {
              text: "Apply"
              hasCursor: root.navZone === "footer" && root.navFooter === 1
              opacity: root.draftDirty() ? 1 : 0.35
              onClicked: {
                root.navZone = "footer"
                root.navFooter = 1
                root.applyDraft()
              }
            }
            MiniButton {
              text: "Undo"
              hasCursor: root.navZone === "footer" && root.navFooter === 2
              opacity: root.draftDirty() || root.undoSlots ? 1 : 0.35
              onClicked: {
                root.navZone = "footer"
                root.navFooter = 2
                root.undoDraft()
              }
            }
            MiniButton {
              text: "Refresh"
              hasCursor: root.navZone === "footer" && root.navFooter === 3
              onClicked: {
                root.navZone = "footer"
                root.navFooter = 3
                root.refreshPanel()
              }
            }
          }
        }
      }
    }
  }
}
