extends RefCounted
## What a kind of domino IS: its name, rarity, play condition and effects. Shared by every copy of it.
## (A single domino you hold, with its own pips, is a Domino in domino.gd.)

var id := 0                # position in the catalogue
var title := ""
var rarity := "c"          # c common, u uncommon, r rare, g junk (Garbage)
var condition = null       # a Condition, or null when it can always be played
var effects := []          # Effect objects, played in order


func has_attack() -> bool:
	for e in effects:
		if e.is_attack():
			return true
	return false


func is_garbage() -> bool:
	return rarity == "g"


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


const RARITY_NAMES := {"c": "Common", "u": "Uncommon", "r": "Rare", "g": "Junk"}
