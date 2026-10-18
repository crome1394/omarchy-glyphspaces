// Workspace list for the Omarchy bar widget.
//
// Numbered pills keep the order you set. Specials always sit in front of
// them, and order inside that group is their order on the bar. Occupied
// workspaces that are not in the list still appear after the numbered pills.
// Nothing here reads the Cachy Quickshell config. The rules stay in this file
// so they can be tested without a running shell.

var MAX_NUMBERED = 10
var MAX_SPECIALS = 8
var LABEL_LIMIT = 8
var FONT_LIMIT = 120
var TITLE_LIMIT = 24
var DEFAULT_FONT = "Noto Color Emoji"
var DEFAULT_PX = 14
var DEFAULT_COUNT = 8

// Yellow, blue, green, red, orange, purple, brown, white, black, blue square.
var DOTS = [
  "\uD83D\uDFE1",
  "\uD83D\uDD35",
  "\uD83D\uDFE2",
  "\uD83D\uDD34",
  "\uD83D\uDFE0",
  "\uD83D\uDFE3",
  "\uD83D\uDFE4",
  "\u26AA",
  "\u26AB",
  "\uD83D\uDFE6"
]

function asArray(value) {
  if (!value || typeof value.length !== "number") return []
  var out = []
  for (var i = 0; i < value.length; i++) out.push(value[i])
  return out
}

function clampCount(count) {
  var n = Math.round(Number(count))
  if (!(n >= 1)) n = 1
  if (n > MAX_NUMBERED) n = MAX_NUMBERED
  return n
}

function clampText(value, maxUnits) {
  var text = String(value === undefined || value === null ? "" : value)
  text = text.replace(/[\r\n\t]/g, " ").replace(/^\s+|\s+$/g, "")
  if (text.length <= maxUnits) return text
  var cut = text.substring(0, maxUnits)
  var last = cut.charCodeAt(cut.length - 1)
  if (last >= 0xD800 && last <= 0xDBFF) cut = cut.substring(0, cut.length - 1)
  return cut
}

function clampFontPx(value) {
  var n = Math.round(Number(value))
  if (n >= 8 && n <= 32) return n
  return 0
}

function effectivePx(fontPx) {
  var n = clampFontPx(fontPx)
  return n >= 8 ? n : DEFAULT_PX
}

function defaultFont() {
  return DEFAULT_FONT
}

function dotForId(id) {
  var n = Math.round(Number(id))
  if (n >= 1 && n <= DOTS.length) return DOTS[n - 1]
  return "\u25CF"
}

function bareSpecial(name) {
  var text = String(name === undefined || name === null ? "" : name).replace(/^\s+|\s+$/g, "")
  while (text.toLowerCase().indexOf("special:") === 0) text = text.substring(8)
  text = text.replace(/[^A-Za-z0-9_-]/g, "")
  if (text.length > 32) text = text.substring(0, 32)
  return text
}

function isSpecial(raw) {
  if (!raw) return false
  if (raw.special === true || raw.isSpecial === true) return true
  var kind = String(raw.kind || "")
  return kind === "special" || kind === "magic" || kind === "scratchpad"
}

function prettyTitle(name) {
  if (name === "magic") return "Magic"
  if (name === "scratchpad") return "Scratchpad"
  if (!name) return "Special"
  return name.charAt(0).toUpperCase() + name.substring(1)
}

function cleanTitle(text, fallback) {
  var title = clampText(text, TITLE_LIMIT)
  if (title) return title
  var fb = clampText(fallback, TITLE_LIMIT)
  return fb || "Special"
}

function defaultLabel(slot) {
  if (!isSpecial(slot)) return dotForId(slot && slot.id)
  var name = bareSpecial(slot && slot.specialName)
  if (!name) {
    var kind = String((slot && slot.kind) || "")
    if (kind === "magic" || kind === "scratchpad") name = kind
  }
  if (name === "scratchpad") return "\u270D\uFE0F"
  if (name === "magic") return "\uD83E\uDE84"
  return "\u2726"
}

