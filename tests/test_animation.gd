extends SceneTree
## Tests for the animations, the pile windows and the speed setting. Run:
##   godot --headless -s tests/test_animation.gd

const Game = preload("res://scripts/game.gd")
const Settings = preload("res://scripts/settings.gd")
const Relics = preload("res://scripts/relics/relics.gd")

var _saved_settings = null     # the player's settings file, put back when the test ends

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
	_saved_settings = FileAccess.get_file_as_bytes(Settings.PATH) if FileAccess.file_exists(Settings.PATH) else null
	test_settings()
	await test_game_hooks()
	await test_ui()
	if _saved_settings != null:
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_buffer(_saved_settings)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	Settings.anim_speed = "medium"
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func test_settings() -> void:
	Settings.anim_speed = "medium"
	expect(Settings.speed_scale() == 1.0, "default speed is medium (the original pacing)")
	Settings.set_speed("fast")
	Settings.anim_speed = "medium"
	Settings.load_settings()
	expect(Settings.anim_speed == "fast", "the speed is saved and loaded again")
	Settings.set_speed("warp")
	expect(Settings.anim_speed == "fast", "an unknown speed is ignored")
	Settings.set_speed("instant")
	expect(Settings.speed_scale() == 0.0, "instant: scale 0, no animations")
	var scales := []
	for id in Settings.SPEED_ORDER:
		scales.append(Settings.SPEEDS[id])
	expect(scales == [1.75, 1.0, 0.5, 0.0], "slow, medium, fast, instant get shorter")
	Settings.set_speed("medium")


func test_game_hooks() -> void:
	var g := Game.new()
	var ui = g.ui
	expect(ui.entered.size() >= Game.START_HAND and ui.entered.all(func(e): return e.source == "stack"),
			"the first hand comes from the draw pile")
	ui.entered.clear()
	g.draw_one()
	expect(ui.entered.size() == 1 and ui.entered[0].card == g.hand.back() and ui.entered[0].source == "stack",
			"drawing tells the UI: from the stack")
	ui.entered.clear()
	var made = g.make_domino(0, 1, 2)
	expect(g.add_to_hand(made) and g.hand.back() == made and ui.entered[0].source == "top",
			"add_to_hand puts the domino in the hand, coming from the top")
	expect(g.history.has("card_added", {"source": "top"}), "add_to_hand is in the history")
	ui.entered.clear()
	while g.hand.size() < Game.MAXH:
		g.hand.append(g.make_domino(0, 0, 0))
	var late = g.make_domino(0, 4, 4)
	expect(not g.add_to_hand(late) and not g.hand.has(late) and ui.entered.is_empty(), "a full hand takes nothing")
	var gone = g.hand[3]
	g.discard_hand_card(3)
	expect(ui.discarded.size() == 1 and ui.discarded[0] == gone, "discard_hand_card tells the UI")
	ui.discarded.clear()
	expect(g.discard_random_from_hand() and ui.discarded.size() == 1 and g.discard.has(ui.discarded[0]),
			"a random discard tells the UI")
	# ephemeral dominoes are discarded when the turn ends
	var eph := -1
	for i in g.data.size():
		if g.data[i].ephemeral:
			eph = i
			break
	expect(eph >= 0, "there is an ephemeral domino kind to test with")
	if eph >= 0:
		g.hand.clear()
		ui.discarded.clear()
		var spent = g.make_domino(eph, 1, 2)
		g.hand.append(spent)
		g._discard_ephemeral()
		expect(ui.discarded == [spent] and g.discard.has(spent), "an ephemeral domino left in hand is flung away at the end of the turn")
	# a weapon that adds dominoes at the start of each turn: they come in from the top
	g.hand.clear()
	var kind = null
	for w in Relics.build_weapons():
		for add in w.adds:
			if add.when == "turn" and add.pos == "hand":
				kind = w
	if kind != null:
		g.weapon = kind
		ui.entered.clear()
		g._weapon_turn()
		expect(not ui.entered.is_empty() and ui.entered.all(func(e): return e.source == "top") and g.hand.size() == ui.entered.size(),
				"dominoes a weapon adds to your hand fly in from the top")
	ui.entered.clear()
	g.hand.clear()
	g.hand.append(g.make_domino(0, 0, 0))
	var order: Array = g.stack_order_by_title()
	var found = g.stack[order[0]]
	await g.tutor_take(order, 0)
	expect(ui.entered.size() == 1 and ui.entered[0].card == found and ui.entered[0].source == "stack",
			"finding a domino in the stack flies it from the draw pile")


func click(v) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	v._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	v._gui_input(up)


func flyers(hud) -> int:
	var n := 0
	for c in hud.fly_layer.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


