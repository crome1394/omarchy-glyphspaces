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
// workspaces. A pill can show a symbol, a text label, or both. On a side
// bar the words read downward. The focused chip uses a square outline.
// Right-click opens settings.
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
  property bool respectTheme: false
  property bool showNumbers: true
  property int workspaceGap: -1
  property int focusPolls: 0
  property bool seededDefaults: false
  property bool sidecarReady: false
  property bool sidecarHadSlots: false
  property bool sidecarShowOnly: true
  property bool sidecarRespect: false
  property bool sidecarShowNumbers: true
  property int sidecarGap: -1
  property var sidecarSlots: []
  property string sidecarBody: ""
  property int sidecarEpoch: 0
  property string sidecarDir: ""
  property string sidecarPath: ""
  property string transferKind: ""
  property var emojiList: []

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
        root.sidecarRespect = Model.truthy(parsed.respectTheme)
        if (parsed.showNumbers === undefined || parsed.showNumbers === null)
          root.sidecarShowNumbers = true
        else
          root.sidecarShowNumbers = Model.truthy(parsed.showNumbers)
        root.sidecarGap = Model.gapSetting(parsed.workspaceGap)
        root.sidecarBody = JSON.stringify({
          showOnlyActive: root.sidecarShowOnly,
          respectTheme: root.sidecarRespect,
          showNumbers: root.sidecarShowNumbers,
          workspaceGap: root.sidecarGap,
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
      respectTheme: !!root.respectTheme,
      showNumbers: !!root.showNumbers,
      workspaceGap: root.workspaceGap,
      slots: clean
    })
    if (body === root.sidecarBody) return
    root.sidecarBody = body
    sidecarFile.setText(body + "\n")
  }

  function emojiCatalogPath() {
    var base = ""
    try { base = String(Quickshell.env("OMARCHY_PATH") || "") } catch (e) { base = "" }
    if (!base) base = "/usr/share/omarchy"
    return base + "/shell/plugins/emojis/emojis.json"
  }

  function finishEmojiCatalog(raw) {
    var parsed = null
    try { parsed = JSON.parse(String(raw || "")) } catch (e) { parsed = null }
    root.emojiList = (parsed && typeof parsed.length === "number") ? parsed : []
    var panel = panelLoader.item
    if (panel && panel.emojiMenuOpen && panel.refreshEmoji) panel.refreshEmoji()
  }

  function notifyTransfer(note) {
    if (panelLoader.item) panelLoader.item.transferNote = note
  }

  function transferPath(path) {
    var text = String(path || "")
    if (!text || text.charAt(0) !== "/") return ""
    if (text.indexOf("\0") >= 0) return ""
    if (root.sidecarPath && text === root.sidecarPath) return ""
    if (text.length >= 10 && text.substring(text.length - 10) === "/shell.json") return ""
    return text
  }

  function writeExport(path, text) {
    var dest = root.transferPath(path)
    if (!dest) {
      root.notifyTransfer("Could not write that file.")
      return
    }
    root.transferKind = "export"
    transferFile.blockLoading = true
    transferFile.path = dest
    transferFile.setText(String(text || ""))
  }

  function readImport(path) {
    var dest = root.transferPath(path)
    if (!dest) {
      root.notifyTransfer("Could not read that file.")
      return
    }
    root.transferKind = "import"
    transferFile.blockLoading = false
    if (transferFile.path === dest) transferFile.reload()
    else transferFile.path = dest
  }

  function finishTransferLoad(raw) {
    if (root.transferKind !== "import") return
    root.transferKind = ""
    transferFile.blockLoading = true
    if (panelLoader.item && panelLoader.item.applyImportText)
      panelLoader.item.applyImportText(raw)
  }

  function finishTransferLoadFail() {
    if (root.transferKind !== "import") return
    root.transferKind = ""
    transferFile.blockLoading = true
    root.notifyTransfer("Could not read that file.")
  }

  function finishTransferSave() {
    if (root.transferKind !== "export") return
    root.transferKind = ""
    root.notifyTransfer("Exported.")
  }

  function finishTransferSaveFail() {
    if (root.transferKind !== "export") return
    root.transferKind = ""
    transferFile.blockLoading = true
    root.notifyTransfer("Could not write that file.")
  }

  function refreshFromPanel() {
    root.requestSpecialSync()
    try { Hyprland.refreshWorkspaces() } catch (e) {}
    root.rebuild()
  }

  function ingestBarSettings() {
    var show = Model.truthy(root.setting("showOnlyActive", true))
    if (show !== root.showOnlyActive) root.showOnlyActive = show
    var theme = Model.truthy(root.setting("respectTheme", false))
    if (theme !== root.respectTheme) root.respectTheme = theme
    var numbers = root.setting("showNumbers", true)
    var showNums = numbers === undefined || numbers === null ? true : Model.truthy(numbers)
    if (showNums !== root.showNumbers) root.showNumbers = showNums
    var gap = Model.gapSetting(root.setting("workspaceGap", -1))
    if (gap !== root.workspaceGap) root.workspaceGap = gap
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

  function workspaceIds() {
    var ids = []
    var seen = {}
    try {
      var values = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : []
      for (var i = 0; i < values.length; i++) {
        var id = values[i] ? Math.round(Number(values[i].id)) : 0
        if (!(id >= 1) || seen[id]) continue
        seen[id] = true
        ids.push(id)
      }
    } catch (e) {}
    return ids
  }

  // steps are hl.dsp.workspace.change_id pairs. slots are the rows to save
  // after those renames, so the pill number matches the workspace.
  function applyWorkspaceOrder(steps, slots, showOnly) {
    var list = steps || []
    var commands = []
    var focused = root.focusedId()
    var focusTo = Model.mapThrough(list, focused)
    for (var i = 0; i < list.length; i++) {
      var step = list[i]
      if (!step) continue
      var from = Math.round(Number(step.from))
      var to = Math.round(Number(step.to))
      if (!(from >= 1) || !(to >= 1) || from === to) continue
      commands.push("hl.dsp.workspace.change_id({ workspace = " + from + ", id = " + to + " })")
    }
    if (focusTo >= 1 && focusTo !== focused) commands.push(Model.focusDispatch(String(focusTo)))
    if (commands.length) root.dispatchAll(commands)
    root.persistSettings(!!showOnly, slots)
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

  function chosenFamily(entry) {
    return (entry && entry.font) ? entry.font : root.fontFamily
  }

  function chipFace(hot, selected, shortSide) {
    return Model.chipChrome({
      respectTheme: root.respectTheme,
      hot: !!hot,
      selected: !!selected,
      shortSide: shortSide,
      squareRadius: 2,
      cornerRadius: Style.cornerRadius,
      hoverBorder: Style.hoverBorderWidth,
      focusBorder: Style.focusBorderWidth,
      selectedBorder: Style.selectedBorderWidth,
      gap: root.workspaceGap >= 0 ? root.workspaceGap : Style.spacing.xxs
    })
  }

  function chipTip(entry) {
    var base = "Right-click for workspace settings"
    if (!entry) return base
    if (entry.isSpecial && entry.title && entry.caption)
      return entry.title + " · " + entry.caption + " · " + base
    if (entry.isSpecial && entry.title) return entry.title + " · " + base
    if (entry.caption) return entry.caption + " · " + base
    return base
  }

  function persistSettings(showOnly, slots) {
    var clean = Model.sanitize(slots)
    var entry = {
      id: root.moduleName,
      showOnlyActive: !!showOnly,
      respectTheme: !!root.respectTheme,
      showNumbers: !!root.showNumbers,
      workspaceGap: root.workspaceGap,
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
      root.respectTheme = Model.truthy(root.setting("respectTheme", false))
      root.showNumbers = Model.truthy(root.setting("showNumbers", true))
      root.workspaceGap = Model.gapSetting(root.setting("workspaceGap", -1))
      var kept = Model.mergeKeptText(root.savedRows(), root.sidecarSlots)
      if (kept) {
        root.persistSettings(Model.truthy(root.setting("showOnlyActive", true)), kept)
        return
      }
      root.writeSidecar(Model.truthy(root.setting("showOnlyActive", true)), root.savedRows())
      return
    }
    root.seededDefaults = true
    if (root.sidecarHadSlots) {
      root.respectTheme = root.sidecarRespect
      root.showNumbers = root.sidecarShowNumbers
      root.workspaceGap = root.sidecarGap
      root.persistSettings(root.sidecarShowOnly, root.sidecarSlots)
    } else
      root.persistSettings(Model.truthy(root.setting("showOnlyActive", true)), Model.defaultSlots())
  }

  function setShowOnly(on) {
    var next = !!on
    if (next === root.showOnlyActive) return
    root.persistSettings(next, root.savedRows())
  }

  function setRespectTheme(on) {
    var next = !!on
    if (next === root.respectTheme) return
    root.respectTheme = next
    root.persistSettings(root.showOnlyActive, root.savedRows())
  }

  function setShowNumbers(on) {
    var next = !!on
    if (next === root.showNumbers) return
    root.showNumbers = next
    root.persistSettings(root.showOnlyActive, root.savedRows())
  }

  function setWorkspaceGap(px) {
    var next = Model.gapSetting(px)
    if (next === root.workspaceGap) return
    root.workspaceGap = next
    root.persistSettings(root.showOnlyActive, root.savedRows())
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
    root.respectTheme = Model.truthy(root.setting("respectTheme", false))
    root.showNumbers = Model.truthy(root.setting("showNumbers", true))
    root.workspaceGap = Model.gapSetting(root.setting("workspaceGap", -1))
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

  // Import and export use a separate file so they never touch the sidecar.
  FileView {
    id: transferFile
    watchChanges: false
    atomicWrites: true
    printErrors: false
    blockLoading: true
    onLoaded: root.finishTransferLoad(text())
    onLoadFailed: root.finishTransferLoadFail()
    onSaved: root.finishTransferSave()
    onSaveFailed: root.finishTransferSaveFail()
  }

  // Read-only catalog from the Omarchy emoji picker. The symbol field stays
  // the thing that gets the choice.
  FileView {
    id: emojiFile
    watchChanges: false
    printErrors: false
    path: root.emojiCatalogPath()
    onLoaded: root.finishEmojiCatalog(text())
    onLoadFailed: root.finishEmojiCatalog("")
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
    function setRespectTheme(value: string): string {
      root.setRespectTheme(Model.truthy(value))
      return root.respectTheme ? "on" : "off"
    }
    function toggleRespectTheme(): string {
      root.setRespectTheme(!root.respectTheme)
      return root.respectTheme ? "on" : "off"
    }
    function setShowNumbers(value: string): string {
      root.setShowNumbers(Model.truthy(value))
      return root.showNumbers ? "on" : "off"
    }
    function toggleShowNumbers(): string {
      root.setShowNumbers(!root.showNumbers)
      return root.showNumbers ? "on" : "off"
    }
    function setWorkspaceGap(value: string): string {
      root.setWorkspaceGap(value)
      return String(root.workspaceGap)
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

  readonly property int chipGap: chipFace(false, false, Math.max(1, root.inner)).gap
  readonly property int chipInset: chipFace(true, true, Math.max(1, root.inner)).inset

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
    columnSpacing: root.vertical ? 0 : root.chipGap
    rowSpacing: root.vertical ? root.chipGap : 0

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
          showNumber: root.showNumbers && !!(modelData && modelData.showNumber),
          label: modelData ? modelData.label : "",
          caption: modelData ? modelData.caption : ""
        })
        readonly property bool labeled: !!(modelData && modelData.caption)
        readonly property bool showIcon: labeled && !!(modelData && modelData.label)
        readonly property bool showNumber: root.showNumbers && !!(modelData && modelData.showNumber)
        readonly property bool stackMark: labeled && !!layout.stack && showIcon && showNumber
        readonly property int faceGap: layout.gap > 0 ? layout.gap : 2
        readonly property int numberGap: {
          if (!showNumber || !labeled) return faceGap
          var measured = Math.ceil(spaceMetric.implicitWidth)
          var floor = layout.numberGap > 0 ? layout.numberGap : faceGap
          return Math.max(faceGap, floor, measured)
        }
        readonly property string customColor: (!root.respectTheme && modelData && modelData.color) ? String(modelData.color) : ""
        readonly property bool faceBold: !!(modelData && modelData.bold)
        readonly property bool faceItalic: !!(modelData && modelData.italic)
        readonly property color faceInk: {
          if (!chipMouse.containsMouse) return root.foreground
          if (root.respectTheme)
            return Style.hoverStateColor(root.foreground, Color.accent, Color.urgent)
          return Color.accent
        }
        readonly property color captionInk: customColor ? customColor : faceInk
        readonly property color symbolInk: {
          if (root.respectTheme) return root.foreground
          if (customColor) return customColor
          return "#ffffff"
        }
        readonly property int boxExtra: root.chipInset * 2
        readonly property int boxWidth: {
          var base = (labeled ? labeledWidth : layout.width) + boxExtra
          return root.vertical ? Math.min(root.barSize, base) : base
        }
        readonly property int boxHeight: {
          var base = (labeled ? labeledHeight : layout.height) + boxExtra
          return root.vertical ? base : Math.min(root.barSize, base)
        }
        readonly property int markWidth: {
          if (!labeled || (!showIcon && !showNumber)) return 0
          if (stackMark) return Math.max(iconMetric.implicitWidth, numberMetric.implicitWidth)
          var w = 0
          var n = 0
          if (showIcon) { w += iconMetric.implicitWidth; n++ }
          if (showNumber) { w += numberMetric.implicitWidth; n++ }
          if (n > 1) w += faceGap
          return w
        }
        readonly property int markHeight: {
          if (!labeled || (!showIcon && !showNumber)) return 0
          if (stackMark) return iconMetric.implicitHeight + faceGap + numberMetric.implicitHeight
          return Math.max(showIcon ? iconMetric.implicitHeight : 0, showNumber ? numberMetric.implicitHeight : 0)
        }
        readonly property int captionCross: Math.ceil(Math.max(captionMetric.implicitHeight, layout.caption))
        readonly property int captionAlong: Math.ceil(captionMetric.implicitWidth + 2)
        readonly property int labeledWidth: {
          if (!labeled) return layout.width
          if (root.vertical) return root.inner
          var w = captionMetric.implicitWidth
          if (showIcon) w += iconMetric.implicitWidth + faceGap
          if (showNumber) w += numberGap + numberMetric.implicitWidth
          return Math.ceil(w + 4)
        }
        readonly property int labeledHeight: {
          if (!labeled) return layout.height
          if (!root.vertical) return root.inner
          var h = captionAlong
          if (markHeight > 0) h += faceGap + markHeight
          return Math.ceil(h + 4)
        }

        Layout.alignment: Qt.AlignCenter
        Layout.preferredWidth: boxWidth
        Layout.preferredHeight: boxHeight
        implicitWidth: boxWidth
        implicitHeight: boxHeight

        Rectangle {
          anchors.fill: parent
          readonly property var chrome: root.chipFace(
            chipMouse.containsMouse,
            !!(modelData && modelData.selected),
            Math.max(1, Math.min(width, height))
          )
          radius: chrome.radius
          color: {
            var on = !!(modelData && modelData.selected)
            var hot = chipMouse.containsMouse && !on
            if (root.respectTheme) {
              if (hot) return Style.hoverFill
              if (on) return Style.selectedFill
              return "transparent"
            }
            if (hot)
              return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
            if (on)
              return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
            return "transparent"
          }
          border.width: chrome.border
          border.color: root.respectTheme
            ? ((modelData && modelData.selected) ? Style.selectedBorderColor : Style.hoverBorderColor)
            : Color.accent
        }

        Text {
          id: iconMetric
          visible: false
          textFormat: Text.PlainText
          text: (modelData && modelData.label) ? modelData.label : ""
          font.family: root.chosenFamily(modelData)
          font.pixelSize: Math.max(chip.layout.icon, 1)
          font.bold: chip.faceBold
          font.italic: chip.faceItalic
        }
        Text {
          id: captionMetric
          visible: false
          textFormat: Text.PlainText
          wrapMode: Text.NoWrap
          text: (modelData && modelData.caption) ? modelData.caption : ""
          font.family: root.chosenFamily(modelData)
          font.pixelSize: Math.max(chip.layout.caption, 1)
          font.bold: chip.faceBold
          font.italic: chip.faceItalic
        }
        Text {
          id: numberMetric
          visible: false
          textFormat: Text.PlainText
          text: (modelData && modelData.number) ? modelData.number : ""
          font.family: root.fontFamily
          font.pixelSize: Math.max(chip.layout.number, 1)
          font.bold: true
        }
        Text {
          id: spaceMetric
          visible: false
          textFormat: Text.PlainText
          text: " "
          font.family: root.chosenFamily(modelData)
          font.pixelSize: Math.max(chip.layout.caption || chip.layout.icon, 1)
          font.bold: chip.faceBold
          font.italic: chip.faceItalic
        }

        Item {
          id: pair
          visible: !chip.labeled
          anchors.centerIn: parent
          readonly property bool stacked: chip.layout.stack
          width: stacked
            ? Math.max(iconBox.width, numberBox.width)
            : iconBox.width + (chip.showNumber ? chip.layout.gap + numberBox.width : 0)
          height: stacked
            ? iconBox.height + (chip.showNumber ? chip.layout.gap + numberBox.height : 0)
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
              color: chip.symbolInk
              font.family: root.chosenFamily(modelData)
              font.pixelSize: chip.layout.icon
              font.bold: chip.faceBold
              font.italic: chip.faceItalic
            }
          }

          Item {
            id: numberBox
            visible: chip.showNumber
            width: chip.layout.numberW
            height: Math.max(chip.layout.number, 1)
            x: pair.stacked ? (pair.width - width) / 2 : chip.layout.icon + chip.layout.gap
            y: pair.stacked ? chip.layout.icon + chip.layout.gap : (pair.height - height) / 2
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: modelData ? modelData.number : ""
              color: chip.faceInk
              font.family: root.fontFamily
              font.pixelSize: Math.max(chip.layout.number, 1)
              font.bold: true
            }
          }
        }

        Item {
          id: hFace
          visible: chip.labeled && !root.vertical
          width: Math.max(1, chip.labeledWidth - 4)
          height: Math.max(iconMetric.implicitHeight, captionMetric.implicitHeight, numberMetric.implicitHeight)
          x: Math.round((parent.width - width) / 2)
          y: Math.round((parent.height - height) / 2)

          Text {
            visible: chip.showIcon
            x: 0
            y: (parent.height - implicitHeight) / 2
            textFormat: Text.PlainText
            text: modelData ? modelData.label : ""
            color: chip.symbolInk
            font.family: root.chosenFamily(modelData)
            font.pixelSize: Math.max(chip.layout.icon, 1)
            font.bold: chip.faceBold
            font.italic: chip.faceItalic
          }
          Text {
            id: hCaption
            x: chip.showIcon ? iconMetric.implicitWidth + chip.faceGap : 0
            y: (parent.height - implicitHeight) / 2
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            text: modelData ? modelData.caption : ""
            color: chip.captionInk
            font.family: root.chosenFamily(modelData)
            font.pixelSize: Math.max(chip.layout.caption, 1)
            font.bold: chip.faceBold
            font.italic: chip.faceItalic
          }
          Text {
            visible: chip.showNumber
            x: hCaption.x + captionMetric.implicitWidth + chip.numberGap
            y: (parent.height - implicitHeight) / 2
            textFormat: Text.PlainText
            text: modelData ? modelData.number : ""
            color: chip.faceInk
            font.family: root.fontFamily
            font.pixelSize: Math.max(chip.layout.number, 1)
            font.bold: true
          }
        }

        Item {
          id: vFace
          visible: chip.labeled && root.vertical
          width: Math.max(chip.markWidth, chip.captionCross)
          height: Math.max(1, chip.labeledHeight - 4)
          x: Math.round((parent.width - width) / 2)
          y: Math.round((parent.height - height) / 2)

          Text {
            id: vIcon
            visible: chip.showIcon
            x: {
              if (chip.stackMark || !chip.showNumber) return (parent.width - implicitWidth) / 2
              return (parent.width - chip.markWidth) / 2
            }
            y: chip.stackMark ? 0 : (chip.markHeight - implicitHeight) / 2
            textFormat: Text.PlainText
            text: modelData ? modelData.label : ""
            color: chip.symbolInk
            font.family: root.chosenFamily(modelData)
            font.pixelSize: Math.max(chip.layout.icon, 1)
            font.bold: chip.faceBold
            font.italic: chip.faceItalic
          }
          Text {
            id: vNumber
            visible: chip.showNumber
            x: {
              if (chip.stackMark || !chip.showIcon) return (parent.width - implicitWidth) / 2
              return vIcon.x + iconMetric.implicitWidth + chip.faceGap
            }
            y: chip.stackMark
              ? iconMetric.implicitHeight + chip.faceGap
              : (chip.markHeight - implicitHeight) / 2
            textFormat: Text.PlainText
            text: modelData ? modelData.number : ""
            color: chip.faceInk
            font.family: root.fontFamily
            font.pixelSize: Math.max(chip.layout.number, 1)
            font.bold: true
          }
          Item {
            width: chip.captionCross
            height: chip.captionAlong
            x: (parent.width - width) / 2
            y: chip.markHeight > 0 ? chip.markHeight + chip.faceGap : 0
            Text {
              anchors.centerIn: parent
              rotation: 90
              transformOrigin: Item.Center
              textFormat: Text.PlainText
              wrapMode: Text.NoWrap
              text: modelData ? modelData.caption : ""
              color: chip.captionInk
              font.family: root.chosenFamily(modelData)
              font.pixelSize: Math.max(chip.layout.caption, 1)
              font.bold: chip.faceBold
              font.italic: chip.faceItalic
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