function specialNameOf(raw) {
  var name = bareSpecial(raw && raw.specialName)
  if (name) return name
  var kind = String((raw && raw.kind) || "")
  if (kind === "magic" || kind === "scratchpad") return kind
  return ""
}

function sanitize(slots) {
  var list = asArray(slots)
  var specials = []
  var numbered = []
  var seenName = {}
  var usedId = {}
  for (var i = 0; i < list.length; i++) {
    var raw = list[i] || {}
    var font = clampText(raw.font, FONT_LIMIT)
    var fontPx = clampFontPx(raw.fontPx)
    var label = clampText(raw.label, LABEL_LIMIT)
    if (isSpecial(raw)) {
      if (specials.length >= MAX_SPECIALS) continue
      var name = specialNameOf(raw)
      if (!name || seenName[name]) continue
      seenName[name] = true
      if (!label) label = defaultLabel({ kind: "special", specialName: name })
      specials.push({
        id: 0,
        kind: "special",
        specialName: name,
        title: cleanTitle(raw.title, prettyTitle(name)),
        label: label,
        font: font,
        fontPx: fontPx
      })
      continue
    }
    if (numbered.length >= MAX_NUMBERED) continue
    var id = Math.round(Number(raw.id))
    if (!(id >= 1) || id > MAX_NUMBERED || usedId[id]) continue
    usedId[id] = true
    if (!label) label = dotForId(id)
    numbered.push({
      id: id,
      kind: "ws",
      label: label,
      font: font,
      fontPx: fontPx,
      specialName: "",
      title: ""
    })
  }
  return specials.concat(numbered)
}

function defaultSlots(count) {
  var n = clampCount(count === undefined ? DEFAULT_COUNT : count)
  var out = []
  for (var i = 1; i <= n; i++) {
    out.push({
      id: i,
      kind: "ws",
      label: dotForId(i),
      font: DEFAULT_FONT,
      fontPx: DEFAULT_PX,
      specialName: "",
      title: ""
    })
  }
  return out
}

function hasSpecial(slots) {
  var list = asArray(slots)
  for (var i = 0; i < list.length; i++) if (isSpecial(list[i])) return true
  return false
}

function numberedCount(slots) {
  var list = sanitize(slots)
  var n = 0
  for (var i = 0; i < list.length; i++) if (list[i].kind !== "special") n++
  return n
}

function specialCount(slots) {
  var list = sanitize(slots)
  var n = 0
  for (var i = 0; i < list.length; i++) if (list[i].kind === "special") n++
  return n
}

function nextFreeId(slots) {
  var used = {}
  var list = sanitize(slots)
  for (var i = 0; i < list.length; i++) {
    if (list[i].kind === "special") continue
    used[list[i].id] = true
  }
  for (var id = 1; id <= MAX_NUMBERED; id++) if (!used[id]) return id
  return -1
}

function signature(slots) {
  var list = sanitize(slots)
  var parts = []
  for (var i = 0; i < list.length; i++) {
    var slot = list[i]
    parts.push([
      slot.kind,
      slot.id,
      slot.label,
      slot.font,
      slot.fontPx,
      slot.specialName || "",
      slot.title || ""
    ].join("\t"))
  }
  return parts.join("\n")
}

function rowsFromSettings(settings) {
  var src = settings || {}
  var stored = src.slots
  var hasStored = !!(stored && typeof stored.length === "number" && stored.length > 0)
  var rows = hasStored ? sanitize(stored) : defaultSlots(DEFAULT_COUNT)
  if (hasStored && src.showMagic === true && !hasSpecial(rows)) {
    var legacy = {
      kind: "special",
      specialName: bareSpecial(src.specialName) || "magic",
      title: "Magic",
      label: src.magicIcon || "\uD83E\uDE84",
      font: src.magicFont || "",
      fontPx: src.magicFontPx || 0
    }
    rows = sanitize([legacy].concat(asArray(rows)))
  }
  if (!numberedCount(rows)) rows = sanitize(asArray(rows).concat(defaultSlots(1)))
  return rows
}

