extends "res://scripts/model.gd"
## Base class for a status on a Combatant (Fury, Power, Boost ...). A status is a model: it holds one
## number (value), changes the damage its owner deals (modify_damage_additive) and reacts when its
## owner finishes an attack (after_attack). Add a new one by making a child of this class and
## registering it in combatant.gd. Its owner is set by Combatant.status().

var value := 0


## Is this status on the combatant who is dealing the damage / finishing the attack?
func is_source(ctx: Dictionary) -> bool:
	return ctx.get("source") == owner


## Text for the tag over the character. "" hides the status.
func text() -> String:
	return ""


## The icon shown next to the status (a kind or an icon name, see icons.gd).
func icon_id() -> String:
	return id


## The name and the number shown on the tag, so the name can be switched off ("" = hidden).
func label() -> String:
	return ""


func number() -> String:
	return ""
