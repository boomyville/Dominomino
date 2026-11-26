extends "res://scripts/effects/effect.gd"
## Make dominoes and put them in your hand (they come in from the top of the screen). "d" is the domino's name and b
## how many. They are created dominoes: they belong to this battle only (Phantom Blades makes Phantom Shivs).

var domino_name := ""


func setup(row: Dictionary) -> void:
	super.setup(row)
	domino_name = row.get("d", "")


func text(_game, s: int) -> String:
	return "Add %d %s to your hand" % [value(s), domino_name]


func icon() -> String:
	return "draw"


func apply(game, _domino, s: int) -> void:
	for i in value(s):
		var d = game.make_named(domino_name)
		d.origin = "created"
		d.roll_all(game.rng)
		if not game.add_to_hand(d, "top"):
			break
		game.ui.refresh()
		await game.ui.pause(0.2)
