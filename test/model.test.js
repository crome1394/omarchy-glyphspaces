const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../WorkspaceModel.js")

test("manifest defaults are the eight emoji workspaces", () => {
  const manifest = require("../manifest.json")
  const defaults = manifest.barWidget.defaults
  assert.equal(defaults.showOnlyActive, true)
  assert.deepEqual(defaults.slots, Model.defaultSlots())
})

test("defaults are eight distinct colored dots", () => {
  const slots = Model.defaultSlots()
  assert.equal(slots.length, 8)
  assert.deepEqual(slots.map((slot) => slot.id), [1, 2, 3, 4, 5, 6, 7, 8])
  assert.equal(new Set(slots.map((slot) => slot.label)).size, 8)
  assert.equal(slots[0].label, "\u{1F7E1}")
  assert.equal(slots[1].label, "\u{1F535}")
  assert.equal(slots[2].label, "\u{1F7E2}")
  assert.equal(slots[0].font, "Noto Color Emoji")
  assert.equal(slots[0].fontPx, 14)
  assert.equal(slots.some((slot) => slot.kind === "special"), false)
})

test("fresh settings stay on the colored row", () => {
  const rows = Model.rowsFromSettings({ showMagic: true })
  assert.equal(rows.length, 8)
  assert.equal(rows.some((slot) => slot.kind === "special"), false)
})

test("saved rows keep order and a legacy magic moves in front once", () => {
  const rows = Model.rowsFromSettings({
    showMagic: true,
    specialName: "magic;touch /tmp/x",
    magicIcon: "\u2728",
    slots: [
      { id: 2, label: "fs", font: "Inter", fontPx: 18 },
      { id: 2, label: "dup" },
      { id: 0, label: "nope" },
      { id: 1, label: "", fontPx: 7 }
    ]
  })
  assert.equal(rows[0].kind, "special")
  assert.equal(rows[0].specialName, "magictouchtmpx")
  assert.equal(rows[0].label, "\u2728")
  assert.deepEqual(rows.slice(1).map((slot) => slot.id), [2, 1])
  assert.equal(rows[1].label, "fs")
  assert.equal(rows[1].fontPx, 18)
  assert.equal(rows[2].label, Model.dotForId(1))
  assert.equal(rows[2].fontPx, 0)
  const again = Model.rowsFromSettings({ showMagic: true, slots: rows })
  assert.equal(again.filter((slot) => slot.kind === "special").length, 1)
})

test("sanitize keeps one special in front", () => {
  const rows = Model.sanitize([
    { id: 3, kind: "ws", label: "\u{1F7E2}" },
    { kind: "magic", label: "\u{1F9F9}" },
    { kind: "special", specialName: "scratchpad", title: "Notes", label: "\u270D\uFE0F" },
    { kind: "special", specialName: "magic", label: "other" }
  ])
  assert.deepEqual(rows.map((slot) => slot.kind === "special" ? slot.specialName : slot.id), [
    "magic", 3
  ])
  assert.equal(rows[0].title, "Magic")
})

test("resize, move, and remove stay inside each group", () => {
  let slots = Model.resizeNumbered(Model.defaultSlots(3), 4)
  assert.deepEqual(slots.map((slot) => slot.id), [1, 2, 3, 4])
  const made = Model.setSpecial(slots, 1, true)
  slots = made.slots
  assert.equal(slots[made.index].specialName, "s2")
  assert.equal(slots[0].kind, "special")
  assert.equal(Model.canMove(slots, 0, 1), false)
  assert.deepEqual(Model.moveWithin(slots, 0, 1).map((slot) => slot.kind), ["special", "ws", "ws", "ws"])
  slots = Model.moveWithin(slots, 2, -1)
  assert.deepEqual(slots.filter((slot) => slot.kind === "ws").map((slot) => slot.id), [3, 1, 4])
  assert.equal(Model.removeAt([{ id: 1, kind: "ws", label: "\u{1F7E1}" }], 0).length, 1)
  const removed = Model.removeAt(slots, 0)
  assert.equal(removed.some((slot) => slot.kind === "special"), false)
})