func test_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var g = main.game
	var hud = main.hud
	await create_timer(1.2).timeout
	Settings.anim_speed = "fast"
	g.busy = 0
	g.ended = false
	expect(hud._anim_locked.is_empty() and flyers(hud) == 0, "the first hand has landed")

	# drawing: flies in from the draw pile, the slot is locked until it lands
	g.stack.append(g.make_domino(0, 3, 4))
	var n: int = g.hand.size()
	g.draw_one()
	main._refresh_ui()
	var v = hud.views[n]
	expect(v.locked and not v.playable and flyers(hud) == 1, "a drawn domino flies in and its slot is locked")
	var taps := [0]
	v.tapped.connect(func(_x): taps[0] += 1)
	click(v)
	expect(taps[0] == 0, "a flying domino cannot be selected")
	var f = hud.fly_layer.get_child(0)
	f._process(0.0)
	expect(f.center().is_equal_approx(hud._center_of(hud.stack_b)), "it starts at the draw pile button")
	await create_timer(0.7).timeout
	expect(not v.locked and flyers(hud) == 0 and hud._anim_locked.is_empty(), "when it lands the domino shows and the lock is gone")
	click(v)
	expect(taps[0] == 1, "a landed domino can be selected")

	# added by an effect: from the top of the screen
	n = g.hand.size()
	g.add_to_hand(g.make_domino(1, 2, 3))
	main._refresh_ui()
	f = hud.fly_layer.get_child(0)
	f._process(0.0)
	expect(hud.views[n].locked and is_equal_approx(f.center().y, -40.0), "an added domino comes in from the top of the screen")
	await create_timer(0.8).timeout
	expect(not hud.views[n].locked, "and lands in the hand")

	# several at once leave one after the other
	n = g.hand.size()
	g.stack.append_array([g.make_domino(0, 1, 1), g.make_domino(0, 2, 2), g.make_domino(0, 3, 3)])
	g.draw(3)
	main._refresh_ui()
	expect(flyers(hud) == 3 and hud.fly_layer.get_child(2)._delay > hud.fly_layer.get_child(1)._delay, "three draws leave the pile one after the other")
	await create_timer(1.0).timeout
	expect(hud._anim_locked.is_empty(), "all three landed")

	# discarding: flung off the screen
	var out = g.hand[0]
	g.discard_hand_card(0)
	expect(flyers(hud) == 1 and hud.fly_layer.get_child(0)._mode == "fling", "a discarded domino is flung away")
	hud.fly_layer.get_child(0)._process(100.0)
	expect(hud.fly_layer.get_child(0).center().y < 0.0, "it leaves the screen")
	await create_timer(0.1).timeout
	expect(flyers(hud) == 0 and g.discard.has(out), "and it is in the discard pile")

	# discarded before it landed: the same flyer is sent away
	g.stack.append(g.make_domino(0, 5, 5))
	g.draw_one()
	main._refresh_ui()
	expect(hud._anim_locked.size() == 1, "one domino is flying in")
	g.discard_hand_card(g.hand.size() - 1)
	expect(hud._anim_locked.is_empty() and flyers(hud) == 1 and hud.fly_layer.get_child(0)._mode == "fling",
			"a domino discarded in mid-air is flung from where it is")
	await create_timer(0.8).timeout
	expect(flyers(hud) == 0, "and is gone")

	# instant: nothing flies, nothing is locked
	Settings.anim_speed = "instant"
	g.stack.append(g.make_domino(0, 6, 6))
	n = g.hand.size()
	g.draw_one()
	main._refresh_ui()
	expect(flyers(hud) == 0 and not hud.views[n].locked, "instant: no flying and no lock")
	var out2 = g.hand[0]
	g.discard_hand_card(0)
	expect(flyers(hud) == 0, "instant: a discard just disappears")
	var t0 := Time.get_ticks_msec()
	await main.pause(5.0)
	expect(Time.get_ticks_msec() - t0 < 500, "instant: the game does not wait between steps")
	Settings.anim_speed = "fast"

	# cancelling (new game)
	g.stack.append(g.make_domino(0, 1, 2))
	n = g.hand.size()
	g.draw_one()
	main._refresh_ui()
	hud.cancel_animations()
	await process_frame
	expect(flyers(hud) == 0 and hud._anim_locked.is_empty() and not hud.views[n].locked, "cancel_animations clears the flights and the locks")

	# the pile windows
	main._refresh_ui()
	expect(hud.stack_b.text == "Stack %d" % g.stack.size() and hud.discard_b.text == "Discard %d" % g.discard.size(),
			"the Stack and Discard buttons show how many dominoes are in each pile")
	g.discard.clear()
	g.discard.append(g.make_domino(0, 1, 1))
	g.discard.append(g.make_domino(1, 2, 2))
	hud.discard_b.pressed.emit()
	var sw = hud.stack_window
	expect(sw.visible and hud.modal_layer.visible and sw.grid.get_child_count() == 2 and sw.title_l.text == "DISCARD PILE (2)",
			"the Discard button shows only the discarded dominoes")
	sw.close_b.pressed.emit()
	expect(not sw.visible and not hud.modal_layer.visible, "Close shuts the discard pile")
	g.discard.clear()
	hud.open_discard(g)
	expect(sw.visible and sw.grid.get_child_count() == 0 and sw.legend_l.text == "No dominoes in the discard pile.", "an empty discard pile says so")
	sw.close_b.pressed.emit()
	hud.stack_b.pressed.emit()
	expect(sw.visible and sw.title_l.text.begins_with("DOMINO STACK"), "the Stack button still shows the stack")
	sw.close_b.pressed.emit()

	# the speed setting in the settings window
	hud.open_settings()
	var row = hud.settings_window._speed_buttons
	expect(hud.settings_window.visible and row["fast"].button_pressed, "settings opens with the current speed marked")
	row["slow"].pressed.emit()
	Settings.anim_speed = "medium"
	Settings.load_settings()
	expect(Settings.anim_speed == "slow", "choosing a speed changes it and saves it")
	hud.settings_window.close_b.pressed.emit()
	expect(not hud.settings_window.visible, "Close shuts the settings")
	main.queue_free()
	await process_frame