function resizeNumbered(slots, count) {
  var cur = sanitize(slots)
  var n = clampCount(count)
  function countWs() {
    var c = 0
    for (var i = 0; i < cur.length; i++) if (cur[i].kind !== "special") c++
    return c
  }
  while (countWs() > n) {
    for (var i = cur.length - 1; i >= 0; i--) {
      if (cur[i].kind !== "special") {
        cur.splice(i, 1)
        break
      }
    }
  }
  while (countWs() < n) {
    var id = nextFreeId(cur)
    if (id < 0) break
    cur.push({
      id: id,
      kind: "ws",
      label: dotForId(id),
      font: DEFAULT_FONT,
      fontPx: DEFAULT_PX,
      specialName: "",
      title: ""
    })
  }
  return sanitize(cur)
}

function addNumbered(slots) {
  return resizeNumbered(slots, numberedCount(slots) + 1)
}

function canMove(slots, index, delta) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  var j = i + Math.round(Number(delta))
  if (i < 0 || j < 0 || i >= cur.length || j >= cur.length) return false
  return (cur[i].kind === "special") === (cur[j].kind === "special")
}

function moveWithin(slots, index, delta) {
  var cur = sanitize(slots)
  if (!canMove(cur, index, delta)) return cur
  var i = Math.round(Number(index))
  var j = i + Math.round(Number(delta))
  var tmp = cur[i]
  cur[i] = cur[j]
  cur[j] = tmp
  return sanitize(cur)
}

function canRemove(slots, index) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length) return false
  if (cur[i].kind === "special") return true
  return numberedCount(cur) > 1
}

function removeAt(slots, index) {
  var cur = sanitize(slots)
  if (!canRemove(cur, index)) return cur
  cur.splice(Math.round(Number(index)), 1)
  return sanitize(cur)
}

function uniqueName(slots, preferred, ignoreIndex) {
  var bare = bareSpecial(preferred) || "special"
  var taken = {}
  var list = sanitize(slots)
  var skip = Math.round(Number(ignoreIndex))
  for (var i = 0; i < list.length; i++) {
    if (i === skip) continue
    if (list[i].kind === "special" && list[i].specialName) taken[list[i].specialName] = true
  }
  if (!taken[bare]) return bare
  for (var n = 2; n < 100; n++) {
    var next = bareSpecial(bare + n)
    if (next && !taken[next]) return next
  }
  return bare
}

function canSetSpecial(slots, index) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length) return false
  if (cur[i].kind === "special") return nextFreeId(cur) >= 0
  return numberedCount(cur) > 1 && specialCount(cur) < MAX_SPECIALS
}

function setSpecial(slots, index, on) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length) return { slots: cur, index: Math.max(0, i) }
  var slot = cur[i]
  var want = !!on
  if (want === (slot.kind === "special")) return { slots: cur, index: i }
  if (!canSetSpecial(cur, i)) return { slots: cur, index: i }
  if (want) {
    var oldId = slot.id
    var made = {
      id: 0,
      kind: "special",
      specialName: uniqueName(cur, "s" + oldId, i),
      title: cleanTitle("Special " + oldId, "Special"),
      label: slot.label || dotForId(oldId),
      font: slot.font,
      fontPx: slot.fontPx
    }
    cur.splice(i, 1)
    var at = 0
    while (at < cur.length && cur[at].kind === "special") at++
    cur.splice(at, 0, made)
    return { slots: sanitize(cur), index: at }
  }
  var id = nextFreeId(cur)
  cur.splice(i, 1)
  cur.push({
    id: id,
    kind: "ws",
    label: slot.label || dotForId(id),
    font: slot.font,
    fontPx: slot.fontPx,
    specialName: "",
    title: ""
  })
  var cleaned = sanitize(cur)
  return { slots: cleaned, index: cleaned.length - 1 }
}

