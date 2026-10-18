const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../WorkspaceModel.js")

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
      { id: 2, label: "files", font: "Inter", fontPx: 18 },
      { id: 2, label: "dup" },
      { id: 0, label: "nope" },
      { id: 1, label: "", fontPx: 7 }
    ]
  })
  assert.equal(rows[0].kind, "special")
  assert.equal(rows[0].specialName, "magictouchtmpx")
  assert.equal(rows[0].label, "\u2728")
  assert.deepEqual(rows.slice(1).map((slot) => slot.id), [2, 1])
  assert.equal(rows[1].label, "files")
  assert.equal(rows[1].fontPx, 18)
  assert.equal(rows[2].label, Model.dotForId(1))
  assert.equal(rows[2].fontPx, 0)
  const again = Model.rowsFromSettings({ showMagic: true, slots: rows })
  assert.equal(again.filter((slot) => slot.kind === "special").length, 1)
})

test("sanitize pulls specials forward and drops a repeated name", () => {
  const rows = Model.sanitize([
    { id: 3, kind: "ws", label: "\u{1F7E2}" },
    { kind: "magic", label: "\u{1F9F9}" },
    { kind: "special", specialName: "scratchpad", title: "Notes", label: "\u270D\uFE0F" },
    { kind: "special", specialName: "magic", label: "other" }
  ])
  assert.deepEqual(rows.map((slot) => slot.kind === "special" ? slot.specialName : slot.id), [
    "magic", "scratchpad", 3
  ])
  assert.equal(rows[0].title, "Magic")
  assert.equal(rows[1].title, "Notes")
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
  const other = Model.setSpecial(slots, 1, true)
  const clash = Model.setMeta(other.slots, 0, null, other.slots[other.index].specialName)
  assert.equal(clash[0].specialName, "magicrm-rf")
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

test("scroll walks specials, then numbered workspaces", () => {
  const slots = Model.sanitize([
    { kind: "special", specialName: "magic", label: "\uD83E\uDE84" },
    { kind: "special", specialName: "scratchpad", label: "\u270D\uFE0F" },
    { id: 1, kind: "ws", label: Model.dotForId(1) },
    { id: 4, kind: "ws", label: Model.dotForId(4) }
  ])
  const onMagic = { slots: slots, activeSpecial: "magic", focusedId: 4 }
  assert.deepEqual(Model.relativeActions(onMagic, 1), [
    "hl.dsp.workspace.toggle_special('magic')",
    "hl.dsp.workspace.toggle_special('scratchpad')"
  ])
  assert.deepEqual(Model.relativeActions(onMagic, -1), [])
  assert.deepEqual(Model.relativeActions({ slots: slots, activeSpecial: "scratchpad", focusedId: 4 }, 1), [
    "hl.dsp.workspace.toggle_special('scratchpad')"
  ])
  assert.deepEqual(Model.relativeActions({ slots: slots, activeSpecial: "", focusedId: 1 }, -1), [
    "hl.dsp.workspace.toggle_special('scratchpad')"
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
  assert.deepEqual(Model.rowActions({ kind: "ws" }).slice(0, 2), ["label", "up"])
  assert.equal(Model.rowActions({ kind: "special" })[0], "title")
  assert.equal(Model.rowActions({ kind: "special" }).indexOf("workspace") > 0, true)
})