test("clearing a special returns it to the end of the numbered row", () => {
  const made = Model.setSpecial(Model.defaultSlots(3), 0, true)
  assert.equal(Model.canSetSpecial(made.slots, made.index), true)
  const back = Model.setSpecial(made.slots, made.index, false)
  assert.equal(back.slots[back.index].kind, "ws")
  assert.equal(back.slots[back.index].id, 1)
  assert.equal(back.index, back.slots.length - 1)
})

test("names, titles, fonts, and sizes stay inside their limits", () => {
  const made = Model.setSpecial(Model.defaultSlots(2), 1, true)
  let slots = Model.setMeta(made.slots, made.index, "Communication", "magic")
  assert.equal(slots[0].title, "Communication")
  assert.equal(slots[0].specialName, "magic")
  slots = Model.setMeta(slots, 0, "Communication", "magic;rm -rf /")
  assert.equal(slots[0].specialName, "magicrm-rf")
  assert.equal(Model.canSetSpecial(slots, 1), false)
  const blocked = Model.setSpecial(slots, 1, true)
  assert.equal(blocked.slots.filter((slot) => slot.kind === "special").length, 1)
  assert.equal(blocked.slots[0].specialName, "magicrm-rf")
  assert.equal(blocked.slots[1].kind, "ws")
  slots = Model.setFace(Model.defaultSlots(1), 0, "", "Inter", 40)
  assert.equal(slots[0].label, Model.dotForId(1))
  assert.equal(slots[0].font, "Inter")
  assert.equal(slots[0].fontPx, 0)
  slots = Model.stepSize(slots, 0, -1)
  assert.equal(slots[0].fontPx, 13)
  assert.equal(Model.stepFont("Inter", 1, ["Inter"]), "")
  assert.equal(Model.stepFont("", 1, ["Inter"]), "Inter")
  assert.equal(Model.effectivePx(0), 14)
})

test("the bar hides empty pills and keeps extras after the row", () => {
  const slots = [
    { kind: "special", specialName: "magic", title: "Magic", label: "\uD83E\uDE84", font: "", fontPx: 0 },
    { id: 1, kind: "ws", label: Model.dotForId(1), font: "Noto Color Emoji", fontPx: 14 },
    { id: 3, kind: "ws", label: Model.dotForId(3), font: "Noto Color Emoji", fontPx: 14 }
  ]
  const shown = Model.visibleEntries({
    slots: slots,
    workspaces: [
      { id: 1, occupied: false },
      { id: 3, occupied: true, focused: true },
      { id: 8, occupied: true }
    ],
    focusedId: 3,
    showOnlyActive: true,
    activeSpecial: "magic"
  })
  assert.deepEqual(shown.map((entry) => entry.isSpecial ? entry.specialName : entry.id), ["magic", 3, 8])
  assert.equal(shown[0].selected, true)
  assert.equal(shown[1].selected, false)
  assert.equal(shown[1].showNumber, true)
  assert.equal(shown[2].label, Model.dotForId(8))
})

test("an empty desktop still shows the focused pill", () => {
  const shown = Model.visibleEntries({
    slots: Model.defaultSlots(3),
    workspaces: [],
    focusedId: 2,
    showOnlyActive: true,
    activeSpecial: ""
  })
  assert.deepEqual(shown.map((entry) => entry.id), [2])
  assert.equal(shown[0].selected, true)
})

