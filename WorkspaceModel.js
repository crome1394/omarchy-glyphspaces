// Workspace list for Omarchy GlyphSpaces.
//
// Numbered pills keep the order you set, and that order is the workspace
// number: the first numbered row is workspace 1. Specials always sit in
// front of them. Occupied workspaces that are not in the list still appear
// after the numbered pills. Each pill has a short symbol and an optional
// text label. The label can stand alone. The rules stay in this file so
// they can be tested without a shell.

var MAX_NUMBERED = 10
var MAX_SPECIALS = 1
var LABEL_LIMIT = 3
var CAPTION_LIMIT = 24
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

// Typed symbols stay at three characters. A picked emoji can be longer.
function clampSymbol(value) {
  var text = clampText(value, 16)
  if (text.length <= LABEL_LIMIT) return text
  if (!hasEmoji(text) || hasAsciiWord(text)) return clampText(text, LABEL_LIMIT)
  return text
}

function hasAsciiWord(text) {
  for (var i = 0; i < text.length; i++) {
    var c = text.charCodeAt(i)
    if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122)) return true
  }
  return false
}

function hasEmoji(text) {
  for (var i = 0; i < text.length; i++) {
    var c = text.charCodeAt(i)
    if (c >= 0xD800) return true
    if (c >= 0x2190 && c <= 0x2BFF) return true
    if (c >= 0x2600 && c <= 0x27BF) return true
  }
  return false
}

function clampFontPx(value) {
  var n = Math.round(Number(value))
  if (n >= 8 && n <= 32) return n
  return 0
}

// Empty means the bar's own ink. #rgb, #rrggbb, and #rrggbbaa become #rrggbb.
function clampColor(value) {
  var text = String(value === undefined || value === null ? "" : value)
  text = text.replace(/^\s+|\s+$/g, "").toLowerCase()
  if (!text) return ""
  if (text.charAt(0) === "#") text = text.substring(1)
  if (!/^[0-9a-f]+$/.test(text)) return ""
  if (text.length === 3 || text.length === 4) {
    var r = text.charAt(0)
    var g = text.charAt(1)
    var b = text.charAt(2)
    return "#" + r + r + g + g + b + b
  }
  if (text.length === 6) return "#" + text
  if (text.length === 8) return "#" + text.substring(0, 6)
  return ""
}

