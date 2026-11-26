extends "res://scripts/model.gd"
## One domino you own or hold: its kind (data) and its own pips.
## Where it is on the board is a separate placement ({x, y, rot, a, b}), see game.gd.
##
## A domino has two sets of pip values:
##   specs   the CORE pips: one PipSpec for each half (stable, unstable or volatile, see pip_spec.gd). They come
##           from the kind. Only an event that changes pips for good (or an explicit pip amount when the domino
##           is made) changes them.
##   a, b    the CURRENT pips, the ones the domino shows and costs energy for. A reroll, an Uptick or a volatile
##           re-roll changes only these, so every change in a battle ends with the battle (the battle uses a
##           copy of the domino you own).
## A domino with an unstable or volatile half has no value for it until the battle starts (rolled is false and
## a / b hold the bottom of the range). Dominoes in the shop, rewards and your collection show the range.

const PipSpec = preload("res://scripts/pip_spec.gd")

var data = null      # DominoData
var specs: Array = []  # [PipSpec, PipSpec] the core pips
var a := 0           # current pips on the first half
var b := 0           # current pips on the second half
var rolled := false  # have the unstable / volatile halves been given a value this battle?
## Where it came from: "collection" (yours), "equipment" (made by a weapon or an artifact) or "created" (made by
## another domino). Only the first stays after the battle: the others belong to what made them.
var origin := "collection"
var ang := 0         # how far it is turned in the hand (degrees, adds up so it never spins backwards)


## pips_a / pips_b: leave them out to use the kind's pips. A number from 0 to 6 makes that half a stable
## pip of that value instead (tests and special dominoes).
func _init(domino_data = null, pips_a: int = -1, pips_b: int = -1) -> void:
	data = domino_data
	for i in 2:
		if data != null and data.pips.size() == 2:
			specs.append(data.pips[i].copy())
		else:
			specs.append(PipSpec.stable(0))
	if pips_a >= 0:
		specs[0] = PipSpec.stable(pips_a)
	if pips_b >= 0:
		specs[1] = PipSpec.stable(pips_b)
	a = specs[0].lo
	b = specs[1].lo


## Upgrade levels. The kind says what each level does (see upgrades.gd); the domino remembers its level by
## pointing at that level's DominoData. Level 1 is normal, 0 is downgraded. The highest level depends on the
## rarity: common 4, uncommon 3, rare 2. Garbage has one level. Weapon dominoes take their weapon's level.
func level() -> int:
	return data.level if data != null else 1


func max_level() -> int:
	return data.max_level() if data != null else 1


func can_upgrade() -> bool:
	return data != null and data.level < data.max_level()


func can_downgrade() -> bool:
	return data != null and data.max_level() > 1 and data.level > 0


## "attack" or "skill" (see DominoData.type).
func type() -> String:
	return data.type() if data != null else "skill"


## Made by a weapon or an artifact (it is removed at the end of the battle with the rest of its equipment).
func is_equipment() -> bool:
	return origin == "equipment"


## Jump to a level (0 up to the highest this kind has).
func set_level(n: int) -> void:
	if data != null:
		data = data.at_level(clampi(n, 0, data.max_level()))


func upgrade() -> bool:
	if not can_upgrade():
		return false
	data = data.at_level(data.level + 1)
	return true


func downgrade() -> bool:
	if not can_downgrade():
		return false
	data = data.at_level(data.level - 1)
	return true


## The small mark for the level: "" at level 1, "-" downgraded, "+" at level 2, "++" at level 3, "+++" at level 4.
func level_tag() -> String:
	var lv := level()
	if lv == 0:
		return "-"
	return "+".repeat(lv - 1)


## The name with its level: "Slash", "Slash-" (downgraded), "Slash+", "Slash++" ...
func display_name() -> String:
	return data.title + level_tag()


## Both halves added together: what the domino costs to play (and the number most effects start from).
func total() -> int:
	return a + b


func has_ranged() -> bool:
	return specs[0].ranged() or specs[1].ranged()


func has_volatile() -> bool:
	return specs[0].is_volatile() or specs[1].is_volatile()


## True while a half still has no value: it has a range and the battle has not rolled it yet.
func unsettled() -> bool:
	return has_ranged() and not rolled


## "stable", "unstable" or "volatile" for each half.
func pip_stability() -> Array:
	return [specs[0].stability, specs[1].stability]


## The core pip of one half (0 or 1): its value if stable, the bottom of its range otherwise.
func core(side: int) -> int:
	return specs[side].lo


func current(side: int) -> int:
	return a if side == 0 else b


func set_current(side: int, value: int) -> void:
	value = clampi(value, 0, PipSpec.MAX_PIP)
	if side == 0:
		a = value
	else:
		b = value


## What the pips look like in text: "3|5", or "1-6|6" while a range has no value yet.
func pips_text() -> String:
	var l: String = specs[0].text() if unsettled() and specs[0].ranged() else str(a)
	var r: String = specs[1].text() if unsettled() and specs[1].ranged() else str(b)
	return "%s|%s" % [l, r]


## The lowest and highest total the pips can have (the same number twice for stable dominoes).
func total_span() -> Vector2i:
	if not unsettled():
		return Vector2i(total(), total())
	return Vector2i(specs[0].lo + specs[1].lo, specs[0].hi + specs[1].hi)


## Start of a battle: every unstable and volatile half gets a value, every stable half is its core pip.
func roll_all(rng: RandomNumberGenerator) -> void:
	for i in 2:
		set_current(i, specs[i].roll(rng) if specs[i].ranged() else specs[i].lo)
	rolled = true


## Start of a turn: only the volatile halves are rolled again.
func roll_volatile(rng: RandomNumberGenerator) -> void:
	for i in 2:
		if specs[i].is_volatile():
			set_current(i, specs[i].roll(rng))


## A reroll effect: a stable half becomes any pip (0 to 6), a half with a range stays in its range.
## Temporary: it only changes the current pips.
func reroll(rng: RandomNumberGenerator) -> void:
	for i in 2:
		if specs[i].ranged():
			set_current(i, specs[i].roll(rng))
		else:
			set_current(i, rng.randi() % (PipSpec.MAX_PIP + 1))


## An Uptick: both current pips go up by 1, never past 6. Temporary.
func uptick() -> void:
	set_current(0, a + 1)
	set_current(1, b + 1)


## Change a core pip for good (for events): moves a stable pip or a whole range by delta, 0 to 6.
func shift_core(side: int, delta: int) -> void:
	specs[side].shift(delta)
	if not has_ranged() or not rolled:
		a = specs[0].lo
		b = specs[1].lo
	else:
		set_current(side, current(side) + delta)


## Back to the core pips (a stable domino shows its core pips again, a range waits for the next roll).
func reset_to_core() -> void:
	a = specs[0].lo
	b = specs[1].lo
	rolled = false


## A fresh copy: same kind, core pips and current pips (not turned).
func copy():
	var c = get_script().new(data)
	for i in 2:
		c.specs[i] = specs[i].copy()
	c.a = a
	c.b = b
	c.rolled = rolled
	c.origin = origin
	return c
