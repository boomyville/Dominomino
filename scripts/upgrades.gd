extends RefCounted
## What each level of a domino does. A kind of domino has levels 0 (downgraded), 1 (the catalogue row, normal) and
## up to 2 (rare), 3 (uncommon) or 4 (common). Level rows are worked out from the level 1 row, so every
## domino has them without being written out; they are built the first time a level is needed
## (DominoData.at_level).
##
## A catalogue row can spell out a level itself with "levels": {"0": {"c": "first"}, "2": {"fx": [...]}}: the keys
## of that level replace the row's (see Berserk). Levels it does not list are worked out as below.
## UPGRADE (level 2 and up): every helpful number (damage, shield, heal, draw ...) rises by about a third of its
## value per level (6 damage becomes 8, then 10 ...). From level 3 a small extra effect is added too: draw a domino,
## gain 1 max shield or heal 1 HP. A domino with no number to raise (it only rerolls, say) gets an extra
## effect on every level instead.
## DOWNGRADE (level 0), chosen from the name of the domino so it never changes:
##   6 in 10: the helpful numbers are lower (6 damage becomes 4)
##   2 in 10: a drawback is added: lose 1 HP, discard 1 at random, apply 2 Impair to yourself, or lose 1 energy
##   2 in 10: a restriction is added: needs 4 dominoes in hand, ends your turn, ephemeral, not on turn 1, only
##            with no shield, or only if you have lost no HP this battle
## (a domino that has nothing to lower, or already has a condition, gets a drawback or the restrictions it can take).

const Dominoes = preload("res://scripts/dominoes.gd")
const EffectFactory = preload("res://scripts/effects/effect_factory.gd")
const PipMetric = preload("res://scripts/pip_metric.gd")

const UP_STEP := 0.33      # share of a number added per level above 1
const DOWN_STEP := 0.3     # share of a number taken away by the downgrade

## The effects whose number is something you want (these go up with a level and down with the downgrade).
const SCALES := ["dmg", "hit", "shield", "maxs", "draw", "tutor", "power", "boost", "heal", "fury", "impE", "pipdmg",
		"addhand", "typedmg", "playeddmg", "scrap", "drawattack"]

const BONUS := [
	{"k": "draw", "m": "K", "a": 0, "b": 1},
	{"k": "maxs", "m": "K", "a": 0, "b": 1},
	{"k": "heal", "m": "K", "a": 0, "b": 1},
]
const DRAWBACKS := [
	{"k": "selfdmg", "m": "K", "a": 0, "b": 1},
	{"k": "discR", "m": "K", "a": 0, "b": 1},
	{"k": "impS", "m": "K", "a": 0, "b": 2},
	{"k": "energy", "m": "K", "a": 0, "b": 1},
]
## A condition id from condition_factory.gd, "endturn" (an effect) or "ephemeral" (the flag).
const RESTRICTIONS := ["hand4", "endturn", "ephemeral", "turn2", "noShield", "noHpLost"]


static func max_level(rarity: String) -> int:
	return load("res://scripts/domino_data.gd").MAX_LEVEL.get(rarity, 1)


## The level of a kind as a DominoData (base is the level 1 one).
static func variant(base, level: int):
	var d = Dominoes.make_data(base.id, level_row(base.row, level))
	d.level = level
	d.base = base
	return d


## The catalogue row for one level of a row. Level 1 is the row itself.
static func level_row(row: Dictionary, level: int) -> Dictionary:
	if level == 1:
		return row
	var patches: Dictionary = row.get("levels", {})
	if patches.has(str(level)):
		# a domino can spell a level out: "levels": {"0": {...}, "2": {...}} replaces those keys of the row
		var custom: Dictionary = row.duplicate(true)
		custom.erase("levels")
		for k in patches[str(level)]:
			custom[k] = patches[str(level)][k]
		return custom
	var out: Dictionary = row.duplicate(true)
	var fx: Array = out.fx
	var h := name_hash(row.n)
	var ref := _ref_pips(row)
	if level > 1:
		var steps := level - 1
		var scaled := 0
		for e in fx:
			if _scalable(e):
				e["b"] = e.get("b", 0) + maxi(1, roundi(_value(e, ref) * UP_STEP * steps))
				scaled += 1
		var extras := level - 2 if scaled > 0 else steps
		for k in extras:
			_add_bonus(fx, BONUS[(h + k) % BONUS.size()])
		return out
	return _downgrade(out, h, ref)


static func _downgrade(out: Dictionary, h: int, ref: Array) -> Dictionary:
	var fx: Array = out.fx
	var mode := h % 10
	if mode <= 5:
		var lowered := false
		for e in fx:
			if _scalable(e):
				var v0 := _value(e, ref)
				var d := maxi(1, roundi(v0 * DOWN_STEP))
				if v0 - d >= 1:
					e["b"] = e.get("b", 0) - d
					lowered = true
		if lowered:
			return out
	var pick := int(h / 10)
	if mode >= 8 and _restrict(out, pick):
		return out
	fx.append(DRAWBACKS[pick % DRAWBACKS.size()].duplicate())
	return out


## Add the first restriction this row can take (starting from pick). False if it can take none.
static func _restrict(out: Dictionary, pick: int) -> bool:
	var fx: Array = out.fx
	for i in RESTRICTIONS.size():
		var id: String = RESTRICTIONS[(pick + i) % RESTRICTIONS.size()]
		match id:
			"endturn":
				fx.append({"k": "endturn"})
				return true
			"ephemeral":
				if not out.get("e", false):
					out["e"] = true
					return true
			_:
				if out.c == "":
					out["c"] = id
					return true
	return false


static func _scalable(e: Dictionary) -> bool:
	return SCALES.has(e.k) and e.get("m", "N") != "N"


## The number an effect gives at the pips the kind normally has (the middle of a range).
static func _value(e: Dictionary, ref: Array) -> int:
	var fx = EffectFactory.make(e)
	return fx.value(PipMetric.of(fx.src, ref[0], ref[1]))


static func _ref_pips(row: Dictionary) -> Array:
	var out := []
	for raw in row.get("p", [0, 0]):
		out.append(roundi((int(raw[0]) + int(raw[1])) / 2.0) if raw is Array else int(raw))
	return out


## One more of a helpful effect: raise it if the row already has one, add it if not.
static func _add_bonus(fx: Array, bonus: Dictionary) -> void:
	for e in fx:
		if e.k == bonus.k and e.get("m", "N") != "N" and not e.has("src"):
			e["b"] = e.get("b", 0) + 1
			return
	fx.append(bonus.duplicate())


## The same number for the same name every time (String.hash is not promised to stay the same).
static func name_hash(s: String) -> int:
	var h := 7
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) % 1000003
	return h
