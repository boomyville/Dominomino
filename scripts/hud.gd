extends Control
## The whole on-screen interface, built from containers in scenes/hud.tscn:
##   top bar      hint, info window (the selected domino), energy and lives
##   bottom bar   stats, OK / Cancel, End turn and Reset
##   tray         the hand: one DominoView per domino
##   tags         HP / shield / status / intent over each character
##   floats       numbers that float up and fade
##   fly layer    dominoes flying into the hand (draw, added) or off the screen (discard)
##   windows      pick window and game over window
##   modal layer  settings, domino stack, inventory and the screen between battles (blocks the game below)
## main.gd tells it what to show with refresh(); it tells main.gd what the player did with signals.

signal end_turn_pressed
signal ok_pressed
signal cancel_pressed
signal new_game_pressed
signal title_new_game_pressed
signal title_load_game_pressed
signal quit_pressed
signal menu_pressed
signal restart_battle_pressed
signal rewind_turn_pressed
signal domino_tapped(view)
signal domino_drag_started(view)
signal domino_drag_moved(view, pos)
signal domino_drag_released(view, pos)
signal domino_rotate_requested(view)

const DominoViewScene = preload("res://scenes/domino_view.tscn")
const FloatingText = preload("res://scripts/floating_text.gd")
const DominoText = preload("res://scripts/domino_text.gd")
const Icons = preload("res://scripts/icons.gd")
const Settings = preload("res://scripts/settings.gd")
const FlyingDomino = preload("res://scripts/flying_domino.gd")
const DominoArt = preload("res://scripts/domino_art.gd")
const FLIGHT_SEC := 0.5        # one flight at medium speed (the setting scales it)
const STAGGER_SEC := 0.08      # dominoes that arrive together leave this far apart
const TAG_FADE := 0.3          # tags are this opaque while a domino is selected
const IDLE_RESET_MS := 10000

@onready var hint_l: Label = %HintLabel
@onready var energy_l: Label = %EnergyLabel
@onready var lives_l: Label = %LivesLabel
@onready var gems_l: Label = %GemsLabel
@onready var restart_b: Button = %RestartButton
@onready var rewind_b: Button = %RewindButton
@onready var victory_window = %VictoryWindow
@onready var shop_window = %ShopWindow
@onready var stats_l: Label = %StatsLabel
@onready var info_window = %InfoWindow
@onready var settings_b: Button = %SettingsButton
@onready var stack_b: Button = %StackButton
@onready var discard_b: Button = %DiscardButton
@onready var menu_b: Button = %MenuButton
@onready var title_screen = %TitleScreen
@onready var library_window = %LibraryWindow
@onready var fly_layer: Control = %FlyLayer
@onready var modal_layer: Control = %ModalLayer
@onready var dim: ColorRect = %Dim
@onready var settings_window = %SettingsWindow
@onready var stack_window = %StackWindow
@onready var inventory_window = %InventoryWindow
@onready var intermission_window = %IntermissionWindow
@onready var actions: HBoxContainer = %Actions
@onready var cancel_b: Button = %CancelButton
@onready var ok_b: Button = %OkButton
@onready var end_b: Button = %EndTurnButton
@onready var reset_b: Button = %ResetButton
@onready var tray: PanelContainer = %Tray
@onready var hand_box: HBoxContainer = %Hand
@onready var enemy_tag = %EnemyTag
@onready var player_tag = %PlayerTag
@onready var relic_bar: HFlowContainer = %RelicBar
@onready var floats: Control = %Floats
@onready var toast_l: Label = %Toast
@onready var pick_window = %PickWindow
@onready var game_over = %GameOver
@onready var flash_rect: ColorRect = %FlashRect
@onready var ghost = %Ghost

var dot_tex: Texture2D = null       # the 2x2 pip image, set by main.gd
var views: Array = []                # the DominoViews in the tray, in hand order
var last_play := 0
var toast_until := 0
var toast_blink_until := 0
var flash_t0 := -100000
var _game = null
var _pending := false
var _relic_ids := []
var _last_st := {}
var _entering: Array = []            # [{d, from}] dominoes that just went into the hand, waiting for refresh()
var _anim_locked := {}               # Domino -> true while its flying copy is arriving (its slot is locked)
var _flying := {}                    # Domino -> its FlyingDomino


