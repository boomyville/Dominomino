extends SceneTree
## Prints every domino with its cost, its score in damage points (see scripts/balance.gd) and how far that is
## from the target for its rarity. Run it after changing dominoes:
##   godot --headless -s tools/balance_report.gd           (all dominoes, level 1)
##   godot --headless -s tools/balance_report.gd -- all    (every level too)
## It also plays every domino once on a test board and says if anything went wrong.

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Balance = preload("res://scripts/balance.gd")


func _initialize() -> void:
	var all_levels := OS.get_cmdline_user_args().has("all")
	var g := Game.new()
	var rows := []
	for base in g.data:
		for lv in (range(0, base.max_level() + 1) if all_levels and base.max_level() > 1 else [1]):
			var d = g.make_domino(base.id)
			d.set_level(lv)
			var span: Vector2i = d.total_span()
			var cost: float = (span.x + span.y) / 2.0
			var r: float = Balance.ratio(d)
			var t: float = Balance.target(d.data)
			rows.append([d.display_name(), d.data.rarity, cost, Balance.score(d), r, t, r / t])
	rows.sort_custom(func(x, y): return x[6] > y[6])
	print("%-22s r  cost  score  per-energy  target  vs-target" % "domino")
	for r in rows:
		print("%-22s %s  %4.1f  %5.1f  %9.2f  %6.2f  %8.2f %s" % [r[0], r[1], r[2], r[3], r[4], r[5], r[6],
				"<-- TOO STRONG" if r[6] > 1.0 + Balance.BAND else ("<-- TOO WEAK" if r[6] < 1.0 - Balance.BAND else "")])
	quit()