function setFace(slots, index, label, font, fontPx) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length) return cur
  var slot = cur[i]
  if (label !== undefined && label !== null) {
    var text = clampText(label, LABEL_LIMIT)
    slot.label = text || defaultLabel(slot)
  }
  if (font !== undefined && font !== null) slot.font = clampText(font, FONT_LIMIT)
  if (fontPx !== undefined && fontPx !== null) slot.fontPx = clampFontPx(fontPx)
  return sanitize(cur)
}

function stepSize(slots, index, delta) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length) return cur
  var px = effectivePx(cur[i].fontPx)
  var next = px + (Math.round(Number(delta)) || 0)
  if (next < 8) next = 8
  if (next > 32) next = 32
  if (next === px && cur[i].fontPx === next) return cur
  return setFace(cur, i, null, null, next)
}

function setMeta(slots, index, title, specialName) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length || cur[i].kind !== "special") return cur
  if (title !== undefined && title !== null) cur[i].title = cleanTitle(title, cur[i].title)
  if (specialName !== undefined && specialName !== null) {
    var name = bareSpecial(specialName)
    if (name && name !== cur[i].specialName) {
      var clash = false
      for (var k = 0; k < cur.length; k++) {
        if (k !== i && cur[k].kind === "special" && cur[k].specialName === name) clash = true
      }
      if (!clash) cur[i].specialName = name
    }
  }
  return sanitize(cur)
}

function fontList(families, extra) {
  var list = [""]
  var seen = { "": true }
  function add(name) {
    var text = clampText(name, FONT_LIMIT)
    if (!text || seen[text]) return
    seen[text] = true
    list.push(text)
  }
  var fams = asArray(families)
  for (var i = 0; i < fams.length; i++) add(fams[i])
  add(extra)
  return list
}

function stepFont(current, delta, families) {
  var list = fontList(families, current)
  var cur = String(current || "")
  var at = 0
  for (var i = 0; i < list.length; i++) if (list[i] === cur) { at = i; break }
  var step = Math.round(Number(delta)) || 0
  var next = at + step
  next = ((next % list.length) + list.length) % list.length
  return list[next]
}

function rowActions(slot) {
  var actions = ["label", "up", "down", "special", "remove", "font", "fontPrev", "fontNext", "sizeDown", "sizeUp"]
  if (isSpecial(slot)) {
    actions.unshift("title")
    actions.push("workspace")
  }
  return actions
}

function occupied(workspace) {
  return !!(workspace && (workspace.occupied || workspace.active || workspace.focused))
}

function faceEntry(slot, selected, occupiedFlag) {
  var special = slot.kind === "special"
  return {
    id: special ? 0 : slot.id,
    isSpecial: special,
    specialName: special ? slot.specialName : "",
    title: special ? slot.title : String(slot.id),
    label: slot.label,
    font: slot.font,
    fontPx: slot.fontPx,
    showNumber: !special,
    number: special ? "" : String(slot.id),
    selected: !!selected,
    occupied: !!occupiedFlag
  }
}

