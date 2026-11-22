extends SceneTree
## Smoke test for the screen: tag fade, HP previews, relic bar, relic cards. Run:
##   godot --headless -s tests/test_ui.gd
const Relics = preload("res://scripts/relics/relics.gd")
const Settings = preload("res://scripts/settings.gd")

var fails := 0
var checks := 0


func expect(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)


func Dominoes_index(g, title: String) -> int:
	for i in g.data.size():
		if g.data[i].title == title:
			return i
	return -1


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
	# ---- settings
	Settings.show_status_names = false
	Settings.show_status_info = false
	Settings.show_damage_taken = true
	g.pl.add("fury", 3)
	g.pl.add("fury", -5)
	main._refresh_ui()
	var st_txt: String = hud.player_tag.status.get_parsed_text()
	expect(not st_txt.contains("Impair") and st_txt.contains("2"), "status names off: icon and number only (%s)" % st_txt.strip_edges())
	Settings.show_status_names = true
	main._refresh_ui()
	expect(hud.player_tag.status.get_parsed_text().contains("Impair 2"), "status names on: Impair 2")
	Settings.show_damage_taken = false
	main._refresh_ui()
	expect(hud.player_tag.preview.loss == 0 and not hud.enemy_tag.intent.get_parsed_text().contains("HP"), "damage estimate off: no HP loss on the bar or the intent")
	Settings.show_damage_taken = true
	hud.open_settings()
	expect(hud.modal_layer.visible and hud.settings_window.visible and hud.settings_window.list.get_child_count() == 3, "settings window opens on the modal layer with 3 toggles")
	var first = hud.settings_window.list.get_child(0)
	first.button_pressed = false
	expect(not Settings.show_damage_taken and first.text.ends_with("OFF"), "toggling a button changes the setting")
	first.button_pressed = true
	hud.settings_window.close()
	expect(not hud.modal_layer.visible, "closing the last window hides the modal layer")
	# ---- domino info + status cards
	g.hand[0] = g.make_domino(Dominoes_index(g, "Crimson Ritual"), 3, 3)
	main.sel = 0
	Settings.show_status_info = false
	main._refresh_ui()
	expect(hud.info_window.visible and hud.info_window.cards.get_child_count() == 0, "info cards off: just the domino info")
	Settings.show_status_info = true
	main._refresh_ui()
	await process_frame
	expect(hud.info_window.cards.get_child_count() == 3, "info cards on: a card each for Lives, Fury, Power")
	expect(hud.info_window.cards.get_child(1).get_child(0).get_parsed_text().contains("Fury"), "the card describes the status")
	Settings.show_status_info = false
	main.sel = -1
	main._refresh_ui()
	# ---- stack window
	g.hand = [g.hand[0], g.hand[1]]
	hud.open_stack(g, true)
	var sw = hud.stack_window
	var entries: Array = g.battle_deck_entries()
	expect(sw.visible and sw.grid.get_child_count() == entries.size(), "stack window lists every domino of the deck")
	var framed := 0
	var faded := 0
	var full := 0
	for i in entries.size():
		var a: float = sw.grid.get_child(i).modulate.a
		if entries[i].state == "hand":
			framed += 1
			expect(is_equal_approx(a, 0.6), "hand domino: low opacity")
		elif entries[i].state == "stack":
			full += 1
		else:
			faded += 1
	expect(framed == 2 and full == g.stack.size(), "2 in hand, the rest of the stack at full opacity")
	var hand_i := -1
	for i in entries.size():
		if entries[i].state == "hand":
			hand_i = i
	expect(sw.grid.get_child(hand_i).get_theme_stylebox("normal").border_width_left == 2, "a hand domino has a border")
	expect(not sw.info.visible, "no info until you click")
	sw.grid.get_child(0).pressed.emit()
	expect(sw.info.visible and sw.info.text.get_parsed_text().contains(entries[0].d.data.title), "clicking a domino shows its info")
	Settings.show_status_info = true
	sw.grid.get_child(0).pressed.emit()
	Settings.show_status_info = false
	sw.close()
	hud.open_stack(g, false)
	var all_full := true
	for c in sw.grid.get_children():
		if not is_equal_approx(c.modulate.a, 1.0):
			all_full = false
	expect(all_full and sw.grid.get_child_count() == g.collection.size(), "between battles every domino is at full opacity")
	sw.close()
	# ---- inventory window
	for id in ["war_drum", "iron_cloak"]:
		g.add_relic(Relics.by_id(id))
	g.add_relic(Relics.by_id("kindling"))
	hud.open_inventory(g)
	var iw = hud.inventory_window
	expect(iw.visible and iw.slots_l.text.contains("/ 8"), "inventory shows the slots")
	var before: int = g.relics.size()
	var btn = iw.rows.get_child(iw.rows.get_child_count() - 1)
	for c in iw.rows.get_children():
		if c is HBoxContainer and c.get_child(2).text == "Unequip":
			btn = c.get_child(2)
			break
	btn.pressed.emit()
	expect(g.relics.size() == before - 1 and g.stored_relics.size() == 1, "Unequip moves the artifact to the unequipped list")
	var eq_btn = null
	for c in iw.rows.get_children():
		if c is HBoxContainer and c.get_child(2).text == "Equip":
			eq_btn = c.get_child(2)
	eq_btn.pressed.emit()
	expect(g.relics.size() == before and g.stored_relics.is_empty(), "Equip puts it back")
	iw.close()
	# ---- the screen between battles
	g.reward_note = "New domino: Test 1|2"
	g.pl.hp = 33
	var done := [false]
	var run := func():
		await hud.intermission(g)
		done[0] = true
	run.call()
	await process_frame
	var iwin = hud.intermission_window
	expect(iwin.visible and hud.modal_layer.visible and not hud.dim.visible, "between battles: a blank screen over the game")
	expect(iwin.title_l.text.begins_with("BATTLE") and iwin.note_l.text.contains("Test") and iwin.hp_bar.value == 33, "it shows the reward and your HP")
	iwin.stack_b.pressed.emit()
	expect(hud.stack_window.visible and hud.stack_window.title_l.text.begins_with("DOMINO STACK"), "its stack button opens the stack window")
	hud.stack_window.close()
	iwin.inv_b.pressed.emit()
	expect(hud.inventory_window.visible, "its inventory button opens the inventory")
	hud.inventory_window.close()
	expect(not done[0] and iwin.visible, "still waiting for Next battle")
	iwin.next_b.pressed.emit()
	await process_frame
	expect(done[0] and not iwin.visible and not hud.modal_layer.visible, "Next battle closes the screen and carries on")
	# ---- choice card (domino or artifact)
	got[0] = -5
	hud.pick_window.ask(g, "Victory!", "x", g._reward_cards(3), "Skip")
	await process_frame
	expect(hud.pick_window.grid.get_child_count() == 2 and hud.pick_window.grid.get_child(1).body.get_parsed_text().contains("artifact"), "the reward choice shows a domino card and an artifact card")
	hud.pick_window.grid.get_child(1).pressed.emit()
	await process_frame
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)
