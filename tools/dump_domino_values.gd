extends SceneTree
## Writes tests/fixtures/domino_values.json: for every domino (Garbage last), what each effect gives at every pip
## total from 0 to 12. tests/test_rules.gd compares the catalogue with this file, so a change to a domino's numbers
## is never an accident. After you balance on purpose, run this and commit the new file:
##   godot --headless -s tools/dump_domino_values.gd

const Game = preload("res://scripts/game.gd")


func _initialize() -> void:
	var g := Game.new()
	var out := []
	for d in g.data:
		var fx := []
		for e in d.effects:
			var vals := []
			for s in 13:
				vals.append(e.value(s))
			fx.append({"k": e.kind, "t": e.hits if e.kind == "hit" else 0, "vals": vals})
		out.append({"n": d.title, "r": d.rarity, "c": d.condition.id if d.condition != null else "", "fx": fx})
	var f := FileAccess.open("res://tests/fixtures/domino_values.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("wrote %d dominoes" % out.size())
	quit()