test("scroll walks the special, then numbered workspaces", () => {
  const slots = Model.sanitize([
    { kind: "special", specialName: "magic", label: "\uD83E\uDE84" },
    { kind: "special", specialName: "scratchpad", label: "\u270D\uFE0F" },
    { id: 1, kind: "ws", label: Model.dotForId(1) },
    { id: 4, kind: "ws", label: Model.dotForId(4) }
  ])
  assert.equal(slots.filter((slot) => slot.kind === "special").length, 1)
  const onMagic = { slots: slots, activeSpecial: "magic", focusedId: 4 }
  assert.deepEqual(Model.relativeActions(onMagic, 1), [
    "hl.dsp.workspace.toggle_special('magic')"
  ])
  assert.deepEqual(Model.relativeActions(onMagic, -1), [])
  assert.deepEqual(Model.relativeActions({ slots: slots, activeSpecial: "", focusedId: 1 }, -1), [
    "hl.dsp.workspace.toggle_special('magic')"
  ])
  assert.deepEqual(Model.relativeActions({ slots: slots, activeSpecial: "", focusedId: 4 }, -1), [
    "hl.dsp.focus({ workspace = \"-1\" })"
  ])
  assert.deepEqual(Model.relativeActions({ slots: [{ id: 1, kind: "ws" }], activeSpecial: "", focusedId: 1 }, -1), [])
  assert.equal(Model.numberedFloor(slots), 1)
})

test("clicks close the open special before focusing a numbered workspace", () => {
  const state = { activeSpecial: "magic", focusedId: 4 }
  assert.deepEqual(Model.activateActions({ isSpecial: true, specialName: "scratchpad" }, state), [
    "hl.dsp.workspace.toggle_special('magic')",
    "hl.dsp.workspace.toggle_special('scratchpad')"
  ])
  assert.deepEqual(Model.activateActions({ isSpecial: true, specialName: "magic" }, state), [
    "hl.dsp.workspace.toggle_special('magic')"
  ])
  assert.deepEqual(Model.activateActions({ isSpecial: false, id: 4 }, state), [
    "hl.dsp.workspace.toggle_special('magic')"
  ])
  assert.deepEqual(Model.activateActions({ isSpecial: false, id: 2 }, { activeSpecial: "", focusedId: 4 }), [
    "hl.dsp.focus({ workspace = \"2\" })"
  ])
  const nasty = Model.toggleDispatch("magic;rm -rf /")
  assert.match(nasty, /^hl\.dsp\.workspace\.toggle_special\('[A-Za-z0-9_-]*'\)$/)
  assert.equal(nasty.includes(";"), false)
  assert.equal(nasty.includes("/"), false)
  assert.equal(Model.focusDispatch("2;touch"), "hl.dsp.focus({ workspace = \"1\" })")
})