function visibleEntries(state) {
  var source = state || {}
  var slots = rowsFromSettings({ slots: source.slots })
  if (source.slots && source.slots.length) slots = sanitize(source.slots)
  var byId = {}
  var workspaces = asArray(source.workspaces)
  for (var i = 0; i < workspaces.length; i++) {
    var workspace = workspaces[i]
    if (!workspace || !(workspace.id > 0)) continue
    byId[Math.round(Number(workspace.id))] = workspace
  }
  var focusedId = source.focusedId > 0 ? Math.round(Number(source.focusedId)) : 0
  var activeSpecial = bareSpecial(source.activeSpecial)
  var showOnly = !!source.showOnlyActive
  var inSlot = {}
  var result = []

  for (var s = 0; s < slots.length; s++) {
    var slot = slots[s]
    if (slot.kind === "special") {
      var on = activeSpecial === slot.specialName
      result.push(faceEntry(slot, on, on))
      continue
    }
    inSlot[slot.id] = true
    var live = byId[slot.id]
    var isOccupied = occupied(live)
    var focused = focusedId === slot.id || !!(live && live.focused)
    if (showOnly && !isOccupied && focusedId !== slot.id) continue
    result.push(faceEntry(slot, !activeSpecial && focused, isOccupied))
  }

  var extras = []
  for (var key in byId) {
    var extraId = Number(key)
    if (inSlot[extraId]) continue
    if (occupied(byId[extraId])) extras.push(extraId)
  }
  extras.sort(function(a, b) { return a - b })
  for (var e = 0; e < extras.length; e++) {
    var extra = byId[extras[e]]
    var extraFocused = focusedId === extras[e] || !!(extra && extra.focused)
    result.push(faceEntry({
      id: extras[e],
      kind: "ws",
      label: dotForId(extras[e]),
      font: DEFAULT_FONT,
      fontPx: DEFAULT_PX
    }, !activeSpecial && extraFocused, true))
  }

  if (!result.length) {
    var fallback = null
    for (var f = 0; f < slots.length; f++) {
      if (slots[f].kind !== "special") { fallback = slots[f]; break }
    }
    if (!fallback) {
      fallback = {
        id: 1,
        kind: "ws",
        label: dotForId(1),
        font: DEFAULT_FONT,
        fontPx: DEFAULT_PX
      }
    }
    result.push(faceEntry(fallback, true, false))
  }
  return result
}

function specialNames(slots) {
  var list = sanitize(slots)
  var names = []
  for (var i = 0; i < list.length; i++) {
    if (list[i].kind === "special") names.push(list[i].specialName)
  }
  return names
}

function numberedFloor(slots) {
  var list = sanitize(slots)
  var floor = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i].kind === "special") continue
    if (!floor || list[i].id < floor) floor = list[i].id
  }
  return floor || 1
}

function focusDispatch(workspace) {
  var text = String(workspace)
  if (text !== "+1" && text !== "-1") {
    var n = Math.round(Number(text))
    if (!(n >= 1) || n > MAX_NUMBERED) n = 1
    text = String(n)
  }
  return "hl.dsp.focus({ workspace = \"" + text + "\" })"
}

function toggleDispatch(name) {
  var safe = bareSpecial(name)
  if (!safe) return ""
  return "hl.dsp.workspace.toggle_special('" + safe + "')"
}

function nameIndex(names, name) {
  for (var i = 0; i < names.length; i++) if (names[i] === name) return i
  return -1
}

function relativeActions(state, delta) {
  var source = state || {}
  var names = specialNames(source.slots)
  var current = bareSpecial(source.activeSpecial)
  var wsId = source.focusedId > 0 ? Math.round(Number(source.focusedId)) : 1
  var floor = numberedFloor(source.slots)
  var forward = Number(delta) > 0
  var idx = current ? nameIndex(names, current) : -1

  if (current && idx >= 0) {
    if (forward) {
      if (idx < names.length - 1) return [toggleDispatch(current), toggleDispatch(names[idx + 1])]
      return [toggleDispatch(current)]
    }
    if (idx > 0) return [toggleDispatch(current), toggleDispatch(names[idx - 1])]
    return []
  }
  if (current && idx < 0) return [toggleDispatch(current)]
  if (forward) return [focusDispatch("+1")]
  if (wsId <= floor) {
    if (names.length) return [toggleDispatch(names[names.length - 1])]
    return []
  }
  return [focusDispatch("-1")]
}

