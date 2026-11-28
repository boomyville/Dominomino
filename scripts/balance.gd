extends RefCounted
## How strong a domino is, in "damage points", so dominoes can be compared and balanced. The weights say how many
## damage points one unit of each effect is worth. The score of a domino divided by what it costs in energy (its
## pip total) should be about the same for dominoes of the same rarity: that is what tests/test_balance.gd
## checks, and tools/balance_report.gd prints a table of every domino. When you add a domino, run the report.

## Damage points per unit.
const WEIGHT := {
	"dmg": 1.0, "hit": 1.0, "shield": 0.9, "maxs": 1.5, "heal": 0.8, "draw": 2.0, "tutor": 3.0,
	"power": 4.0, "boost": 1.0, "fury": 1.8, "impE": 1.5, "impS": -1.5, "selfdmg": -1.2, "discR": -2.0, "discP": -1.0,
	"energy": -1.5, "gen": 1.0, "life": 10.0, "paylife": -10.0,
	"addhand": 2.0, "drawattack": 2.0, "berserk": -2.5, "gain": 1.5,
}
## Flat points for effects with no number.
const FLAT := {"rerollA": 1.0, "rerollP": 0.8, "uptick": 2.0, "endturn": -3.0, "playedpips": 12.0}

## Target damage points per energy, by tier (the rarity; a weapon domino uses the tier of its weapon, and should be a
## little better than a regular domino of that rarity). A condition, or ephemeral, is allowed a stronger domino.
const TARGET := {"c": 1.4, "u": 2.0, "r": 3.0}
const WEAPON_BONUS := 1.2
const CONDITION_BONUS := 1.2
const EPHEMERAL_BONUS := 1.3
const BAND := 0.35         # a domino may be this far (as a share) above or below its target


## The score of a domino at the pips it has. While a pip is still a range (unstable, volatile) it is the average
## over every value the pips can take.
static func score(d) -> float:
	if not d.unsettled():
		return _score_at(d, d.a, d.b)
	var sum := 0.0
	var n := 0
	for x in range(d.specs[0].lo, d.specs[0].hi + 1):
		for y in range(d.specs[1].lo, d.specs[1].hi + 1):
			sum += _score_at(d, x, y)
			n += 1
	return sum / n


static func _score_at(d, a: int, b: int) -> float:
	var total := 0.0
	for e in d.data.effects:
		total += effect_score(e, d, a, b)
	return total


static func effect_score(e, d, a: int, b: int) -> float:
	var s: int = load("res://scripts/pip_metric.gd").of(e.src, a, b)
	match e.kind:
		"pipdmg":
			var own: int =  (1 if a == e.pip else 0) + (1 if b == e.pip else 0)
			return e.value(s) * (own + 2)
		"dmgdbl":
			return e.value(s) * 1.5                                       # doubled about half of the time
		"breakshield":
			return 3.0                                                    # about 3 shield of the enemy's
		"typedmg":
			return e.value(s) * (2.5 if e.ty == "skill" else 1.5)       # about 2.5 skills / 1.5 other attacks in a hand
		"playeddmg":
			return e.value(s) * 1.6                                      # about 1.6 attacks played in a turn, this one included
		"scrap":
			return 0.9 * e.value(s) * 2.0 - 6.0                          # about 2 attacks in hand, and they are lost
		"replay":
			return 5.5 * e.count * e.times * (0.7 if e.pick == "equipment" else 0.9)
		_:
			if FLAT.has(e.kind):
				return FLAT[e.kind]
			var n: float = e.value(s) if e.mode != "N" else 1.0
			if e.kind == "hit":
				n *= e.hits
			if e.kind == "tutor" and e.mode == "N":
				n = 1.0
			return n * WEIGHT.get(e.kind, 0.0)


## Points per energy. A domino with no cost has its score as is.
static func ratio(d) -> float:
	var span: Vector2i = d.total_span()
	var cost := maxf(1.0, (span.x + span.y) / 2.0)
	return score(d) / cost


## The ratio a domino of this kind should have (rarity, condition and ephemeral change it).
static func target(data) -> float:
	var t: float = TARGET.get(data.tier, 1.4)
	if data.rarity == "w":
		t *= WEAPON_BONUS
	if data.condition != null and data.condition.id != "":
		t *= CONDITION_BONUS
	if data.ephemeral:
		t *= EPHEMERAL_BONUS
	return t