test("a numbered row takes its place as the workspace number", () => {
  const slots = Model.sanitize([
    { kind: "special", specialName: "communications", title: "Communications", label: "\u{1F4AC}" },
    { id: 2, kind: "ws", label: "\u{1F535}", caption: "Staging" },
    { id: 1, kind: "ws", label: "\u{1F7E1}", caption: "Coding" },
    { id: 3, kind: "ws", label: "\u{1F7E2}", caption: "Gaming" }
  ])
  assert.equal(Model.orderIndex(slots, 0), 0)
  assert.equal(Model.orderIndex(slots, 1), 1)
  assert.deepEqual(Model.orderPairs(slots), [{ from: 2, to: 1 }, { from: 1, to: 2 }])
  const plan = Model.commitOrder(slots, [1, 2, 3])
  assert.deepEqual(plan.slots.filter((slot) => slot.kind === "ws").map((slot) => slot.id), [1, 2, 3])
  assert.equal(plan.slots[1].caption, "Staging")
  assert.equal(plan.slots[2].caption, "Coding")
  const live = { 1: "coding", 2: "staging", 3: "gaming" }
  for (const step of plan.steps) {
    assert.equal(live[step.to], undefined)
    live[step.to] = live[step.from]
    delete live[step.from]
  }
  assert.equal(live[1], "staging")
  assert.equal(live[2], "coding")
  assert.equal(live[3], "gaming")
  assert.equal(Model.mapThrough(plan.steps, 2), 1)
  assert.equal(Model.mapThrough(plan.steps, 1), 2)
  assert.deepEqual(Model.invertSteps(plan.steps).length, plan.steps.length)
  const typed = Model.moveToOrder(slots, 2, "1")
  assert.equal(typed.index, 1)
  assert.equal(typed.slots[1].caption, "Coding")
  assert.equal(typed.slots[1].id, 1)
  const back = Model.commitOrder(typed.slots, [1, 2, 3])
  assert.equal(back.steps.length, 0)
  const parked = Model.commitOrder(Model.sanitize([
    { id: 2, kind: "ws", label: "b" },
    { id: 1, kind: "ws", label: "a" }
  ]), [1, 2, 99])
  assert.equal(parked.steps.some((step) => step.from === 100 || step.to === 100), true)
  assert.equal(parked.steps.some((step) => step.to === 99), false)
  const blocked = Model.commitOrder(Model.sanitize([
    { id: 1, kind: "ws", label: "a" },
    { id: 3, kind: "ws", label: "c" }
  ]), [1, 2, 3])
  assert.deepEqual(blocked.slots.map((slot) => slot.id), [1, 3])
  assert.equal(blocked.steps.length, 0)
  const shifted = Model.commitOrder(Model.sanitize([
    { id: 1, kind: "ws", label: "a" },
    { id: 3, kind: "ws", label: "c" }
  ]), [1, 3])
  assert.deepEqual(shifted.slots.map((slot) => slot.id), [1, 2])
  assert.deepEqual(shifted.steps, [{ from: 3, to: 2 }])
})

test("the dot stays beside the number on every bar edge that can hold it", () => {
  const side = Model.chipLayout({ vertical: true, inner: 24, fontPx: 14, showNumber: true })
  assert.equal(side.stack, false)
  assert.equal(side.width, 24)
  assert.ok(side.icon + side.gap + side.numberW <= 20)
  const thin = Model.chipLayout({ vertical: true, inner: 16, fontPx: 14, showNumber: true })
  assert.equal(thin.stack, true)
  assert.ok(thin.height > thin.icon)
  const top = Model.chipLayout({ vertical: false, inner: 22, fontPx: 14, showNumber: true })
  assert.equal(top.stack, false)
  assert.equal(top.height, 22)
  assert.ok(top.width > top.icon)
  const wide = Model.chipLayout({ vertical: true, inner: 64, fontPx: 14, showNumber: true })
  assert.equal(wide.stack, false)
  assert.equal(Model.truthy("true"), true)
  assert.equal(Model.truthy("no"), false)
  assert.deepEqual(Model.rowActions({ kind: "ws" }).slice(0, 3), ["order", "up", "down"])
  assert.equal(Model.rowActions({ kind: "ws" }).indexOf("fontPrev"), -1)
  assert.equal(Model.rowActions({ kind: "special" })[0], "title")
  assert.equal(Model.rowActions({ kind: "special" }).indexOf("workspace") > 0, true)
  assert.equal(Model.rowActions({ kind: "ws" }).indexOf("caption") > 0, true)
})