function styleOf(raw) {
  var src = raw || {}
  return {
    color: clampColor(src.color),
    bold: truthy(src.bold),
    italic: truthy(src.italic)
  }
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
    var caption = clampText(raw.caption, CAPTION_LIMIT)
    var label = clampSymbol(raw.label)
    if (isSpecial(raw)) {
      if (specials.length >= MAX_SPECIALS) continue
      var name = specialNameOf(raw)
      if (!name || seenName[name]) continue
      seenName[name] = true
      if (!label && !caption) label = defaultLabel({ kind: "special", specialName: name })
      var specialStyle = styleOf(raw)
      specials.push({
        id: 0,
        kind: "special",
        specialName: name,
        title: cleanTitle(raw.title, prettyTitle(name)),
        label: label,
        caption: caption,
        font: font,
        fontPx: fontPx,
        color: specialStyle.color,
        bold: specialStyle.bold,
        italic: specialStyle.italic
      })
      continue
    }
    if (numbered.length >= MAX_NUMBERED) continue
    var id = Math.round(Number(raw.id))
    if (!(id >= 1) || id > MAX_NUMBERED || usedId[id]) continue
    usedId[id] = true
    if (!label && !caption) label = dotForId(id)
    var numberedStyle = styleOf(raw)
    numbered.push({
      id: id,
      kind: "ws",
      label: label,
      caption: caption,
      font: font,
      fontPx: fontPx,
      specialName: "",
      title: "",
      color: numberedStyle.color,
      bold: numberedStyle.bold,
      italic: numberedStyle.italic
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
      caption: "",
      font: DEFAULT_FONT,
      fontPx: DEFAULT_PX,
      specialName: "",
      title: "",
      color: "",
      bold: false,
      italic: false
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
      slot.caption || "",
      slot.font,
      slot.fontPx,
      slot.specialName || "",
      slot.title || "",
      slot.color || "",
      slot.bold ? 1 : 0,
      slot.italic ? 1 : 0
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
      caption: "",
      font: DEFAULT_FONT,
      fontPx: DEFAULT_PX,
      specialName: "",
      title: "",
      color: "",
      bold: false,
      italic: false
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

// 1-based place among numbered rows. Specials have no number.
function orderIndex(slots, index) {
  var list = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= list.length || list[i].kind === "special") return 0
  var n = 0
  for (var k = 0; k <= i; k++) if (list[k].kind !== "special") n++
  return n
}

// Move a numbered row to a workspace number. The id stays with the row
// until Apply renames the Hyprland workspace.
function moveToOrder(slots, index, order) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length || cur[i].kind === "special")
    return { slots: cur, index: Math.max(0, Math.min(i, cur.length - 1)) }
  var specials = []
  var numbered = []
  var pos = 0
  for (var k = 0; k < cur.length; k++) {
    if (cur[k].kind === "special") specials.push(cur[k])
    else {
      if (k === i) pos = numbered.length
      numbered.push(cur[k])
    }
  }
  var raw = String(order === undefined || order === null ? "" : order).replace(/[^0-9]/g, "")
  var dest = Math.round(Number(raw))
  if (!(dest >= 1)) return { slots: cur, index: i }
  if (dest > numbered.length) dest = numbered.length
  var destPos = dest - 1
  if (destPos === pos) return { slots: cur, index: i }
  var slot = numbered[pos]
  numbered.splice(pos, 1)
  numbered.splice(destPos, 0, slot)
  return { slots: sanitize(specials.concat(numbered)), index: specials.length + destPos }
}

function orderPairs(slots) {
  var list = sanitize(slots)
  var pairs = []
  var n = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i].kind === "special") continue
    n++
    if (list[i].id !== n) pairs.push({ from: list[i].id, to: n })
  }
  return pairs
}

function alignSlots(slots) {
  var list = sanitize(slots)
  var n = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i].kind === "special") continue
    n++
    list[i].id = n
  }
  return list
}

// Safe workspace.change_id order. A cycle parks the first id on a free
// temporary workspace so an in-use id is never the destination.
function changeIdSteps(pairs, liveIds) {
  var dest = {}
  var froms = []
  var used = {}
  var live = asArray(liveIds)
  for (var u = 0; u < live.length; u++) {
    var id = Math.round(Number(live[u]))
    if (id >= 1) used[id] = true
  }
  var list = asArray(pairs)
  for (var i = 0; i < list.length; i++) {
    if (!list[i]) continue
    var from = Math.round(Number(list[i].from))
    var to = Math.round(Number(list[i].to))
    if (!(from >= 1) || !(to >= 1) || from === to || dest[from]) continue
    dest[from] = to
    froms.push(from)
    used[from] = true
    used[to] = true
  }
  var temp = 99
  while (used[temp]) temp++
  var seen = {}
  var steps = []
  for (var s = 0; s < froms.length; s++) {
    if (seen[froms[s]]) continue
    var chain = []
    var at = froms[s]
    var guard = 0
    while (dest[at] && !seen[at] && guard < 32) {
      seen[at] = true
      chain.push(at)
      var next = dest[at]
      if (next === chain[0]) break
      if (!dest[next]) break
      at = next
      guard++
    }
    if (!chain.length) continue
    var lastDest = dest[chain[chain.length - 1]]
    if (lastDest === chain[0]) {
      steps.push({ from: chain[0], to: temp })
      for (var c = chain.length - 1; c >= 1; c--)
        steps.push({ from: chain[c], to: dest[chain[c]] })
      steps.push({ from: temp, to: dest[chain[0]] })
    } else {
      for (var a = chain.length - 1; a >= 0; a--)
        steps.push({ from: chain[a], to: dest[chain[a]] })
    }
  }
  return steps
}

