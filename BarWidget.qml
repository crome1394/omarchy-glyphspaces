import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as Model

// Omarchy GlyphSpaces. Colored workspace dots for the Omarchy bar.
//
// The manifest entry is this BarWidget. Settings live in Panel.qml, which
// the loader below creates. Specials stay in front of the numbered
// workspaces. The focused chip is a rounded pill. Right-click opens settings.
//
// open/close/toggle stay local. The IPC handler asks the shell to summon the
// copy on the focused monitor, and that path calls open() here.
BarWidget {
  id: root
  moduleName: "crome.workspaces"

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int inner: Math.max(12, barSize - 4)

  property var shownEntries: []
  property string activeSpecial: ""
  property bool showOnlyActive: true
  property int focusPolls: 0
  property bool seededDefaults: false
  property bool sidecarReady: false
  property bool sidecarHadSlots: false
  property bool sidecarShowOnly: true
  property var sidecarSlots: []
  property string sidecarBody: ""
  property int sidecarEpoch: 0
  property string sidecarDir: ""
  property string sidecarPath: ""

  // The bar slot is this item. Forward the panel lifecycle so summon, hide,
  // and the popout switch find open/close/opened here.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = root
    if ("hostWidget" in target) target.hostWidget = root
  }

  function armSidecar() {
    var fromEnv = Quickshell.env("XDG_STATE_HOME")
    var home = (fromEnv && String(fromEnv).length > 0) ? String(fromEnv) : (Quickshell.env("HOME") + "/.local/state")
    root.sidecarDir = home + "/omarchy"
    sidecarDirProc.command = ["mkdir", "-p", root.sidecarDir]
    sidecarDirProc.running = true
  }

  function finishSidecar(raw) {
    if (root.sidecarReady || root.sidecarEpoch < 1) return
    root.sidecarReady = true
    var parsed = null
    var text = String(raw || "")
    try {
      if (text.trim()) parsed = JSON.parse(text)
    } catch (e) {
      parsed = null
    }
    if (parsed && parsed.slots) {
      var clean = Model.sanitize(parsed.slots)
      if (clean.length > 0) {
        root.sidecarSlots = clean
        root.sidecarHadSlots = true
        if (parsed.showOnlyActive === undefined || parsed.showOnlyActive === null)
          root.sidecarShowOnly = true
        else
          root.sidecarShowOnly = Model.truthy(parsed.showOnlyActive)
        root.sidecarBody = JSON.stringify({
          showOnlyActive: root.sidecarShowOnly,
          slots: clean
        })
      }
    }
    root.ensureDefaultConfig()
  }

  function writeSidecar(showOnly, slots) {
    if (!root.sidecarReady) return
    var clean = Model.sanitize(slots)
    var body = JSON.stringify({
      showOnlyActive: !!showOnly,
      slots: clean
    })
    if (body === root.sidecarBody) return
    root.sidecarBody = body
    sidecarFile.setText(body + "\n")
  }

  function refreshFromPanel() {
    root.requestSpecialSync()
    try { Hyprland.refreshWorkspaces() } catch (e) {}
    root.rebuild()
  }

  function ingestBarSettings() {
    var show = Model.truthy(root.setting("showOnlyActive", true))
    if (show !== root.showOnlyActive) root.showOnlyActive = show
    root.rebuild()
    root.injectPanel()
  }

  function hideTips() {
    if (root.bar) root.bar.hideTooltip(root)
  }

  function savedRows() {
    return Model.rowsFromSettings(root.settings || {})
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
    root.showOnlyActive = !!showOnly
    root.settings = entry
    root.writeSidecar(!!showOnly, clean)
    if (root.bar && root.bar.shell && root.bar.shell.updateEntryInline)
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    root.rebuild()
  }

  // A fresh bar entry is only { id }. Slots already on the bar stay there.
  // With none, a saved row in the state file is written back. Otherwise the
  // eight emoji workspaces are written once.
  function entryHasSlots() {
    var slots = root.settings ? root.settings.slots : null
    return !!(slots && slots.length > 0)
  }

  function ensureDefaultConfig() {
    if (root.seededDefaults || !root.sidecarReady) return
    if (!root.bar || !root.bar.shell || !root.bar.shell.updateEntryInline) return
    if (root.entryHasSlots()) {
      root.seededDefaults = true
      root.writeSidecar(Model.truthy(root.setting("showOnlyActive", true)), root.savedRows())
      return
    }
    root.seededDefaults = true
    if (root.sidecarHadSlots)
      root.persistSettings(root.sidecarShowOnly, root.sidecarSlots)
    else
      root.persistSettings(Model.truthy(root.setting("showOnlyActive", true)), Model.defaultSlots())
  }

  function setShowOnly(on) {
    var next = !!on
    if (next === root.showOnlyActive) return
    root.persistSettings(next, root.savedRows())
  }

  // shell.summon/hide/toggle pick the bar on the focused monitor. Calling
  // open() here would only reach whichever copy registered the IPC target.
  function openOverIpc() {
    var shell = root.bar && root.bar.shell
    if (shell && shell.summon && shell.summon(root.moduleName, "")) return
    root.open()
  }

  function closeOverIpc() {
    var shell = root.bar && root.bar.shell
    if (shell && shell.hide && shell.hide(root.moduleName)) return
    root.close()
  }

  function toggleOverIpc() {
    var shell = root.bar && root.bar.shell
    if (shell && shell.toggle && shell.toggle(root.moduleName, "")) return
    root.toggle()
  }

  onBarChanged: {
    root.injectPanel()
    root.ensureDefaultConfig()
  }

  onSettingsChanged: root.ingestBarSettings()

  Component.onCompleted: {
    root.showOnlyActive = Model.truthy(root.setting("showOnlyActive", true))
    root.rebuild()
    root.requestSpecialSync()
    root.injectPanel()
    root.armSidecar()
  }

  Process {
    id: sidecarDirProc
    onExited: {
      root.sidecarEpoch = root.sidecarEpoch + 1
      // One assignment. A second reload drops the read that just started.
      root.sidecarPath = root.sidecarDir + "/crome.workspaces.json"
      sidecarFile.path = root.sidecarPath
    }
  }

  // The plugin directory is watched, so this copy lives under the state
  // directory. Disable drops the shell.json entry and leaves the file in
  // place. The next enable writes it back onto the bar.
  FileView {
    id: sidecarFile
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.finishSidecar(text())
    onLoadFailed: root.finishSidecar("")
  }

  IpcHandler {
    target: "crome.workspaces"

    function open(): void { root.openOverIpc() }
    function close(): void { root.closeOverIpc() }
    function show(): void { root.openOverIpc() }
    function hide(): void { root.closeOverIpc() }
    function toggle(): void { root.toggleOverIpc() }
    function setShowOnlyActive(value: string): string {
      root.setShowOnly(Model.truthy(value))
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

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }
}
