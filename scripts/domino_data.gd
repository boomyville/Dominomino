extends RefCounted
## What a kind of domino IS: its name, rarity, play condition and effects. Shared by every copy of it.
## (A single domino you hold, with its own pips, is a Domino in domino.gd.)

var id := 0                # position in the catalogue
var title := ""
var rarity := "c"          # c common, u uncommon, r rare, w weapon (only a weapon adds it), g junk (Garbage)
var condition = null       # a Condition, or null when it can always be played
var effects := []          # Effect objects, played in order
var ephemeral := false     # if it is still in your hand when you end the turn, it goes to the discard pile
var pips := []             # [PipSpec, PipSpec]: the core pips of each half (stable, unstable or volatile)
var row := {}              # the catalogue row this was built from
var tier := ""             # c, u or r: the class that sets the highest level and the balance. Same as rarity, except for
                           # weapon dominoes (rarity w), which take the tier of their weapon
var level := 1             # upgrade level: 1 is the normal domino, 0 is downgraded, more is upgraded
var base = null            # the level 1 DominoData of this kind (null on the level 1 one itself)
var _levels := {}          # level -> DominoData, built the first time it is needed (level 1 only)

## The highest level of each tier (Garbage and tokens have one level). Level 0 is the downgrade. Weapon dominoes
## are not upgraded on their own: they take the level of the weapon that adds them.
const MAX_LEVEL := {"c": 4, "u": 3, "r": 2}


func has_attack() -> bool:
	for e in effects:
		if e.is_attack():
			return true
	return false


## "stable", "unstable" or "volatile" for each half: its pip_stability.
func pip_stability() -> Array:
	return [pips[0].stability, pips[1].stability] if pips.size() == 2 else ["stable", "stable"]


func has_ranged_pips() -> bool:
	return pips.size() == 2 and (pips[0].ranged() or pips[1].ranged())


func max_level() -> int:
	return MAX_LEVEL.get(tier if tier != "" else rarity, 1)


## "attack" for a domino with an attack in it (damage, hits, pip damage ...), "skill" for everything else
## (defence, buffs, drawing, making dominoes). Weapon dominoes, regular ones and created ones all count.
func type() -> String:
	return "attack" if has_attack() else "skill"


func has_effect(kind_id: String) -> bool:
	for e in effects:
		if e.kind == kind_id:
			return true
	return false


## The same kind of domino at another level (0 to max_level): its own effects, condition and ephemeral
## flag, see upgrades.gd. Level 1 is the catalogue entry itself.
func at_level(n: int):
	var b = base if base != null else self
	if n == 1 or b.max_level() <= 1:
		return b
	n = clampi(n, 0, b.max_level())
	if n == 1:
		return b
	if not b._levels.has(n):
		b._levels[n] = load("res://scripts/upgrades.gd").variant(b, n)
	return b._levels[n]


func is_garbage() -> bool:
	return rarity == "g"


func rarity_name() -> String:
	if rarity == "w" and tier != "":
		return "%s weapon" % RARITY_NAMES[tier]
	return RARITY_NAMES[rarity]


const RARITY_NAMES := {"c": "Common", "u": "Uncommon", "r": "Rare", "w": "Weapon", "g": "Junk", "x": "Token"}