// Rename plan for Apply. Steps only include workspaces that exist. If a
// destination is already taken by a workspace this plan does not move, the
// ids stay as they are.
function commitOrder(slots, liveIds) {
  var cur = sanitize(slots)
  var pairs = orderPairs(cur)
  if (!pairs.length) return { slots: cur, steps: [] }
  var steps = changeIdSteps(pairs, liveIds)
  var live = {}
  var ids = asArray(liveIds)
  for (var i = 0; i < ids.length; i++) {
    var id = Math.round(Number(ids[i]))
    if (id >= 1) live[id] = true
  }
  var ok = []
  for (var s = 0; s < steps.length; s++) {
    var step = steps[s]
    var fromLive = !!live[step.from]
    if (fromLive && live[step.to]) return { slots: cur, steps: [] }
    if (fromLive) {
      ok.push({ from: step.from, to: step.to })
      live[step.to] = true
      delete live[step.from]
    }
  }
  return { slots: alignSlots(cur), steps: ok }
}

function mapThrough(steps, id) {
  var cur = Math.round(Number(id))
  var list = asArray(steps)
  for (var i = 0; i < list.length; i++) {
    if (!list[i]) continue
    if (Math.round(Number(list[i].from)) === cur) cur = Math.round(Number(list[i].to))
  }
  return cur
}

function invertSteps(steps) {
  var list = asArray(steps)
  var out = []
  for (var i = list.length - 1; i >= 0; i--) {
    if (!list[i]) continue
    out.push({
      from: Math.round(Number(list[i].to)),
      to: Math.round(Number(list[i].from))
    })
  }
  return out
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
      label: slot.label,
      caption: slot.caption || "",
      font: slot.font,
      fontPx: slot.fontPx,
      color: slot.color || "",
      bold: !!slot.bold,
      italic: !!slot.italic
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
    label: slot.label,
    caption: slot.caption || "",
    font: slot.font,
    fontPx: slot.fontPx,
    specialName: "",
    title: "",
    color: slot.color || "",
    bold: !!slot.bold,
    italic: !!slot.italic
  })
  var cleaned = sanitize(cur)
  return { slots: cleaned, index: cleaned.length - 1 }
}

