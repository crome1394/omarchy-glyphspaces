import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as Model

// Settings for Omarchy GlyphSpaces. BarWidget.qml loads this and anchors it
// to the bar slot. The shell routes summon and hide through the bar widget.
Panel {
  id: root
  moduleName: "crome.workspaces"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color muted: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.7)
  readonly property color cardFill: Qt.rgba(1, 1, 1, 0.04)
  readonly property color cardEdge: Qt.rgba(1, 1, 1, 0.08)
  property bool showOnlyActive: true
  property bool respectTheme: false
  property bool showNumbers: true
  property int workspaceGap: -1
  property string settingsPage: "workspaces"
  property int draftEpoch: 0
  property string savedSig: ""
  property var draftRows: []
  property var undoSlots: null
  property var undoSteps: []
  property var fontFamilies: []
  property var fontOptions: [{ value: "", label: "Bar font" }]
  property bool fontsLoaded: false
  property string navZone: "toggle"
  property int navIndex: 0
  property string navAction: "label"
  property int navFooter: 0
  property string editKey: ""
  property bool fieldLock: false
  property bool fontMenuOpen: false
  property int fontOpenIndex: -1
  property int fontOpenTick: 0
  property int colorRow: -1
  property int navTransfer: 0
  property bool dialogOpen: false
  property string transferNote: ""
  property bool emojiMenuOpen: false
  property int emojiRow: -1
  property string emojiQuery: ""
  property var emojiHits: []

  component MiniButton: Button {
    property bool danger: false
    focusable: false
    bordered: true
    fontSize: Style.font.bodySmall
    horizontalPadding: Style.space(8)
    verticalPadding: Style.space(4)
    foreground: danger ? Color.urgent : Color.popups.text
  }

  component SettingCheck: Rectangle {
    id: check
    property bool checked: false
    implicitWidth: Style.space(28)
    implicitHeight: Style.space(28)
    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.maximumWidth: implicitWidth
    Layout.maximumHeight: implicitHeight
    radius: Style.space(4)
    color: check.checked ? "#3ddc97" : "transparent"
    border.width: 1
    border.color: check.checked ? "#3ddc97" : Color.urgent
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: check.checked ? "✓" : "✕"
      color: check.checked ? "#101315" : Color.urgent
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  function savedRows() {
    if (root.hostWidget && root.hostWidget.savedRows) return root.hostWidget.savedRows()
    return Model.rowsFromSettings(root.settings || {})
  }

  function draftDirty() {
    return Model.signature(root.draftRows) !== Model.signature(root.savedRows())
  }

  function persistSettings(showOnly, slots) {
    if (root.hostWidget && root.hostWidget.persistSettings)
      root.hostWidget.persistSettings(showOnly, slots)
  }

  function setShowOnly(on) {
    if (root.hostWidget && root.hostWidget.setShowOnly) root.hostWidget.setShowOnly(on)
    root.pullShowOnly()
  }

  function setRespectTheme(on) {
    if (root.hostWidget && root.hostWidget.setRespectTheme) root.hostWidget.setRespectTheme(on)
    root.pullRespect()
  }

  function setShowNumbers(on) {
    if (root.hostWidget && root.hostWidget.setShowNumbers) root.hostWidget.setShowNumbers(on)
    root.pullShowNumbers()
  }

  function setWorkspaceGap(px) {
    if (root.hostWidget && root.hostWidget.setWorkspaceGap) root.hostWidget.setWorkspaceGap(px)
    root.pullGap()
  }

  function pullShowNumbers() {
    var next = true
    if (root.hostWidget) next = !!root.hostWidget.showNumbers
    else next = Model.truthy(root.setting("showNumbers", true))
    if (next !== root.showNumbers) root.showNumbers = next
  }

  function pullGap() {
    var next = -1
    if (root.hostWidget) next = Model.gapSetting(root.hostWidget.workspaceGap)
    else next = Model.gapSetting(root.setting("workspaceGap", -1))
    if (next !== root.workspaceGap) root.workspaceGap = next
  }

  function effectiveGap() {
    if (root.workspaceGap >= 0) return root.workspaceGap
    return Style.spacing.xxs
  }

  function stepGap(delta) {
    var current = root.workspaceGap >= 0 ? root.workspaceGap : root.effectiveGap()
    var next = Math.round(Number(current)) + (Math.round(Number(delta)) || 0)
    if (next < 0) next = 0
    if (next > 32) next = 32
    root.setWorkspaceGap(next)
  }

  function setPage(page) {
    root.settingsPage = page === "settings" ? "settings" : "workspaces"
    root.navZone = "tabs"
    root.revealNav()
  }

  function pullShowOnly() {
    var next = true
    if (root.hostWidget) next = !!root.hostWidget.showOnlyActive
    else next = Model.truthy(root.setting("showOnlyActive", true))
    if (next !== root.showOnlyActive) root.showOnlyActive = next
  }

  function pullRespect() {
    var next = false
    if (root.hostWidget) next = !!root.hostWidget.respectTheme
    else next = Model.truthy(root.setting("respectTheme", false))
    if (next !== root.respectTheme) root.respectTheme = next
  }

  function syncFields() {
    var rows = root.draftRows || []
    for (var i = 0; i < rows.length; i++) {
      var card = rowRepeater.itemAt(i)
      var slot = rows[i]
      if (!card || !slot) continue
      if (root.editKey !== i + ":label" && card.labelField)
        card.labelField.text = slot.label || ""
      if (root.editKey !== i + ":caption" && card.captionField)
        card.captionField.text = slot.caption || ""
      if (root.editKey !== i + ":title" && card.titleField)
        card.titleField.text = slot.title || ""
      if (root.editKey !== i + ":workspace" && card.workspaceField)
        card.workspaceField.text = slot.specialName || ""
      if (root.editKey !== i + ":order" && card.orderField)
        card.orderField.text = String(Model.orderIndex(rows, i) || "")
    }
  }

  function liveWorkspaceIds() {
    if (root.hostWidget && root.hostWidget.workspaceIds) return root.hostWidget.workspaceIds()
    return []
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function close() {
    root.finishEditing(false)
    root.hideTips()
    root.controller.hide()
  }

  function hideTips() {
    if (root.hostWidget && root.hostWidget.hideTips) root.hostWidget.hideTips()
    else if (root.bar) root.bar.hideTooltip(root.hostWidget || root)
  }

  function resetDraft() {
    root.editKey = ""
    root.draftRows = root.savedRows()
    root.clampNav()
    Qt.callLater(root.syncFields)
  }

  function commitDraft(rows) {
    var next = Model.sanitize(rows)
    if (Model.signature(next) === Model.signature(root.draftRows)) return
    root.editKey = ""
    root.fontMenuOpen = false
    root.emojiMenuOpen = false
    root.draftRows = next
    root.clampNav()
    Qt.callLater(root.syncFields)
  }

  function setDraftCount(count) {
    var n = Math.round(Number(count))
    if (!(n >= 1)) n = 1
    if (n > 10) n = 10
    if (n === Model.numberedCount(root.draftRows)) return
    root.commitDraft(Model.resizeNumbered(root.draftRows, n))
  }

  function applyDraft() {
    var plan = Model.commitOrder(root.draftRows, root.liveWorkspaceIds())
    var same = Model.signature(plan.slots) === Model.signature(root.savedRows())
    if (same && !plan.steps.length) return
    root.undoSlots = root.savedRows()
    root.undoSteps = plan.steps
    root.editKey = ""
    root.draftRows = plan.slots
    if (root.hostWidget && root.hostWidget.applyWorkspaceOrder)
      root.hostWidget.applyWorkspaceOrder(plan.steps, plan.slots, root.showOnlyActive)
    else
      root.persistSettings(root.showOnlyActive, plan.slots)
    Qt.callLater(root.syncFields)
  }

  function undoDraft() {
    if (root.draftDirty()) {
      root.resetDraft()
      return
    }
    if (!root.undoSlots) return
    var previous = root.undoSlots
    var steps = Model.invertSteps(root.undoSteps)
    root.undoSlots = root.savedRows()
    root.undoSteps = steps
    root.editKey = ""
    if (root.hostWidget && root.hostWidget.applyWorkspaceOrder)
      root.hostWidget.applyWorkspaceOrder(steps, previous, root.showOnlyActive)
    else
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

  function emojiSource() {
    var list = root.hostWidget && root.hostWidget.emojiList
    if (list && list.length) return list
    return Model.builtinEmoji()
  }

  function refreshEmoji() {
    root.emojiHits = Model.filterEmoji(root.emojiSource(), root.emojiQuery, 0)
  }

  function openEmoji(index) {
    if (root.emojiMenuOpen && root.emojiRow === index) {
      root.closeEmoji()
      return
    }
    root.emojiRow = index
    root.emojiQuery = ""
    root.emojiMenuOpen = true
    if (emojiSearch) emojiSearch.text = ""
    root.refreshEmoji()
    Qt.callLater(function() {
      if (root.emojiMenuOpen && emojiSearch) emojiSearch.forceActiveFocus()
    })
  }

  function closeEmoji() {
    root.emojiMenuOpen = false
    root.emojiRow = -1
    Qt.callLater(function() {
      if (root.opened && !root.editKey && !root.fontMenuOpen) keyCatcher.forceActiveFocus()
    })
  }

  function pickEmoji(symbol) {
    var index = root.emojiRow
    root.closeEmoji()
    if (!(index >= 0) || !symbol) return
    root.commitDraft(Model.setFace(root.draftRows, index, symbol, null, null))
  }

  function colorHex(c) {
    if (c === undefined || c === null) return ""
    if (typeof c === "string") return Model.clampColor(c)
    function byte(v) {
      var n = Math.round(Number(v) * 255)
      if (!(n >= 0)) n = 0
      if (n > 255) n = 255
      var h = n.toString(16)
      return h.length < 2 ? "0" + h : h
    }
    if (c.r === undefined) return Model.clampColor(String(c))
    return Model.clampColor("#" + byte(c.r) + byte(c.g) + byte(c.b))
  }

  function openTextColor(index) {
    if (root.respectTheme) return
    var slot = root.draftRows[index]
    if (!slot) return
    root.colorRow = index
    root.dialogOpen = true
    textColorDialog.selectedColor = slot.color || "#ffffff"
    textColorDialog.open()
  }

  function acceptTextColor() {
    root.dialogOpen = false
    var index = root.colorRow
    root.colorRow = -1
    var hex = root.colorHex(textColorDialog.selectedColor)
    if (index >= 0 && hex)
      root.commitDraft(Model.setFace(root.draftRows, index, null, null, null, null, null, null, hex))
    Qt.callLater(function() {
      if (root.opened && !root.editKey) keyCatcher.forceActiveFocus()
    })
  }

  function dismissDialog() {
    root.dialogOpen = false
    Qt.callLater(function() {
      if (root.opened && !root.editKey) keyCatcher.forceActiveFocus()
    })
  }

  function homeFolder() {
    var home = ""
    try { home = String(Quickshell.env("HOME") || "") } catch (e) { home = "" }
    if (!home || home.charAt(0) !== "/") home = "/tmp"
    return "file://" + encodeURI(home)
  }

  function filePath(url) {
    var text = String(url || "")
    if (!text || text === "undefined") return ""
    if (text.indexOf("file://") === 0) {
      var path = text.substring(7)
      try { path = decodeURIComponent(path) } catch (e) {}
      return path
    }
    if (text.charAt(0) === "/") return text
    return ""
  }

  function beginExport() {
    root.transferNote = ""
    root.dialogOpen = true
    var folder = root.homeFolder()
    exportDialog.currentFolder = folder
    exportDialog.currentFile = folder + "/glyphspaces.json"
    exportDialog.selectedFile = folder + "/glyphspaces.json"
    exportDialog.open()
  }

  function beginImport() {
    root.transferNote = ""
    root.dialogOpen = true
    importDialog.currentFolder = root.homeFolder()
    importDialog.open()
  }

  function finishExportDialog() {
    root.dialogOpen = false
    var path = root.filePath(exportDialog.selectedFile)
    var body = Model.exportText({
      showOnlyActive: root.showOnlyActive,
      respectTheme: root.respectTheme,
      showNumbers: root.showNumbers,
      workspaceGap: root.workspaceGap,
      slots: root.draftRows
    })
    if (root.hostWidget && root.hostWidget.writeExport) root.hostWidget.writeExport(path, body)
    else root.transferNote = "Could not write that file."
    Qt.callLater(function() {
      if (root.opened && !root.editKey) keyCatcher.forceActiveFocus()
    })
  }

  function finishImportDialog() {
    root.dialogOpen = false
    var path = root.filePath(importDialog.selectedFile)
    if (root.hostWidget && root.hostWidget.readImport) root.hostWidget.readImport(path)
    else root.transferNote = "Could not read that file."
    Qt.callLater(function() {
      if (root.opened && !root.editKey) keyCatcher.forceActiveFocus()
    })
  }

  function applyImportText(raw) {
    var parsed = Model.importSettings(raw)
    if (!parsed) {
      root.transferNote = "That file is not a GlyphSpaces export."
      return
    }
    root.setShowOnly(parsed.showOnlyActive)
    root.setRespectTheme(parsed.respectTheme)
    root.setShowNumbers(parsed.showNumbers)
    root.setWorkspaceGap(parsed.workspaceGap)
    var changed = Model.signature(parsed.slots) !== Model.signature(root.draftRows)
    if (changed) root.commitDraft(parsed.slots)
    root.transferNote = changed ? "Imported. Apply updates the workspaces." : "Imported."
  }

  function refreshPanel() {
    root.ensureFonts(true)
    if (root.hostWidget && root.hostWidget.refreshFromPanel) root.hostWidget.refreshFromPanel()
    if (!root.draftDirty()) root.resetDraft()
  }

  function ingestSettings() {
    root.pullShowOnly()
    root.pullRespect()
    root.pullShowNumbers()
    root.pullGap()
    var rows = root.savedRows()
    var sig = Model.signature(rows)
    var slotsChanged = sig !== root.savedSig
    root.savedSig = sig
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
      else if (root.navZone === "footer") root.revealItem(actionRow)
      else if (root.navZone === "tabs") root.revealItem(tabRow)
      else if (root.navZone === "toggle") root.revealItem(toggleCard)
      else if (root.navZone === "theme") root.revealItem(themeCard)
      else if (root.navZone === "numbers") root.revealItem(numbersCard)
      else if (root.navZone === "gap") root.revealItem(gapCard)
      else if (root.navZone === "transfer") root.revealItem(transferCard)
      else if (root.navZone === "count") root.revealItem(countCard)
    })
  }

  function moveCursor(dx, dy) {
    if (root.navZone === "footer") {
      if (dy > 0) root.navZone = "tabs"
      else if (dx < 0) root.navFooter = Math.max(0, root.navFooter - 1)
      else if (dx > 0) root.navFooter = Math.min(3, root.navFooter + 1)
      root.revealNav()
      return
    }
    if (root.navZone === "tabs") {
      if (dy < 0) root.navZone = "footer"
      else if (dy > 0) root.navZone = root.settingsPage === "settings" ? "toggle" : "count"
      else if (dx !== 0) root.setPage(root.settingsPage === "workspaces" ? "settings" : "workspaces")
      root.revealNav()
      return
    }
    if (root.settingsPage === "settings") {
      if (root.navZone === "transfer" && dx !== 0) {
        root.navTransfer = dx < 0 ? 0 : 1
        root.revealNav()
        return
      }
      if (root.navZone === "gap" && dx !== 0) {
        root.stepGap(dx)
        root.revealNav()
        return
      }
      var order = ["toggle", "theme", "numbers", "gap", "transfer"]
      var at = 0
      for (var s = 0; s < order.length; s++) if (order[s] === root.navZone) at = s
      if (dy < 0) root.navZone = at === 0 ? "tabs" : order[at - 1]
      else if (dy > 0 && at < order.length - 1) root.navZone = order[at + 1]
      root.revealNav()
      return
    }
    if (root.navZone === "count") {
      if (dy < 0) root.navZone = "tabs"
      else if (dy > 0) {
        if (root.draftRows.length) {
          root.navZone = "row"
          root.navIndex = 0
          root.navAction = root.firstAction(0)
        }
      } else if (dx !== 0) root.setDraftCount(Model.numberedCount(root.draftRows) + dx)
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
    if (root.navZone === "theme") {
      root.setRespectTheme(!root.respectTheme)
      return
    }
    if (root.navZone === "numbers") {
      root.setShowNumbers(!root.showNumbers)
      return
    }
    if (root.navZone === "transfer") {
      if (root.navTransfer === 0) root.beginImport()
      else root.beginExport()
      return
    }
    if (root.navZone === "tabs") {
      root.setPage(root.settingsPage === "workspaces" ? "settings" : "workspaces")
      return
    }
    if (root.navZone === "count" || root.navZone === "gap") return
    if (root.navZone === "footer") {
      if (root.navFooter === 0) root.applyDraft()
      else if (root.navFooter === 1) root.undoDraft()
      else if (root.navFooter === 2) root.addWorkspace()
      else root.refreshPanel()
      return
    }
    var index = root.navIndex
    var action = root.navAction
    var slot = root.draftRows[index]
    if (!slot) return
    if (action === "title" || action === "label" || action === "caption" || action === "workspace" || action === "order") {
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
    if (action === "clear") {
      root.commitField(index, "label", "", false)
      return
    }
    if (action === "emoji") {
      root.openEmoji(index)
      return
    }
    if (action === "clearCaption") {
      root.commitField(index, "caption", "", false)
      return
    }
    if (action === "font") {
      root.fontOpenIndex = index
      root.fontOpenTick++
      Qt.callLater(root.openFontMenu)
      return
    }
    if (action === "sizeDown" || action === "sizeUp")
      root.commitDraft(Model.stepSize(root.draftRows, index, action === "sizeUp" ? 1 : -1))
    if (action === "bold" || action === "italic")
      root.commitDraft(Model.setFace(
        root.draftRows, index, null, null, null, null,
        action === "bold" ? !slot.bold : null,
        action === "italic" ? !slot.italic : null
      ))
  }

  function commitField(index, action, text, restoreFocus) {
    if (root.fieldLock) return
    root.fieldLock = true
    var before = Model.signature(root.draftRows)
    var rows = root.draftRows
    if (action === "label") rows = Model.setFace(rows, index, text, null, null)
    else if (action === "caption") rows = Model.setFace(rows, index, null, null, null, text)
    else if (action === "title") rows = Model.setMeta(rows, index, text, null)
    else if (action === "workspace") rows = Model.setMeta(rows, index, null, text)
    else if (action === "order") {
      var placed = Model.moveToOrder(rows, index, text)
      rows = placed.slots
      root.navIndex = placed.index
      root.navAction = "order"
    }
    root.editKey = ""
    root.commitDraft(rows)
    if (Model.signature(root.draftRows) === before) {
      var card = rowRepeater.itemAt(index)
      var slot = root.draftRows[index]
      if (card && slot) {
        if (action === "label" && card.labelField) card.labelField.text = slot.label
        if (action === "caption" && card.captionField) card.captionField.text = slot.caption || ""
        if (action === "title" && card.titleField) card.titleField.text = slot.title
        if (action === "workspace" && card.workspaceField) card.workspaceField.text = slot.specialName
        if (action === "order" && card.orderField)
          card.orderField.text = String(Model.orderIndex(root.draftRows, index) || "")
      }
    }
    root.fieldLock = false
    if (restoreFocus) {
      Qt.callLater(function() {
        if (root.opened && !root.fontMenuOpen && !root.emojiMenuOpen) keyCatcher.forceActiveFocus()
      })
    }
  }

  function fieldFor(card, action) {
    if (!card) return null
    if (action === "label") return card.labelField
    if (action === "caption") return card.captionField
    if (action === "title") return card.titleField
    if (action === "workspace") return card.workspaceField
    if (action === "order") return card.orderField
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

  onEditKeyChanged: if (root.editKey) Qt.callLater(root.focusEditor)

  onSettingsChanged: root.ingestSettings()
  onHostWidgetChanged: {
    root.pullShowOnly()
    root.pullRespect()
    root.pullShowNumbers()
    root.pullGap()
  }

  onOpenedChanged: {
    root.hideTips()
    if (root.opened) {
      root.ensureFonts(false)
      root.pullShowNumbers()
      root.pullGap()
      if (!root.draftDirty()) root.resetDraft()
      else Qt.callLater(root.syncFields)
      root.settingsPage = "workspaces"
      root.navZone = "footer"
      root.navIndex = 0
      root.navFooter = 0
      root.editKey = ""
      root.placeSettingsWindow()
      Qt.callLater(function() {
        if (!root.opened) return
        root.syncFields()
        keyCatcher.forceActiveFocus()
      })
    } else {
      root.finishEditing(false)
      root.editKey = ""
      root.fontMenuOpen = false
      root.emojiMenuOpen = false
    }
  }

  Connections {
    target: root.hostWidget
    function onShowOnlyActiveChanged() { root.pullShowOnly() }
    function onRespectThemeChanged() { root.pullRespect() }
    function onShowNumbersChanged() { root.pullShowNumbers() }
    function onWorkspaceGapChanged() { root.pullGap() }
  }

  function placeSettingsWindow() {
    var item = root.anchorItem
    var host = item && item.QsWindow ? item.QsWindow.window : null
    if (host && host.screen) settingsWindow.screen = host.screen
  }

  onRespectThemeChanged: {
    if (root.respectTheme && textColorDialog.visible) textColorDialog.close()
  }

  Component.onCompleted: {
    root.savedSig = Model.signature(root.savedRows())
    root.pullShowOnly()
    root.pullRespect()
    root.pullShowNumbers()
    root.pullGap()
    root.resetDraft()
  }

  FloatingWindow {
    id: settingsWindow
    title: "Omarchy GlyphSpaces"
    color: Color.popups.background
    visible: root.opened
    implicitWidth: 1040
    implicitHeight: 760
    minimumSize: Qt.size(560, 420)

    onVisibleChanged: if (!visible && root.opened) root.close()
    onClosed: if (root.opened) root.close()

    Item {
      id: windowBody
      anchors.fill: parent
      anchors.margins: Style.space(10)

      ColumnLayout {
        id: windowChrome
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        RowLayout {
          id: actionRow
          Layout.fillWidth: true
          spacing: Style.space(8)

          MiniButton {
            text: "Apply"
            hasCursor: root.navZone === "footer" && root.navFooter === 0
            opacity: root.draftDirty() ? 1 : 0.35
            onClicked: {
              root.navZone = "footer"
              root.navFooter = 0
              root.applyDraft()
            }
          }
          MiniButton {
            text: "Undo"
            hasCursor: root.navZone === "footer" && root.navFooter === 1
            opacity: root.draftDirty() || root.undoSlots ? 1 : 0.35
            onClicked: {
              root.navZone = "footer"
              root.navFooter = 1
              root.undoDraft()
            }
          }
          MiniButton {
            text: "Add workspace"
            hasCursor: root.navZone === "footer" && root.navFooter === 2
            opacity: Model.numberedCount(root.draftRows) < 10 ? 1 : 0.35
            onClicked: {
              root.settingsPage = "workspaces"
              root.navZone = "footer"
              root.navFooter = 2
              root.addWorkspace()
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
          Item {
            Layout.fillWidth: true
            Layout.minimumHeight: Style.space(28)
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.SizeAllCursor
              onPressed: settingsWindow.startSystemMove()
            }
          }
          Text {
            textFormat: Text.PlainText
            text: "Omarchy GlyphSpaces"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.SizeAllCursor
              onPressed: settingsWindow.startSystemMove()
            }
          }
        }

        RowLayout {
          id: tabRow
          Layout.fillWidth: true
          spacing: Style.space(8)

          MiniButton {
            text: "Workspaces"
            hasCursor: root.navZone === "tabs" && root.settingsPage === "workspaces"
            onClicked: root.setPage("workspaces")
          }
          MiniButton {
            text: "Settings"
            hasCursor: root.navZone === "tabs" && root.settingsPage === "settings"
            onClicked: root.setPage("settings")
          }
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.cardEdge
          }
        }
      }

      MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        z: 20
        cursorShape: Qt.SizeHorCursor
        onPressed: settingsWindow.startSystemResize(Qt.LeftEdge)
      }
      MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        z: 20
        cursorShape: Qt.SizeHorCursor
        onPressed: settingsWindow.startSystemResize(Qt.RightEdge)
      }
      MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 6
        z: 20
        cursorShape: Qt.SizeVerCursor
        onPressed: settingsWindow.startSystemResize(Qt.BottomEdge)
      }
      MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 6
        z: 20
        cursorShape: Qt.SizeVerCursor
        onPressed: settingsWindow.startSystemResize(Qt.TopEdge)
      }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.top: windowChrome.bottom
      anchors.topMargin: Style.space(8)
      focus: true
      blocked: root.editKey !== "" || root.fontMenuOpen || root.dialogOpen || root.emojiMenuOpen
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
            visible: root.settingsPage === "workspaces"
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "The first numbered row is workspace 1. One row can be a special, and it stays in front. Apply updates the bar."
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }

          Rectangle {
            id: toggleCard
            visible: root.settingsPage === "settings"
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

              SettingCheck { checked: root.showOnlyActive }
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
            id: themeCard
            visible: root.settingsPage === "settings"
            Layout.fillWidth: true
            implicitHeight: themeRow.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.cardFill
            border.width: 1
            border.color: root.navZone === "theme" ? Color.accent : root.cardEdge

            RowLayout {
              id: themeRow
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
                  text: "Respect Omarchy theme"
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  text: "Use the theme's rounding, border, and colors."
                  color: root.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  Layout.fillWidth: true
                }
              }

              SettingCheck { checked: root.respectTheme }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.navZone = "theme"
                root.setRespectTheme(!root.respectTheme)
              }
            }
          }

          Rectangle {
            id: numbersCard
            visible: root.settingsPage === "settings"
            Layout.fillWidth: true
            implicitHeight: numbersRow.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.cardFill
            border.width: 1
            border.color: root.navZone === "numbers" ? Color.accent : root.cardEdge

            RowLayout {
              id: numbersRow
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
                  text: "Show workspace numbers"
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  text: "Show the number after the label."
                  color: root.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  Layout.fillWidth: true
                }
              }
              SettingCheck { checked: root.showNumbers }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.navZone = "numbers"
                root.setShowNumbers(!root.showNumbers)
              }
            }
          }

          Rectangle {
            id: gapCard
            visible: root.settingsPage === "settings"
            Layout.fillWidth: true
            implicitHeight: gapCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.cardFill
            border.width: 1
            border.color: root.navZone === "gap" ? Color.accent : root.cardEdge

            ColumnLayout {
              id: gapCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Workspace spacing"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: root.workspaceGap >= 0 ? (root.workspaceGap + " px between pills") : "Following the theme spacing"
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
                  minimum: 0
                  maximum: 32
                  step: 1
                  value: root.effectiveGap()
                  fillColor: Color.accent
                  knobColor: "#ffffff"
                  trackColor: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.18)
                  onMoved: function(value) {
                    root.navZone = "gap"
                    root.setWorkspaceGap(value)
                  }
                  onReleased: function(value) { root.setWorkspaceGap(value) }
                }
                MiniButton {
                  text: "‹"
                  onClicked: {
                    root.navZone = "gap"
                    root.stepGap(-1)
                  }
                }
                MiniButton {
                  text: "›"
                  onClicked: {
                    root.navZone = "gap"
                    root.stepGap(1)
                  }
                }
                Rectangle {
                  Layout.preferredWidth: Style.space(36)
                  Layout.preferredHeight: Style.space(28)
                  Layout.minimumWidth: Style.space(36)
                  Layout.minimumHeight: Style.space(28)
                  radius: Style.cornerRadius
                  color: Qt.rgba(1, 1, 1, 0.06)
                  border.width: 1
                  border.color: root.cardEdge
                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: String(root.effectiveGap())
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
              }
            }
          }

          Rectangle {
            id: transferCard
            visible: root.settingsPage === "settings"
            Layout.fillWidth: true
            implicitHeight: transferCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.cardFill
            border.width: 1
            border.color: root.navZone === "transfer" ? Color.accent : root.cardEdge

            ColumnLayout {
              id: transferCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Import / export"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                text: "Save or load the rows and these toggles. Apply puts imported rows on the bar."
                color: root.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                Layout.fillWidth: true
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)
                MiniButton {
                  text: "Import"
                  hasCursor: root.navZone === "transfer" && root.navTransfer === 0
                  onClicked: {
                    root.navZone = "transfer"
                    root.navTransfer = 0
                    root.beginImport()
                  }
                }
                MiniButton {
                  text: "Export"
                  hasCursor: root.navZone === "transfer" && root.navTransfer === 1
                  onClicked: {
                    root.navZone = "transfer"
                    root.navTransfer = 1
                    root.beginExport()
                  }
                }
              }
              Text {
                visible: root.transferNote !== ""
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                text: root.transferNote
                color: root.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                Layout.fillWidth: true
              }
            }
          }

          Rectangle {
            id: countCard
            visible: root.settingsPage === "workspaces"
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
                text: "How many numbered pills to keep."
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
            visible: root.settingsPage === "workspaces"
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "Order is the workspace number. Symbol takes 3 characters. The smiley picks an emoji. × clears the symbol or the label. Font, B, I, and size apply to both. The square sets the color when the theme is off. Right-click it to clear."
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }

          GridLayout {
            id: rowGrid
            visible: root.settingsPage === "workspaces"
            Layout.fillWidth: true
            columns: 1
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
                property alias captionField: captionField
                property alias titleField: titleField
                property alias workspaceField: workspaceField
                property alias orderField: orderField
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
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText
                      text: card.special ? "Name" : "Order"
                      color: root.muted
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      Layout.alignment: Qt.AlignVCenter
                      Layout.preferredWidth: Style.space(64)
                    }

                    TextField {
                      id: orderField
                      visible: !card.special
                      activeFocusOnTab: !card.special
                      text: String(Model.orderIndex(root.draftRows, index) || "")
                      hasCursor: root.rowHot(index, "order")
                      horizontalAlignment: Text.AlignHCenter
                      maximumLength: 2
                      Layout.preferredWidth: Style.space(44)
                      Layout.alignment: Qt.AlignVCenter
                      font.pixelSize: Style.font.body
                      font.bold: true
                      onActiveFocusChanged: {
                        if (root.fieldLock) return
                        if (activeFocus) {
                          root.navZone = "row"
                          root.navIndex = index
                          root.navAction = "order"
                          root.editKey = index + ":order"
                          return
                        }
                        if (root.editKey !== index + ":order") return
                        root.commitField(index, "order", text, false)
                      }
                      Keys.onEscapePressed: function(event) {
                        root.cancelEdit(orderField, String(Model.orderIndex(root.draftRows, index) || ""))
                        event.accepted = true
                      }
                      Keys.onReturnPressed: function(event) {
                        root.commitField(index, "order", text, true)
                        event.accepted = true
                      }
                      Keys.onEnterPressed: function(event) {
                        root.commitField(index, "order", text, true)
                        event.accepted = true
                      }
                    }

                    TextField {
                      id: titleField
                      visible: card.special
                      activeFocusOnTab: card.special
                      text: modelData.title
                      placeholderText: "Name"
                      hasCursor: root.rowHot(index, "title")
                      Layout.fillWidth: true
                      Layout.minimumWidth: Style.space(80)
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

                    Text {
                      textFormat: Text.PlainText
                      text: "Symbol"
                      color: root.muted
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                      id: labelField
                      text: modelData.label
                      hasCursor: root.rowHot(index, "label")
                      maximumLength: Math.max(3, (modelData.label || "").length)
                      Layout.preferredWidth: Style.space(72)
                      Layout.maximumWidth: Style.space(84)
                      Layout.alignment: Qt.AlignVCenter
                      font.pixelSize: Style.font.body
                      font.family: modelData.font ? modelData.font : root.fontFamily
                      font.bold: !!modelData.bold
                      font.italic: !!modelData.italic
                      foreground: (!root.respectTheme && modelData.color) ? modelData.color : Color.foreground
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
                      id: symbolClear
                      text: "×"
                      hasCursor: root.rowHot(index, "clear")
                      opacity: modelData.label ? 1 : 0.35
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "clear"
                        root.activateCursor()
                      }
                    }
                    MiniButton {
                      text: "😀"
                      fontFamily: "Noto Color Emoji"
                      fontSize: Style.font.body
                      tooltipText: "Emoji"
                      horizontalPadding: symbolClear.horizontalPadding
                      verticalPadding: symbolClear.verticalPadding
                      Layout.minimumWidth: symbolClear.implicitWidth
                      Layout.minimumHeight: symbolClear.implicitHeight
                      Layout.preferredWidth: symbolClear.implicitWidth
                      Layout.preferredHeight: symbolClear.implicitHeight
                      hasCursor: root.rowHot(index, "emoji")
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "emoji"
                        root.activateCursor()
                      }
                    }

                    Item {
                      Layout.fillWidth: true
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
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText
                      text: "Label"
                      color: root.muted
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      Layout.alignment: Qt.AlignVCenter
                      Layout.preferredWidth: Style.space(64)
                    }

                    TextField {
                      id: captionField
                      text: modelData.caption || ""
                      placeholderText: "Optional"
                      hasCursor: root.rowHot(index, "caption")
                      Layout.fillWidth: true
                      Layout.preferredWidth: Style.space(96)
                      Layout.minimumWidth: Style.space(64)
                      font.pixelSize: Style.font.body
                      font.family: modelData.font ? modelData.font : root.fontFamily
                      font.bold: !!modelData.bold
                      font.italic: !!modelData.italic
                      foreground: (!root.respectTheme && modelData.color) ? modelData.color : Color.foreground
                      onActiveFocusChanged: {
                        if (root.fieldLock) return
                        if (activeFocus) {
                          root.navZone = "row"
                          root.navIndex = index
                          root.navAction = "caption"
                          root.editKey = index + ":caption"
                          return
                        }
                        if (root.editKey !== index + ":caption") return
                        root.commitField(index, "caption", text, false)
                      }
                      Keys.onEscapePressed: function(event) {
                        root.cancelEdit(captionField, modelData.caption || "")
                        event.accepted = true
                      }
                      Keys.onReturnPressed: function(event) {
                        root.commitField(index, "caption", text, true)
                        event.accepted = true
                      }
                      Keys.onEnterPressed: function(event) {
                        root.commitField(index, "caption", text, true)
                        event.accepted = true
                      }
                    }

                    MiniButton {
                      text: "×"
                      hasCursor: root.rowHot(index, "clearCaption")
                      opacity: modelData.caption ? 1 : 0.35
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "clearCaption"
                        root.activateCursor()
                      }
                    }

                    Rectangle {
                      visible: !root.respectTheme
                      Layout.preferredWidth: Style.space(22)
                      Layout.preferredHeight: Style.space(22)
                      Layout.alignment: Qt.AlignVCenter
                      radius: Style.space(4)
                      color: modelData.color ? modelData.color : "#ffffff"
                      border.width: 1
                      border.color: root.cardEdge

                      MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                          root.navZone = "row"
                          root.navIndex = index
                          root.navAction = "caption"
                          if (mouse.button === Qt.RightButton) {
                            root.commitDraft(Model.setFace(root.draftRows, index, null, null, null, null, null, null, ""))
                            return
                          }
                          root.openTextColor(index)
                        }
                      }
                    }

                    SearchableDropdown {
                      id: fontDrop
                      property bool sawFontPopup: false
                      showLabel: false
                      value: modelData.font || ""
                      options: root.fontOptions
                      hasCursor: root.rowHot(index, "font")
                      placeholderText: "Search fonts..."
                      Layout.fillWidth: true
                      Layout.preferredWidth: Style.space(150)
                      Layout.minimumWidth: Style.space(96)
                      Layout.alignment: Qt.AlignVCenter
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
                      id: boldButton
                      text: "B"
                      selected: !!modelData.bold
                      tooltipText: "Bold"
                      hasCursor: root.rowHot(index, "bold")
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "bold"
                        root.activateCursor()
                      }
                    }
                    MiniButton {
                      id: italicButton
                      // The kit button paints its label upright, so the italic I is drawn here.
                      text: ""
                      selected: !!modelData.italic
                      tooltipText: "Italic"
                      Layout.preferredWidth: boldButton.implicitWidth
                      Layout.minimumWidth: boldButton.implicitWidth
                      Layout.preferredHeight: boldButton.implicitHeight
                      Layout.minimumHeight: boldButton.implicitHeight
                      hasCursor: root.rowHot(index, "italic")
                      onClicked: {
                        root.navZone = "row"
                        root.navIndex = index
                        root.navAction = "italic"
                        root.activateCursor()
                      }
                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "I"
                        font.family: Style.font.family
                        font.pixelSize: italicButton.fontSize
                        font.italic: true
                        font.bold: italicButton.selected
                        color: italicButton.selected
                          ? Style.selectedStateColor(italicButton.foreground, italicButton.accent)
                          : italicButton.foreground
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
            visible: root.settingsPage === "workspaces"
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "Arrows move. Enter edits. Esc closes. x removes a row."
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            Layout.fillWidth: true
          }

        }
      }
    }
    }

    Item {
      anchors.fill: parent
      z: 40
      visible: root.emojiMenuOpen

      MouseArea {
        anchors.fill: parent
        scrollGestureEnabled: false
        onClicked: root.closeEmoji()
      }

      WheelHandler {
        orientation: Qt.Vertical
        blocking: true
        onWheel: function(event) {
          var dy = event.pixelDelta.y
          if (!dy) dy = event.angleDelta.y
          var next = emojiGrid.contentY - dy
          var maxY = Math.max(0, emojiGrid.contentHeight - emojiGrid.height)
          if (next < 0) next = 0
          if (next > maxY) next = maxY
          emojiGrid.contentY = next
          event.accepted = true
        }
      }

      Rectangle {
        id: emojiSheet
        width: Math.min(parent.width - Style.space(32), Style.space(640))
        height: Math.min(parent.height - Style.space(32), Style.space(560))
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: Color.popups.background
        border.width: 1
        border.color: root.cardEdge

        MouseArea {
          anchors.fill: parent
          scrollGestureEnabled: false
          onClicked: {}
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText
              text: "Emoji"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
            TextField {
              id: emojiSearch
              Layout.fillWidth: true
              placeholderText: "Search"
              font.pixelSize: Style.font.body
              onTextChanged: {
                root.emojiQuery = text
                root.refreshEmoji()
              }
              Keys.onEscapePressed: function(event) {
                root.closeEmoji()
                event.accepted = true
              }
              Keys.onReturnPressed: function(event) {
                if (root.emojiHits.length) root.pickEmoji(root.emojiHits[0])
                event.accepted = true
              }
              Keys.onEnterPressed: function(event) {
                if (root.emojiHits.length) root.pickEmoji(root.emojiHits[0])
                event.accepted = true
              }
            }
            MiniButton {
              text: "×"
              onClicked: root.closeEmoji()
            }
          }

          Text {
            visible: root.emojiHits.length === 0
            textFormat: Text.PlainText
            text: "No matches"
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          GridView {
            id: emojiGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Style.space(64)
            cellHeight: Style.space(64)
            cacheBuffer: Style.space(256)
            boundsBehavior: Flickable.StopAtBounds
            model: root.emojiHits

            delegate: Item {
              required property string modelData
              required property int index
              width: emojiGrid.cellWidth
              height: emojiGrid.cellHeight

              Rectangle {
                anchors.fill: parent
                anchors.margins: Style.space(4)
                radius: Style.space(6)
                color: emojiCell.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
              }

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData
                font.family: "Noto Color Emoji"
                font.pixelSize: Style.space(32)
              }

              MouseArea {
                id: emojiCell
                anchors.fill: parent
                hoverEnabled: true
                scrollGestureEnabled: false
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pickEmoji(modelData)
              }
            }
          }
        }
      }
    }

    ColorDialog {
      id: textColorDialog
      title: "Workspace text"
      parentWindow: settingsWindow
      onAccepted: root.acceptTextColor()
      onRejected: root.dismissDialog()
    }

    FileDialog {
      id: exportDialog
      title: "Export GlyphSpaces settings"
      fileMode: FileDialog.SaveFile
      nameFilters: ["JSON files (*.json)"]
      defaultSuffix: "json"
      parentWindow: settingsWindow
      onAccepted: root.finishExportDialog()
      onRejected: root.dismissDialog()
    }

    FileDialog {
      id: importDialog
      title: "Import GlyphSpaces settings"
      fileMode: FileDialog.OpenFile
      nameFilters: ["JSON files (*.json)"]
      parentWindow: settingsWindow
      onAccepted: root.finishImportDialog()
      onRejected: root.dismissDialog()
    }
  }

}
