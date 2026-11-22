extends SceneTree
## Smoke test for the screen: tag fade, HP previews, relic bar, relic cards. Run:
##   godot --headless -s tests/test_ui.gd
const Relics = preload("res://scripts/relics/relics.gd")

var fails := 0
var checks := 0


func expect(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var g = main.game
	var hud = main.hud
	g.foe.intent = [{"k": "atk", "v": 8}]
	g.pl.shield = 3
	g.hand[0] = g.make_domino(0, 3, 4)        # Slash 3|4 = 9 damage
	g.hand[1] = g.make_domino(3, 3, 3)        # Iron Guard
	main.sel = -1
	main._refresh_ui()
	expect(hud.enemy_tag.modulate.a == 1.0 and hud.player_tag.modulate.a == 1.0, "tags fully visible with nothing selected")
	expect(hud.enemy_tag.preview.loss == 0, "no damage marked on the enemy bar")
	expect(hud.player_tag.preview.loss == 5 and hud.player_tag.hp_text.text.contains("-5"), "your bar marks the 5 HP the enemy attack would take (8 - 3 shield)")
	main.sel = 0
	main._refresh_ui()
	expect(is_equal_approx(hud.enemy_tag.modulate.a, 0.3) and is_equal_approx(hud.player_tag.modulate.a, 0.3), "tags go to 30% when a domino is selected")
	expect(hud.enemy_tag.preview.loss == 9 and hud.enemy_tag.hp_text.text.contains("-9"), "enemy bar marks 9 HP for the selected attack")
	main.sel = 1
	main._refresh_ui()
	expect(hud.enemy_tag.preview.loss == 0 and is_equal_approx(hud.enemy_tag.modulate.a, 0.3), "a shield domino marks nothing but still fades the tags")
	main.sel = -1
	main._refresh_ui()
	expect(hud.enemy_tag.modulate.a == 1.0, "tags come back when nothing is selected")
	expect(hud.enemy_tag.intent.get_parsed_text().contains("Attack 8: -5 HP"), "enemy intent line shows the HP you lose")
	g.add_relic(Relics.by_id("war_drum"))
	g.add_relic(Relics.by_id("tile_armor"))
	main._refresh_ui()
	expect(hud.relic_bar.get_child_count() == 2 and hud.relic_bar.get_child(0).tooltip_text.begins_with("War Drum"), "relic bar shows owned relics with tooltips")
	var got := [-5]
	hud.pick_window.chosen.connect(func(i): got[0] = i)
	hud.pick_window.ask(g, "Choose a relic", "x", Relics.roll([], 3), "Skip")
	await process_frame
	var grid = hud.pick_window.grid
	expect(grid.get_child_count() == 3 and not grid.get_child(0).picture.visible, "relic cards show text only")
	expect(grid.get_child(0).body.get_parsed_text().contains("relic"), "relic card text has the rarity line")
	grid.get_child(1).pressed.emit()
	await process_frame
	expect(got[0] == 1, "choosing a relic card answers its index")
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)
