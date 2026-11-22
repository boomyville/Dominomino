extends RefCounted
## Base class for a status on a Combatant (Fury, Power, Boost ...).
## A status holds one number (value). It can change the damage its owner deals and react when
## its owner finishes an attack. Add a new status by making a child of this class and registering
## it in combatant.gd.

var id := ""
var value := 0


## Change the damage this combatant deals (add or subtract here).
func modify_damage(n: int) -> int:
	return n


## Called once after the owner finishes an attack (a domino with an attack in it, or an enemy attack).
func on_attack_done() -> void:
	pass


## Text for the tag over the character. "" hides the status.
func text() -> String:
	return ""


## The icon shown next to the status (a kind or an icon name, see icons.gd).
func icon_id() -> String:
	return id