func _ready() -> void:
	Settings.load_settings()
	settings_b.pressed.connect(open_settings)
	restart_b.pressed.connect(func(): restart_battle_pressed.emit())
	rewind_b.pressed.connect(func(): rewind_turn_pressed.emit())
	shop_window.closed.connect(_on_shop_closed)
	intermission_window.shop_pressed.connect(func(): open_shop(_game))
	stack_b.pressed.connect(func(): open_stack(_game, true))
	discard_b.pressed.connect(func(): open_discard(_game))
	menu_b.pressed.connect(func(): menu_pressed.emit())
	title_screen.new_game_pressed.connect(func(): title_new_game_pressed.emit())
	title_screen.load_game_pressed.connect(func(): title_load_game_pressed.emit())
	title_screen.quit_pressed.connect(func(): quit_pressed.emit())
	title_screen.settings_pressed.connect(open_settings)
	title_screen.library_pressed.connect(open_library)
	library_window.closed.connect(_sync_modal)
	settings_window.changed.connect(_on_settings_changed)
	for w in [settings_window, stack_window, inventory_window]:
		w.closed.connect(_sync_modal)
	intermission_window.stack_pressed.connect(func(): open_stack(_game, false))
	intermission_window.inventory_pressed.connect(func(): open_inventory(_game))
	cancel_b.pressed.connect(func(): cancel_pressed.emit())
	ok_b.pressed.connect(func(): ok_pressed.emit())
	end_b.pressed.connect(func(): end_turn_pressed.emit())
	reset_b.pressed.connect(func(): new_game_pressed.emit())
	game_over.new_game_pressed.connect(func(): new_game_pressed.emit())
	toast_l.visible = false
	ghost.visible = false
	last_play = Time.get_ticks_msec()


## Show the current game. st = {sel, pending, drag_index, pending_index}.
func refresh(game, st: Dictionary) -> void:
	_game = game
	_last_st = st
	_pending = st.pending
	energy_l.text = "Energy %d" % game.energy
	lives_l.text = "Lives x%d" % game.lives
	gems_l.text = "Gems %d" % game.gems
	restart_b.disabled = game.busy != 0 and not game.ended
	rewind_b.visible = game.has_rewind()
	rewind_b.disabled = not game.can_rewind_turn() or st.pending
	var s: Dictionary = game.stats
	stats_l.text = "Played %d\nEnergy wasted %d\nBattle %d, turn %d" % [
			s.played, s.wasted, game.battle_no, game.history.turn]
	stack_b.text = "Stack %d" % game.stack.size()
	discard_b.text = "Discard %d" % game.discard.size()
	if game.busy == 2:
		hint_l.text = "Resolving effects"
	elif game.busy == 3:
		hint_l.text = "Victory!"
	elif game.busy != 0:
		hint_l.text = "Computer turn"
	elif st.pending:
		hint_l.text = "Tap the domino or press OK to place it"
	elif st.drag_index >= 0:
		hint_l.text = "Right-click or second finger to rotate"
	elif st.sel >= 0:
		hint_l.text = "Tap to rotate. Drag onto the board."
	else:
		hint_l.text = "Select a domino"
	# the info window is the selected domino (at 30% opacity, set in the scene)
	var show_info: bool = st.sel >= 0 and st.sel < game.hand.size() and not game.ended and game.busy == 0
	info_window.visible = show_info
	if show_info:
		info_window.show_domino(game, game.hand[st.sel], st.sel)
	actions.visible = st.pending
	end_b.disabled = game.busy != 0 or game.ended or st.pending
	_sync_tray(game, st)
	_sync_relics(game)
	update_tags(game, st)