test("a workspace can keep a symbol, a text label, or only the text", () => {
  let slots = Model.setFace(Model.defaultSlots(1), 0, null, "Inter", 16, "Coding")
  assert.equal(slots[0].label, Model.dotForId(1))
  assert.equal(slots[0].caption, "Coding")
  assert.equal(slots[0].font, "Inter")
  assert.equal(slots[0].fontPx, 16)
  assert.notEqual(Model.signature(Model.defaultSlots(1)), Model.signature(slots))
  slots = Model.setFace(slots, 0, "", null, null, null)
  assert.equal(slots[0].label, "")
  assert.equal(slots[0].caption, "Coding")
  slots = Model.setFace(slots, 0, null, null, null, "  Code\ning  ")
  assert.equal(slots[0].caption, "Code ing")
  const phrase = Model.setFace(Model.defaultSlots(1), 0, "", null, null, "\u{1F7E1} Coding")
  assert.equal(phrase[0].label, "")
  assert.equal(phrase[0].caption, "\u{1F7E1} Coding")
  const trimmed = Model.setFace(Model.defaultSlots(1), 0, null, null, null, "abcdefghijklmnopqrstuvwxyz")
  assert.equal(trimmed[0].caption, "abcdefghijklmnopqrstuvwx")
  slots = Model.setFace(phrase, 0, null, null, null, "")
  assert.equal(slots[0].caption, "")
  assert.equal(slots[0].label, Model.dotForId(1))
  const legacy = Model.sanitize([{ id: 3, kind: "ws", label: "files" }])
  assert.equal(legacy[0].label, "fil")
  const emoji = Model.setFace(Model.defaultSlots(1), 0, "\u{1F7E1}", null, null)
  assert.equal(emoji[0].label, "\u{1F7E1}")
  const clipped = Model.setFace(Model.defaultSlots(1), 0, "abcd", null, null)
  assert.equal(clipped[0].label, "abc")
  assert.equal(legacy[0].caption, "")
  const made = Model.setSpecial(Model.setFace(Model.defaultSlots(2), 1, "", null, null, "Notes"), 1, true)
  assert.equal(made.slots[0].kind, "special")
  assert.equal(made.slots[0].caption, "Notes")
  assert.equal(made.slots[0].label, "")
  const shown = Model.visibleEntries({
    slots: phrase,
    workspaces: [{ id: 1, occupied: true, focused: true }],
    focusedId: 1,
    showOnlyActive: true
  })
  assert.equal(shown[0].label, "")
  assert.equal(shown[0].caption, "\u{1F7E1} Coding")
  assert.equal(shown[0].showNumber, true)
})

test("a text label widens a top bar and reads downward on a side bar", () => {
  const plain = Model.chipLayout({ vertical: false, inner: 22, fontPx: 14, showNumber: true, label: "\u{1F7E1}" })
  const named = Model.chipLayout({
    vertical: false,
    inner: 22,
    fontPx: 14,
    showNumber: true,
    label: "\u{1F7E1}",
    caption: "Coding"
  })
  assert.equal(named.rotateCaption, false)
  assert.equal(named.height, 22)
  assert.ok(named.width > plain.width)
  assert.equal(named.showIcon, true)
  const words = Model.chipLayout({
    vertical: false,
    inner: 22,
    fontPx: 14,
    showNumber: true,
    label: "",
    caption: "Coding"
  })
  assert.equal(words.showIcon, false)
  assert.ok(words.width < named.width)
  const side = Model.chipLayout({
    vertical: true,
    inner: 24,
    fontPx: 14,
    showNumber: true,
    label: "\u{1F7E1}",
    caption: "Coding"
  })
  assert.equal(side.rotateCaption, true)
  assert.equal(side.width, 24)
  assert.ok(side.height > side.captionAlong)
  assert.ok(side.captionAlong > side.caption)
  const spaced = Model.chipLayout({
    vertical: false,
    inner: 28,
    fontPx: 18,
    showNumber: true,
    label: "\u{1F7E1}",
    caption: "Coding"
  })
  assert.ok(spaced.numberGap >= 6)
  assert.ok(spaced.width >= spaced.captionAlong + spaced.numberGap)
})

test("a saved caption comes back when the bar copy lost it", () => {
  const shell = Model.sanitize([{ id: 1, kind: "ws", label: "\u{1F7E1}", caption: "" }])
  const side = Model.sanitize([{ id: 1, kind: "ws", label: "\u{1F7E1}", caption: "Coding" }])
  const kept = Model.mergeKeptText(shell, side)
  assert.equal(kept[0].caption, "Coding")
  assert.equal(Model.mergeKeptText(side, side), null)
  assert.equal(Model.gapSetting(""), -1)
  assert.equal(Model.gapSetting(8), 8)
})

