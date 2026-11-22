extends "res://scripts/effects/effect.gd"
## Deal damage equal to the pips of EVERY domino you have played this battle (this one included).
## Row: {"k": "playedpips", "m": "K", "b": damage per pip (1)}. Fury, Power and Boost add as usual.


func is_attack() -> bool:
	return true


func icon() -> String:
	return "damage"


## Pips on the board that you played. placed is true once this domino is on the board already.
func count(game, domino, placed: bool = false) -> int:
	var n := 0
	for p in game.placed:
		if p.owner == "p":
			n += p.a + p.b
	if domino != null and not placed:
		n += domino.total()
	return n


func amount(game, domino, s: int, placed: bool = false) -> int:
	return value(s) * count(game, domino, placed)


func text_for(game, domino, s: int) -> String:
	var n := count(game, domino)
	return "Deal %d damage: the pips of every domino you have played (%d now)" % [
			game.pl.attack_damage(value(s) * n), n]


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
