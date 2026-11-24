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


func is_garbage() -> bool:
	return rarity == "g"


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


const RARITY_NAMES := {"c": "Common", "u": "Uncommon", "r": "Rare", "w": "Weapon", "g": "Junk"}