function activateActions(entry, state) {
  var source = state || {}
  if (!entry) return []
  var current = bareSpecial(source.activeSpecial)
  if (entry.isSpecial) {
    var name = bareSpecial(entry.specialName)
    if (!name) return []
    if (current && current !== name) return [toggleDispatch(current), toggleDispatch(name)]
    return [toggleDispatch(name)]
  }
  if (!(entry.id > 0)) return []
  var actions = []
  if (current) actions.push(toggleDispatch(current))
  var focused = source.focusedId > 0 ? Math.round(Number(source.focusedId)) : 0
  if (focused !== Math.round(Number(entry.id))) actions.push(focusDispatch(entry.id))
  return actions
}

function chipLayout(spec) {
  var src = spec || {}
  var vertical = !!src.vertical
  var inner = Math.round(Number(src.inner))
  if (!(inner >= 12)) inner = 24
  var requested = Math.round(Number(src.fontPx))
  if (!(requested >= 8 && requested <= 32)) requested = DEFAULT_PX
  var showNumber = !!src.showNumber
  var gap = showNumber ? 2 : 0
  var pad = 4
  var budget = Math.max(8, inner - pad)
  var icon = Math.min(requested, budget)
  var number = showNumber ? Math.min(Math.max(8, Math.min(15, Math.round(requested * 0.9))), budget) : 0

  function numberWidth(px) {
    return Math.max(8, Math.ceil(px * 0.72))
  }

  // The bar look is a dot beside its number. On a side bar the thickness is
  // the width, so shrink the pair until it fits. Stack only when even the
  // smallest pair is wider than the bar.
  var stack = false
  if (vertical && showNumber) {
    var guard = 0
    while (icon + gap + numberWidth(number) > budget && guard < 40) {
      if (icon >= number && icon > 8) icon -= 1
      else if (number > 8) number -= 1
      else break
      guard += 1
    }
    if (icon + gap + numberWidth(number) > budget) {
      stack = true
      icon = Math.min(requested, budget)
      number = Math.min(Math.max(8, Math.round(requested * 0.75)), Math.max(8, Math.floor(budget * 0.45)))
    }
  }

  var numberW = showNumber ? numberWidth(number) : 0
  var width
  var height
  if (!vertical) {
    height = inner
    width = (showNumber ? icon + gap + numberW : icon) + pad
  } else if (stack) {
    width = inner
    height = icon + gap + number + pad
  } else {
    width = inner
    height = Math.max(icon, number) + pad
  }
  return {
    stack: stack,
    icon: icon,
    number: showNumber ? number : 0,
    numberW: numberW,
    gap: showNumber ? gap : 0,
    width: width,
    height: height
  }
}

function truthy(value) {
  if (value === true || value === 1) return true
  var text = String(value === undefined || value === null ? "" : value).toLowerCase()
  return text === "true" || text === "1" || text === "on" || text === "yes"
}

if (typeof module !== "undefined") {
  module.exports = {
    dotForId: dotForId,
    defaultFont: defaultFont,
    effectivePx: effectivePx,
    bareSpecial: bareSpecial,
    sanitize: sanitize,
    defaultSlots: defaultSlots,
    rowsFromSettings: rowsFromSettings,
    signature: signature,
    numberedCount: numberedCount,
    resizeNumbered: resizeNumbered,
    addNumbered: addNumbered,
    canMove: canMove,
    moveWithin: moveWithin,
    canRemove: canRemove,
    removeAt: removeAt,
    canSetSpecial: canSetSpecial,
    setSpecial: setSpecial,
    setFace: setFace,
    stepSize: stepSize,
    setMeta: setMeta,
    stepFont: stepFont,
    rowActions: rowActions,
    visibleEntries: visibleEntries,
    relativeActions: relativeActions,
    activateActions: activateActions,
    focusDispatch: focusDispatch,
    toggleDispatch: toggleDispatch,
    chipLayout: chipLayout,
    truthy: truthy,
    numberedFloor: numberedFloor
  }
}