test("the highlight stays square unless the theme owns the rounding", () => {
  const square = Model.chipChrome({
    respectTheme: false,
    selected: true,
    shortSide: 24,
    squareRadius: 2,
    cornerRadius: 12,
    hoverBorder: 1,
    focusBorder: 1,
    selectedBorder: 0,
    gap: 2
  })
  assert.equal(square.radius, 2)
  assert.equal(square.border, 1)
  assert.equal(square.gap, 2)
  assert.equal(square.inset, 0)
  const themed = Model.chipChrome({
    respectTheme: true,
    selected: true,
    shortSide: 24,
    squareRadius: 2,
    cornerRadius: 12,
    hoverBorder: 2,
    focusBorder: 2,
    selectedBorder: 0,
    gap: 2
  })
  assert.equal(themed.radius, 12)
  assert.equal(themed.border, 2)
  assert.equal(themed.gap, 2)
  assert.equal(themed.inset, 1)
  const thick = Model.chipChrome({
    respectTheme: true,
    hot: false,
    selected: false,
    shortSide: 10,
    cornerRadius: 8,
    hoverBorder: 3,
    focusBorder: 3,
    selectedBorder: 3,
    gap: 2
  })
  assert.equal(thick.radius, 5)
  assert.equal(thick.border, 0)
  assert.equal(thick.gap, 3)
  assert.equal(thick.inset, 2)
})

test("text color, bold, and italic stay with the symbol and the label", () => {
  assert.equal(Model.clampColor("#ABC"), "#aabbcc")
  assert.equal(Model.clampColor("#aabbccdd"), "#aabbcc")
  assert.equal(Model.clampColor("red"), "")
  assert.equal(Model.clampColor(""), "")
  assert.equal(Model.defaultSlots()[0].color, "")
  assert.equal(Model.defaultSlots()[0].bold, false)
  assert.equal(Model.defaultSlots()[0].italic, false)
  let slots = Model.setFace(Model.defaultSlots(2), 0, "A", null, null, "Code", true, true, "#ff00aa")
  assert.equal(slots[0].label, "A")
  assert.equal(slots[0].caption, "Code")
  assert.equal(slots[0].bold, true)
  assert.equal(slots[0].italic, true)
  assert.equal(slots[0].color, "#ff00aa")
  assert.equal(slots[1].color, "")
  assert.equal(slots[1].bold, false)
  const sized = Model.stepSize(slots, 0, 1)
  assert.equal(sized[0].color, "#ff00aa")
  assert.equal(sized[0].bold, true)
  const made = Model.setSpecial(slots, 0, true)
  assert.equal(made.slots[0].kind, "special")
  assert.equal(made.slots[0].color, "#ff00aa")
  assert.equal(made.slots[0].bold, true)
  assert.equal(made.slots[0].italic, true)
  assert.equal(made.slots[0].caption, "Code")
  const back = Model.setSpecial(made.slots, made.index, false)
  assert.equal(back.slots[back.index].kind, "ws")
  assert.equal(back.slots[back.index].color, "#ff00aa")
  assert.equal(back.slots[back.index].italic, true)
  const cleared = Model.setFace(back.slots, back.index, null, null, null, null, null, null, "")
  assert.equal(cleared[back.index].color, "")
  assert.equal(cleared[back.index].bold, true)
  const shown = Model.visibleEntries({
    slots: slots,
    workspaces: [{ id: 1, occupied: true, focused: true }],
    focusedId: 1,
    showOnlyActive: false
  })
  assert.equal(shown[0].color, "#ff00aa")
  assert.equal(shown[0].bold, true)
  assert.equal(shown[0].italic, true)
  const actions = Model.rowActions({ kind: "ws" })
  assert.deepEqual(actions.slice(-5), ["font", "bold", "italic", "sizeDown", "sizeUp"])
  assert.equal(actions.indexOf("color"), -1)
})

