extends "res://scripts/effects/effect.gd"
## Deal damage for every pip of one number ("a 4 pip" = fire) on the board, or in your hand.
## The catalogue row says which: {"k": "pipdmg", "p": 4, "w": "board" | "hand", "m": "K", "b": damage per pip}.
## Fury, Power and Boost add to the total like they do for any attack.
## The count is "if you played this domino now": a domino on the board counts its own pips, and a
## domino that leaves your hand does not count itself.

const Elements = preload("res://scripts/elements.gd")

var pip := 1
var where := "board"


func setup(row: Dictionary) -> void:
	super(row)
	pip = int(row.get("p", 1))
	where = str(row.get("w", "board"))


func is_attack() -> bool:
	return true


func icon() -> String:
	return Elements.icon(pip)


## How many of this pip count, given the domino (null = just count what is there).
## placed is true once the domino is already on the board (and out of the hand).
func count(game, domino, placed: bool = false) -> int:
	var n: int = game.count_pips(pip, where)
	if domino == null or placed:
		return n
	var own := 0
	if domino.a == pip:
		own += 1
	if domino.b == pip:
		own += 1
	if where == "board":
		return n + own
	if game.hand.has(domino):
		return n - own
	return n


func amount(game, domino, s: int, placed: bool = false) -> int:
	return value(s) * count(game, domino, placed)


func text_for(game, domino, s: int) -> String:
	var n := count(game, domino)
	var place := "on the board" if where == "board" else "in your hand"
	return "Deal %d damage: %d per :%s: pip %s (%d now)" % [
			game.pl.attack_damage(value(s) * n), value(s), Elements.icon(pip), place, n]


func caption_for(game, domino, s: int) -> String:
	return str(game.pl.attack_damage(amount(game, domino, s)))


func text(game, s: int) -> String:
	return text_for(game, null, s)


func caption(game, s: int) -> String:
	return caption_for(game, null, s)


func apply(game, domino, s: int) -> void:
	game.hit_foe(game.pl.attack_damage(amount(game, domino, s, true)))


func preview(game, domino, s: int, sim: Dictionary) -> void:
	sim.foe.take_damage(sim.pl.attack_damage(amount(game, domino, s)))