function setFace(slots, index, label, font, fontPx, caption, bold, italic, color) {
  var cur = sanitize(slots)
  var i = Math.round(Number(index))
  if (i < 0 || i >= cur.length) return cur
  var slot = cur[i]
  if (caption !== undefined && caption !== null) slot.caption = clampText(caption, CAPTION_LIMIT)
  if (label !== undefined && label !== null) slot.label = clampSymbol(label)
  if (font !== undefined && font !== null) slot.font = clampText(font, FONT_LIMIT)
  if (fontPx !== undefined && fontPx !== null) slot.fontPx = clampFontPx(fontPx)
  if (bold !== undefined && bold !== null) slot.bold = truthy(bold)
  if (italic !== undefined && italic !== null) slot.italic = truthy(italic)
  if (color !== undefined && color !== null) slot.color = clampColor(color)
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

function builtinEmoji() {
  return [
    { e: "\uD83D\uDE00", k: "grinning face smile happy" },
    { e: "\uD83D\uDE0A", k: "smiling face blush" },
    { e: "\uD83D\uDE0E", k: "smiling face sunglasses cool" },
    { e: "\uD83D\uDCAC", k: "speech balloon comment chat" },
    { e: "\u2B50", k: "star" },
    { e: "\uD83D\uDD25", k: "fire hot" },
    { e: "\u2764\uFE0F", k: "heart red love" },
    { e: "\uD83D\uDCBB", k: "laptop computer coding" },
    { e: "\uD83D\uDCDD", k: "memo note" },
    { e: "\uD83D\uDCC1", k: "folder file" },
    { e: "\uD83C\uDFB5", k: "music note" },
    { e: "\uD83C\uDFAE", k: "game controller gaming" },
    { e: "\uD83D\uDCCC", k: "pushpin pin" },
    { e: "\uD83D\uDFE1", k: "yellow circle" },
    { e: "\uD83D\uDD35", k: "blue circle" },
    { e: "\uD83D\uDFE2", k: "green circle" },
    { e: "\uD83D\uDD34", k: "red circle" },
    { e: "\uD83D\uDFE0", k: "orange circle" },
    { e: "\uD83D\uDFE3", k: "purple circle" },
    { e: "\u26AA", k: "white circle" },
    { e: "\u26AB", k: "black circle" }
  ]
}

// limit of 0 returns the whole catalog. The list starts with faces, so a
// small cap looks like only faces are installed.
function filterEmoji(catalog, query, limit) {
  var values = asArray(catalog)
  var needle = String(query === undefined || query === null ? "" : query).replace(/^\s+|\s+$/g, "").toLowerCase()
  var max = 0
  if (!(limit === undefined || limit === null || limit === "")) {
    max = Math.round(Number(limit))
    if (!(max >= 0)) max = 0
  }
  var out = []
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    var symbol = item && item.e ? String(item.e) : ""
    if (!symbol || symbol.length > 16) continue
    var keys = String((item && item.k) || "").toLowerCase()
    if (needle && keys.indexOf(needle) < 0 && symbol.toLowerCase().indexOf(needle) < 0) continue
    out.push(symbol)
    if (max >= 1 && out.length >= max) break
  }
  return out
}

function rowActions(slot) {
  var actions = ["up", "down", "special", "remove", "label", "clear", "emoji", "caption", "clearCaption", "font", "bold", "italic", "sizeDown", "sizeUp"]
  if (isSpecial(slot)) {
    actions.unshift("title")
    actions.push("workspace")
  } else actions.unshift("order")
  return actions
}

function occupied(workspace) {
  return !!(workspace && (workspace.occupied || workspace.active || workspace.focused))
}