test("settings export and import round-trip", () => {
  const src = {
    showOnlyActive: false,
    respectTheme: true,
    showNumbers: false,
    workspaceGap: 12,
    slots: Model.setFace(Model.defaultSlots(2), 0, null, null, null, "Coding", true, false, "#112233")
  }
  const text = Model.exportText(src)
  const back = Model.importSettings(text)
  assert.equal(back.showOnlyActive, false)
  assert.equal(back.respectTheme, true)
  assert.equal(back.showNumbers, false)
  assert.equal(back.workspaceGap, 12)
  assert.equal(back.slots[0].caption, "Coding")
  assert.equal(back.slots[0].color, "#112233")
  assert.equal(back.slots[0].bold, true)
  assert.equal(back.slots[0].italic, false)
  assert.equal(back.slots[1].color, "")
  assert.equal(Model.importSettings("{"), null)
  assert.equal(Model.importSettings("{\"plugin\":\"other\",\"slots\":[{\"id\":1}]}"), null)
  assert.equal(Model.importSettings("{\"slots\":[]}"), null)
  assert.equal(Model.importSettings("{\"plugin\":\"crome.workspaces\",\"slots\":{\"length\":1000000000000}}"), null)
  assert.equal(Model.sanitize({ length: 1000000000000 }).length, 0)
  const sparse = []
  sparse.length = 100000
  sparse[0] = { id: 1, kind: "ws", label: "A" }
  sparse[11] = { id: 2, kind: "ws", label: "past-cap" }
  const capped = Model.sanitize(sparse)
  assert.equal(capped.length, 1)
  assert.equal(capped[0].label, "A")
  const many = []
  for (let i = 1; i <= 30; i++) many.push({ id: i, kind: "ws", label: "n" + i })
  const trimmed = Model.importSettings(JSON.stringify({ plugin: "crome.workspaces", slots: many }))
  assert.equal(trimmed.slots.length, 10)
  assert.equal(trimmed.slots.some((slot) => slot.id > 10), false)
})

test("emoji search fits the symbol field and the label can be cleared from the keyboard", () => {
  const catalog = [
    { e: "\uD83D\uDE00", k: "grinning face smile" },
    { e: "\uD83C\uDDFA\uD83C\uDDF8", k: "flag united states" },
    { e: "\uD83D\uDD25", k: "fire hot" }
  ]
  assert.equal("\uD83C\uDDFA\uD83C\uDDF8".length > 3, true)
  assert.deepEqual(Model.filterEmoji(catalog, "", 10), ["\uD83D\uDE00", "\uD83C\uDDFA\uD83C\uDDF8", "\uD83D\uDD25"])
  assert.deepEqual(Model.filterEmoji(catalog, "", 0).length, 3)
  assert.deepEqual(Model.filterEmoji(catalog, "fire", 10), ["\uD83D\uDD25"])
  assert.deepEqual(Model.filterEmoji(catalog, "flag", 10), ["\uD83C\uDDFA\uD83C\uDDF8"])
  const flag = Model.setFace(Model.defaultSlots(1), 0, "\uD83C\uDDFA\uD83C\uDDF8", null, null)
  assert.equal(flag[0].label, "\uD83C\uDDFA\uD83C\uDDF8")
  assert.equal(Model.setFace(Model.defaultSlots(1), 0, "abcd", null, null)[0].label, "abc")
  assert.equal(Model.builtinEmoji().length > 0, true)
  const actions = Model.rowActions({ kind: "ws" })
  assert.equal(actions[actions.indexOf("clear") + 1], "emoji")
  assert.equal(actions[actions.indexOf("caption") + 1], "clearCaption")
  const cleared = Model.setFace(Model.defaultSlots(1), 0, null, null, null, "")
  assert.equal(cleared[0].caption, "")
})
