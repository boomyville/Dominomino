extends "res://scripts/effects/effect.gd"
## Take attack dominoes out of your hand, play their effects again (no cost, they do not go on the board) and discard
## them. "pick": "equipment" asks you to choose one weapon domino, "random" takes "n" random attack dominoes.
## "times" is how often each is played.

var pick := "equipment"
var count := 1
var times := 1


func setup(row: Dictionary) -> void:
	super.setup(row)
	pick = row.get("pick", "equipment")
	count = int(row.get("n", 1))
	times = int(row.get("times", 1))


func text(_game, _s: int) -> String:
	var how := "once" if times == 1 else "%d times" % times
	if pick == "equipment":
		return "Choose a weapon domino in your hand: play it %s, then discard it" % how
	return "Play %d random attack dominoes from your hand %s, then discard them" % [count, how]


func icon() -> String:
	return "boost"


func apply(game, _domino, _s: int) -> void:
	var pool := []
	for d in game.hand:
		if d.data.has_attack() and not d.data.has_effect("replay") and (pick != "equipment" or d.is_equipment()):
			pool.append(d)
	if pool.is_empty():
		game.ui.toast("No domino in your hand to play again")
		return
	var chosen := []
	if pick == "equipment":
		var c: int = await game.ui.pick("Choose a weapon domino", "It is played %d times for free, then discarded." % times, pool)
		chosen = [pool[clampi(c, 0, pool.size() - 1)]]
	else:
		game.rshuffle(pool)
		chosen = pool.slice(0, count)
	for d in chosen:
		await game.replay_domino(d, times)