func _sync_tray(game, st: Dictionary) -> void:
	while views.size() < game.hand.size():
		var v = DominoViewScene.instantiate()
		v.dot_tex = dot_tex
		hand_box.add_child(v)
		v.tapped.connect(func(view): domino_tapped.emit(view))
		v.drag_started.connect(func(view): domino_drag_started.emit(view))
		v.drag_moved.connect(func(view, pos): domino_drag_moved.emit(view, pos))
		v.drag_released.connect(func(view, pos): domino_drag_released.emit(view, pos))
		v.rotate_requested.connect(func(view): domino_rotate_requested.emit(view))
		views.append(v)
	while views.size() > game.hand.size():
		var gone = views.pop_back()
		hand_box.remove_child(gone)
		gone.queue_free()
	_start_entries(game)
	for i in game.hand.size():
		var locked: bool = _anim_locked.has(game.hand[i])
		var can: bool = game.busy == 0 and not game.ended and not st.pending and not locked and game.can_play(i)
		var hide_it: bool = i == st.drag_index or i == st.pending_index
		views[i].update_view(game.hand[i], i, i == st.sel and not locked, can, game.caps(i), hide_it, locked)


# ---- dominoes flying in and out -------------------------------------------

## game.gd says a domino went into the hand (source "stack" or "top"). It starts flying at the next
## refresh(), when its slot in the tray exists.
func queue_entry(d, source: String) -> void:
	_entering.append({"d": d, "from": source})


## Start a flight for every queued domino whose slot exists. Its slot is locked until it lands.
func _start_entries(game) -> void:
	var scale := Settings.speed_scale()
	var n := 0
	for e in _entering:
		var i: int = game.hand.find(e.d)
		if i < 0 or i >= views.size() or scale <= 0.0:
			continue
		_launch_arrival(e.d, e.from, n * STAGGER_SEC * scale, scale)
		n += 1
	_entering.clear()


func _launch_arrival(d, source: String, delay: float, scale: float) -> void:
	var f = FlyingDomino.new()
	f.setup(d, dot_tex)
	fly_layer.add_child(f)
	_anim_locked[d] = true
	_flying[d] = f
	var from_fn: Callable
	var arc := 56.0
	var dur := FLIGHT_SEC
	if source == "stack":
		from_fn = func(): return _center_of(stack_b)
	else:
		# from above the screen, a little to one side of the slot
		var side := randf_range(-70.0, 70.0)
		from_fn = func(): return Vector2(_center_of(tray).x + side, -40.0)
		arc = 24.0
		dur = FLIGHT_SEC * 1.3
	f.arrive(from_fn, _slot_center.bind(d), dur * scale, delay, arc)
	f.finished.connect(_on_flyer_finished.bind(d))


func _center_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## The view that shows this domino (as of the last refresh), or null.
func view_for(d):
	for v in views:
		if v.domino == d:
			return v
	return null


## Where the domino's flat picture sits in its slot (the flyer lands there), or null if it has no slot.
func _slot_center(d):
	var v = view_for(d)
	if v == null or not v.is_inside_tree():
		return null
	return v.global_position + Vector2(v.size.x / 2.0, 30.0)


func _on_flyer_finished(_landed: bool, d) -> void:
	_anim_locked.erase(d)
	_flying.erase(d)
	var v = view_for(d)
	if v != null:
		v.set_locked(false)


## A domino was discarded: it flies off the screen. Its slot disappears at the next refresh().
func fling(d) -> void:
	var scale := Settings.speed_scale()
	var vp := get_viewport_rect().size
	var v = view_for(d)
	if v != null:
		v.set_locked(true)
	if scale <= 0.0:
		if _flying.has(d):
			_flying[d].queue_free()
			_on_flyer_finished(false, d)
		return
	var from := _center_of(tray)
	if v != null:
		from = v.global_position + Vector2(v.size.x / 2.0, 30.0)
	var dir := 1.0 if from.x >= vp.x / 2.0 else -1.0
	var to := Vector2(vp.x / 2.0 + dir * vp.x * 0.75, -140.0)
	var f
	if _flying.has(d):
		f = _flying[d]            # it never landed: send it away from where it is now
		f.finished.disconnect(_on_flyer_finished.bind(d))
		_flying.erase(d)
		_anim_locked.erase(d)
	else:
		f = FlyingDomino.new()
		f.setup(d, dot_tex)
		fly_layer.add_child(f)
	f.fling(from, to, FLIGHT_SEC * 1.1 * scale, 70.0, dir * TAU * 1.2)


## Stop every flight (new game, rewind): the dominoes just appear where they belong.
func cancel_animations() -> void:
	for c in fly_layer.get_children():
		c.queue_free()
	_anim_locked.clear()
	_flying.clear()
	_entering.clear()
	for v in views:
		v.set_locked(false)