function faceEntry(slot, selected, occupiedFlag) {
  var special = slot.kind === "special"
  var style = styleOf(slot)
  return {
    id: special ? 0 : slot.id,
    isSpecial: special,
    specialName: special ? slot.specialName : "",
    title: special ? slot.title : String(slot.id),
    label: slot.label || "",
    caption: slot.caption || "",
    font: slot.font,
    fontPx: slot.fontPx,
    color: style.color,
    bold: style.bold,
    italic: style.italic,
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

// Approximate advance of a label, in em. Emoji count as about one em.
// ASCII is a little wide so the estimate does not clip the last letter.
function textUnits(text) {
  var units = 0
  var s = String(text || "")
  for (var i = 0; i < s.length; i++) {
    var code = s.charCodeAt(i)
    if (code >= 0xD800 && code <= 0xDBFF) {
      units += 1.15
      if (i + 1 < s.length && s.charCodeAt(i + 1) >= 0xDC00 && s.charCodeAt(i + 1) <= 0xDFFF) i++
      continue
    }
    if (code === 0xFE0F || code === 0x200D) continue
    if (code <= 0x20) units += 0.33
    else if (code < 0x80) units += 0.62
    else units += 1
  }
  return units
}

// One space in front of the workspace number. Narrow faces still get a gap.
function textSpace(px) {
  var size = Math.round(Number(px))
  if (!(size >= 1)) size = 1
  return Math.max(Math.round(size * 0.55), 6)
}

function gapSetting(value) {
  if (value === undefined || value === null || value === "") return -1
  var n = Math.round(Number(value))
  if (!(n >= 0 && n <= 48)) return -1
  return n
}

// The shell copy can lose a caption during a reload. Keep the saved words.
function mergeKeptText(shellSlots, sidecarSlots) {
  var shell = sanitize(shellSlots)
  var side = sanitize(sidecarSlots)
  if (!shell.length || !side.length) return null
  var changed = false
  for (var i = 0; i < shell.length; i++) {
    var match = null
    for (var j = 0; j < side.length; j++) {
      var sameKind = shell[i].kind === side[j].kind
      if (!sameKind) continue
      if (shell[i].kind === "special") {
        if (shell[i].specialName === side[j].specialName) match = side[j]
      } else if (shell[i].id === side[j].id) match = side[j]
    }
    if (!match) continue
    if (!shell[i].caption && match.caption) {
      shell[i].caption = match.caption
      changed = true
    }
  }
  return changed ? shell : null
}

function chipLayout(spec) {
  var src = spec || {}
  var vertical = !!src.vertical
  var inner = Math.round(Number(src.inner))
  if (!(inner >= 12)) inner = 24
  var requested = Math.round(Number(src.fontPx))
  if (!(requested >= 8 && requested <= 32)) requested = DEFAULT_PX
  var showNumber = !!src.showNumber
  var caption = clampText(src.caption, CAPTION_LIMIT)
  var showCaption = caption.length > 0
  var showIcon = !showCaption || String(src.label || "").length > 0
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
  if (vertical && showNumber && showIcon) {
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

  if (!showIcon) icon = 0

  if (showCaption) {
    var captionPx = Math.min(requested, budget)
    var along = Math.max(captionPx, Math.ceil(textUnits(caption) * captionPx) + 2)
    var partGap = 2
    var numberWCap = showNumber ? numberWidth(number) : 0
    var numberGap = showNumber ? textSpace(captionPx) : 0
    if (!vertical) {
      var parts = (showIcon ? 1 : 0) + 1 + (showNumber ? 1 : 0)
      var gaps = partGap * Math.max(0, parts - 1 - (showNumber ? 1 : 0)) + numberGap
      return {
        stack: false,
        rotateCaption: false,
        showIcon: showIcon,
        showCaption: true,
        icon: icon,
        number: showNumber ? number : 0,
        numberW: numberWCap,
        caption: captionPx,
        captionAlong: along,
        gap: partGap,
        numberGap: numberGap,
        width: (showIcon ? icon : 0) + along + numberWCap + gaps + pad,
        height: inner
      }
    }
    var top = 0
    if (showIcon || showNumber) {
      if (stack && showIcon && showNumber) top = icon + gap + number
      else top = Math.max(icon, showNumber ? number : 0)
    }
    return {
      stack: stack,
      rotateCaption: true,
      showIcon: showIcon,
      showCaption: true,
      icon: icon,
      number: showNumber ? number : 0,
      numberW: numberWCap,
      caption: captionPx,
      captionAlong: along,
      gap: partGap,
      numberGap: 0,
      width: inner,
      height: top + (top ? partGap : 0) + along + pad
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
    rotateCaption: false,
    showIcon: true,
    showCaption: false,
    icon: icon,
    number: showNumber ? number : 0,
    numberW: numberW,
    caption: 0,
    captionAlong: 0,
    gap: showNumber ? gap : 0,
    numberGap: showNumber ? gap : 0,
    width: width,
    height: height
  }
}

// Highlight chrome for one pill. The default outline is nearly square.
// Respecting the theme uses Hyprland rounding plus the theme border.
// The gap stays at least as wide as that stroke so neighbors do not merge.
function chipChrome(spec) {
  var src = spec || {}
  var theme = !!src.respectTheme
  var hot = !!src.hot
  var selected = !!src.selected
  var shortSide = Math.round(Number(src.shortSide))
  if (!(shortSide >= 1)) shortSide = 1

  function px(value, fallback) {
    var n = Math.round(Number(value))
    return n >= 0 ? n : fallback
  }

  var square = px(src.squareRadius, 2)
  var radius = theme ? px(src.cornerRadius, 0) : square
  var cap = Math.floor(shortSide / 2)
  if (radius > cap) radius = cap
  if (radius < 0) radius = 0

  var hoverBorder = px(src.hoverBorder, 1)
  var focusBorder = px(src.focusBorder, hoverBorder)
  var selectedBorder = px(src.selectedBorder, 0)
  var reserve = theme ? Math.max(hoverBorder, focusBorder, selectedBorder, 1) : 1
  var border = 0
  if (hot || selected) {
    if (!theme) border = 1
    else if (selected) border = selectedBorder >= 1 ? selectedBorder : Math.max(focusBorder, 1)
    else border = Math.max(hoverBorder, 1)
  }
  var gap = px(src.gap, 2)
  if (gap < reserve) gap = reserve
  return {
    radius: radius,
    border: border,
    gap: gap,
    inset: Math.max(0, reserve - 1)
  }
}

function truthy(value) {
  if (value === true || value === 1) return true
  var text = String(value === undefined || value === null ? "" : value).toLowerCase()
  return text === "true" || text === "1" || text === "on" || text === "yes"
}

function exportText(src) {
  var s = src || {}
  var showOnly = s.showOnlyActive
  var numbers = s.showNumbers
  var body = {
    plugin: "crome.workspaces",
    version: 1,
    showOnlyActive: showOnly === undefined || showOnly === null ? true : !!showOnly,
    respectTheme: !!s.respectTheme,
    showNumbers: numbers === undefined || numbers === null ? true : !!numbers,
    workspaceGap: gapSetting(s.workspaceGap),
    slots: sanitize(s.slots)
  }
  return JSON.stringify(body, null, 2) + "\n"
}

function importSettings(text) {
  var raw = String(text === undefined || text === null ? "" : text)
  if (!raw || raw.length > 262144) return null
  var parsed = null
  try { parsed = JSON.parse(raw) } catch (e) { return null }
  if (!parsed || typeof parsed !== "object") return null
  if (parsed.plugin && parsed.plugin !== "crome.workspaces") return null
  var slots = parsed.slots
  if (!slots || typeof slots.length !== "number") return null
  var clean = sanitize(slots)
  if (!clean.length) return null
  var showOnly = parsed.showOnlyActive
  var numbers = parsed.showNumbers
  return {
    showOnlyActive: showOnly === undefined || showOnly === null ? true : truthy(showOnly),
    respectTheme: truthy(parsed.respectTheme),
    showNumbers: numbers === undefined || numbers === null ? true : truthy(numbers),
    workspaceGap: gapSetting(parsed.workspaceGap),
    slots: clean
  }
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
    orderIndex: orderIndex,
    moveToOrder: moveToOrder,
    orderPairs: orderPairs,
    alignSlots: alignSlots,
    changeIdSteps: changeIdSteps,
    commitOrder: commitOrder,
    mapThrough: mapThrough,
    invertSteps: invertSteps,
    canRemove: canRemove,
    removeAt: removeAt,
    canSetSpecial: canSetSpecial,
    setSpecial: setSpecial,
    setFace: setFace,
    stepSize: stepSize,
    setMeta: setMeta,
    stepFont: stepFont,
    rowActions: rowActions,
    builtinEmoji: builtinEmoji,
    filterEmoji: filterEmoji,
    visibleEntries: visibleEntries,
    relativeActions: relativeActions,
    activateActions: activateActions,
    focusDispatch: focusDispatch,
    toggleDispatch: toggleDispatch,
    chipLayout: chipLayout,
    chipChrome: chipChrome,
    textSpace: textSpace,
    gapSetting: gapSetting,
    mergeKeptText: mergeKeptText,
    truthy: truthy,
    numberedFloor: numberedFloor,
    clampColor: clampColor,
    exportText: exportText,
    importSettings: importSettings
  }
}