## The relic icons in the top right corner (hover for the text, tap to see it).
func _sync_relics(game) -> void:
	var shown: Array = ([game.weapon] if game.weapon != null else []) + game.relics
	var ids := []
	for r in shown:
		ids.append("%s:%d:%s" % [r.id, r.level, r.counter_text()])      # a new level or counter redraws the icon
	if ids == _relic_ids:
		return
	_relic_ids = ids
	for c in relic_bar.get_children():
		relic_bar.remove_child(c)
		c.queue_free()
	for r in shown:
		var icon := TextureRect.new()
		icon.texture = Icons.relic_texture(r)
		icon.custom_minimum_size = Vector2(Icons.RELIC_SIZE, Icons.RELIC_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.tooltip_text = r.tooltip()
		icon.gui_input.connect(_on_relic_input.bind(r))
		if r.counter_text() != "":
			icon.add_child(_counter_badge(r.counter_text()))     # the counter, in the corner of the icon
		relic_bar.add_child(icon)


## The small number in the bottom right corner of an artifact that has a counter.
func _counter_badge(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color.BLACK)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return l


func _on_relic_input(event: InputEvent, relic) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toast(relic.tooltip().replace("\n", ": "))


## The HP / shield / status / intent boxes. While a domino is selected they fade to TAG_FADE so the
## board shows through, the enemy's HP bar marks the HP the domino would take, and (always) your
## HP bar marks the HP the enemy's planned attacks would take.
func update_tags(game, st: Dictionary = {}) -> void:
	var foe = game.foe
	var pl = game.pl
	var idx: int = st.get("sel", -1)
	if idx < 0:
		idx = st.get("pending_index", -1)
	var picking: bool = idx >= 0 and idx < game.hand.size() and not game.ended and game.busy == 0
	var fade := TAG_FADE if picking else 1.0
	enemy_tag.modulate.a = fade
	player_tag.modulate.a = fade

	var foe_loss := 0
	var foe_note := ""
	if picking:
		var pv: Dictionary = game.preview_player_attack(idx)
		foe_loss = pv.hp
		if pv.attack and pv.hp == 0:
			foe_note = "(blocked)" if pv.absorbed > 0 else "(no damage)"
	var show_taken: bool = Settings.show_damage_taken
	var plan: Dictionary = game.preview_intents(show_taken)
	var pl_loss: int = plan.loss if show_taken else 0
	var pl_note := "(blocked)" if show_taken and plan.attacks > 0 and plan.loss == 0 and plan.absorbed > 0 else ""

	var foe_status: Array = [{"k": "shield", "text": "Shield %d" % foe.shield, "name": "Shield", "num": str(foe.shield)}] + foe.status_entries()
	enemy_tag.show_combatant("%s  LV %d" % [foe.title.to_upper(), foe.lv], foe.hp, foe.max_hp, foe_status, plan.entries, foe_loss, foe_note)
	var pl_status: Array = [{"k": "shield", "text": "Shield %d/%d" % [pl.shield, pl.max_shield], "name": "Shield",
			"num": "%d/%d" % [pl.shield, pl.max_shield]}] + pl.status_entries()
	player_tag.show_combatant("YOU", pl.hp, pl.max_hp, pl_status, [], pl_loss, pl_note)


## Put the tags just above the characters. Anchors are the bottom-centre of each tag.
func place_tags(enemy_anchor: Vector2, player_anchor: Vector2) -> void:
	_place(enemy_tag, enemy_anchor)
	_place(player_tag, player_anchor)


func _place(tag: Control, anchor: Vector2) -> void:
	var vp := get_viewport_rect().size
	var s: Vector2 = tag.size
	tag.position = Vector2(clampf(anchor.x - s.x / 2.0, 4.0, vp.x - s.x - 4.0), maxf(4.0, anchor.y - s.y))


## Top-centre of a character's tag ("c" enemy, "p" player): where its floating numbers start.
func tag_top(who: String) -> Vector2:
	var t = enemy_tag if who == "c" else player_tag
	return Vector2(t.position.x + t.size.x / 2.0, t.position.y)


func spawn_float(text: String, pos: Vector2) -> void:
	var f := FloatingText.new()
	floats.add_child(f)
	f.start(text, pos)


func toast(text: String, blink: bool = false) -> void:
	var now := Time.get_ticks_msec()
	toast_l.text = text
	toast_until = now + 1400
	toast_blink_until = now + 1200 if blink else 0


func flash() -> void:
	flash_t0 = Time.get_ticks_msec()


func note_play() -> void:
	last_play = Time.get_ticks_msec()


func pick(game, title: String, sub: String, list: Array, skip: String = "") -> int:
	var r: int = await pick_window.ask(game, title, sub, list, skip)
	return r


## ---- modal windows ------------------------------------------------------

## The title screen covers everything until a run starts. has_save enables Load game.
func show_title(has_save: bool) -> void:
	title_screen.set_has_save(has_save)
	title_screen.visible = true


func hide_title() -> void:
	title_screen.visible = false


func open_library() -> void:
	library_window.open(_game)
	_sync_modal()


func open_settings() -> void:
	settings_window.open(_game)
	_sync_modal()


func open_shop(game) -> void:
	if game == null:
		return
	shop_window.open(game)
	_sync_modal()


func _on_shop_closed() -> void:
	if _game != null:
		_game.leave_shop()                 # the library notes what you could afford and left
		_game.shop_pending = false         # you have been to the shop: now it is Next battle
		intermission_window.show_stats(_game)
	_sync_modal()


## The victory screen (damage dealt, HP lost, gems). Waits for Continue.
func victory(game, summary: Dictionary) -> void:
	_game = game
	victory_window.ask(game, summary)
	_sync_modal()
	await victory_window.continue_pressed
	_sync_modal()


## in_battle: false shows the whole collection at full opacity (between battles).
func open_stack(game, in_battle: bool) -> void:
	if game == null:
		return
	stack_window.open(game, in_battle)
	_sync_modal()


## The discard pile, nothing else (the latest discarded first).
func open_discard(game) -> void:
	if game == null:
		return
	stack_window.open_discard(game)
	_sync_modal()


func open_inventory(game) -> void:
	if game == null:
		return
	inventory_window.open(game)
	_sync_modal()


## The screen between battles. Waits until Next battle is pressed.
func intermission(game) -> void:
	_game = game
	intermission_window.ask(game)
	_sync_modal()
	await intermission_window.next_pressed
	_sync_modal()


## The modal layer is only there (and only blocks the game under it) while a window is open.
func _sync_modal() -> void:
	var any: bool = settings_window.visible or stack_window.visible or inventory_window.visible \
			or intermission_window.visible or victory_window.visible or shop_window.visible or library_window.visible
	modal_layer.visible = any
	dim.visible = not intermission_window.visible


func _on_settings_changed() -> void:
	if _game != null:
		refresh(_game, _last_st)
	stack_window.refresh_info()


func show_game_over(rows: Array) -> void:
	game_over.show_stats(rows)


func hide_game_over() -> void:
	game_over.visible = false


## The domino that follows the pointer while it is dragged off the board (over the tray).
func set_ghost(show_it: bool, d, pos: Vector2) -> void:
	ghost.visible = show_it
	if show_it:
		ghost.dot_tex = dot_tex
		ghost.size = Vector2(56, 28)
		ghost.set_domino(d.a, d.b, d.ang, true, DominoArt.sides(d))
		ghost.position = pos - ghost.size / 2.0


## Where the tray starts (a drag above this line is a drag onto the board).
func tray_top() -> float:
	return tray.get_global_rect().position.y


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _game != null:
		var stuck: bool = _game.busy == 0 and not _game.ended and not _pending and not _game.playable_any()
		end_b.modulate = Color(0.35, 0.35, 0.35) if (stuck and int(now / 350.0) % 2 == 0) else Color.WHITE
		reset_b.visible = not _game.ended and _game.busy == 0 and now - last_play > IDLE_RESET_MS
	var blinking := now < toast_blink_until
	toast_l.visible = now < toast_until and (not blinking or int(now / 150.0) % 2 == 0)
	var fa := now - flash_t0
	flash_rect.color.a = 0.45 if (fa < 1050 and int(fa / 175.0) % 2 == 0) else 0.0
