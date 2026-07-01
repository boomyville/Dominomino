extends Node2D

onready var board = $GridPosition/Board
onready var hand = $PlayerHandPosition/PlayerHand 
onready var ok_button = $UI/UIPosition/UIContainer/OKButton
onready var undo_button = $UI/UIPosition/UIContainer/UndoButton
onready var energy_label = $UI/EnergyPosition/Energy
onready var chain_label = $UI/EnergyPosition/Chain
onready var settings_button = $UI/SettingsPosition/SettingsButton
onready var end_turn_button = $UI/EndTurnPosition/EndTurnButton
onready var rotate_button = $UI/UIPosition/UIContainer/RotateButton

const SETTINGS_POPUP_SCENE = preload("res://scenes/settings.tscn")

enum PlayState { IDLE, DRAGGING, VERIFYING, PROCESSING, REPOSITIONING }

export var player_data: Resource  # This is assigned in the editor

var player_draw_pile: Array = []
var player_discard_pile: Array = []
var player_void_pile: Array = []
var current_play_state = PlayState.IDLE
var active_domino = null
var active_domino_origin = Vector2.ZERO
var last_placed_domino = null
var last_placed_origin = Vector2.ZERO
var last_placed_slot = null
var domino_snap_offset: Vector2 = Vector2.ZERO

# Cached result from the last evaluate_candidate_placement call so _on_ok_pressed
# can apply the correct discounted cost without re-scanning the board.
var _last_placement_eval: Dictionary = {"valid": false, "matched_reduction": 0, "has_any_match": false}

func _ready() -> void:
	randomize()

	ok_button.connect("pressed", self, "_on_ok_pressed")
	undo_button.connect("pressed", self, "_on_undo_pressed")
	rotate_button.connect("pressed", self, "_on_rotate_pressed")
	_toggle_verification_ui(false)

	settings_button.connect("pressed", self, "_on_settings_pressed")
	end_turn_button.connect("pressed", self, "_on_end_turn_pressed")

	GameState.connect("player_energy_changed", self, "_on_energy_adjusted")
	GameState.connect("player_chain_changed", self, "_on_chain_adjusted")

	prepare_combat_draw_pile()

	GameState.load_player(player_data)     
	draw_dominoes(GameState.player_starting_draw)

	_refresh_hand_playability()

	var temp = preload("res://scenes/domino.tscn").instance()
	var sprite = temp.get_node_or_null("BaseSprite")
	if sprite and sprite.texture:
		var size = sprite.texture.get_size() * sprite.scale
		domino_snap_offset = Vector2(0, 0)
	temp.free()

func _process(_delta) -> void:
	if active_domino != null and current_play_state == PlayState.DRAGGING:
		var visual_offset = active_domino.get_placement_offset()
		var logical_pos = active_domino.global_position - visual_offset
		var grid_pos = board.world_to_grid(logical_pos)
		var gx = int(grid_pos.x)
		var gy = int(grid_pos.y)
		var vertical = active_domino.is_vertical()
		# Always call highlight_preview — board.gd decides tile3 (valid), tile4 (pip-blocked),
		# or nothing (cells occupied/OOB) internally.
		board.highlight_preview(gx, gy, vertical, active_domino)

func _on_domino_clicked(domino) -> void:
	print("_on_domino_clicked | state: ", current_play_state, " | domino: ", domino, " | last_placed: ", last_placed_domino)

	if hand.is_shuffling:
		return

	if current_play_state == PlayState.VERIFYING and domino == last_placed_domino:
		board.remove_domino_from_matrix(last_placed_domino)
		active_domino = last_placed_domino
		active_domino_origin = last_placed_origin
		active_domino.current_status = active_domino.StatusType.HAND
		last_placed_domino = null
		current_play_state = PlayState.DRAGGING
		_toggle_verification_ui(false)

		var global_pos = active_domino.global_position
		var old_parent = active_domino.get_parent()
		old_parent.remove_child(active_domino)
		$DragLayer.add_child(active_domino)
		active_domino.global_position = global_pos

		active_domino.start_drag_from(get_global_mouse_position())
		return

	if last_placed_domino != null:
		return

	if not Settings.mouse_mode_enabled and current_play_state == PlayState.DRAGGING and active_domino == domino:
		_try_place_active_domino()
		return

	if current_play_state != PlayState.IDLE:
		return

	active_domino = domino
	active_domino_origin = domino.global_position
	last_placed_slot = domino.get_parent()
	current_play_state = PlayState.DRAGGING
	active_domino.set_selected_visual(true)
	_refresh_domino_selection_visuals()

	var global_pos = domino.global_position
	last_placed_slot.remove_child(domino)
	$DragLayer.add_child(domino)
	domino.global_position = global_pos

	if Settings.mouse_mode_enabled:
		domino.start_drag()
	else:
		domino.start_drag_from(get_global_mouse_position())

	_toggle_verification_ui(false)

func _input(event) -> void:
	if event is InputEventMouseButton:
		var ui_rect = $UI/UIPosition/UIContainer.get_global_rect()
		var settings_rect = $UI/SettingsPosition/SettingsButton.get_global_rect()
		var mouse_pos = get_global_mouse_position()
		if ui_rect.has_point(mouse_pos) or settings_rect.has_point(mouse_pos):
			return

	if not Settings.mouse_mode_enabled:
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
			if current_play_state == PlayState.DRAGGING and active_domino != null:
				_try_place_active_domino()
				get_tree().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
			if current_play_state == PlayState.DRAGGING and active_domino != null:
				active_domino.rotate_domino()
				get_tree().set_input_as_handled()
				return
		return

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		if current_play_state == PlayState.DRAGGING and active_domino != null:
			_try_place_active_domino()

	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		if current_play_state == PlayState.DRAGGING and active_domino != null:
			active_domino.rotate_domino()

func _try_place_active_domino() -> void:
	print("Call try_place_active_domino at:", OS.get_ticks_msec())

	var visual_offset = active_domino.get_placement_offset()
	var logical_pos = active_domino.global_position - visual_offset
	var grid_pos = board.world_to_grid(logical_pos)
	var gx = int(grid_pos.x)
	var gy = int(grid_pos.y)
	var vertical = active_domino.is_vertical()

	if not board.is_placement_valid(gx, gy, vertical, active_domino):
		board.clear_preview()
		_cancel_active_domino()
		return

	var eval = board.evaluate_candidate_placement(active_domino, gx, gy, vertical)
	var cost = GameState.calculate_domino_cost_discounted(
		active_domino.left_pip_value,
		active_domino.right_pip_value,
		eval.get("matched_reduction", 0)
	)
	if GameState.current_player_energy < cost:
		board.clear_preview()
		_cancel_active_domino()
		return	

	# Cache the evaluation result so _on_ok_pressed can use the exact discount
	# that applied to this placement without re-scanning.
	_last_placement_eval = board.evaluate_candidate_placement(active_domino, gx, gy, vertical)

	board.clear_preview()
	var old_parent = active_domino.get_parent()
	old_parent.remove_child(active_domino)
	board.add_child(active_domino)

	var snap_world = board.grid_to_world(gx, gy)
	active_domino.global_position = snap_world + visual_offset
	print("Active domino global pos: ", active_domino.global_position, " | Rotation: ", active_domino.rotation_step, " | Snap world pos: ", snap_world, " | Visual offset: ", visual_offset)

	board.place_domino_on_matrix(active_domino, gx, gy)
	active_domino.z_index = gy
	active_domino.stop_drag()
	active_domino.current_status = active_domino.StatusType.BOARD

	last_placed_domino = active_domino
	last_placed_origin = active_domino_origin
	var placed_domino = active_domino
	placed_domino.set_selected_visual(false)

	active_domino = null
	# NOTE: Do NOT call _refresh_domino_selection_visuals() here.
	# Still pending OK/Undo — hand shaders stay suppressed until move is resolved.

	hand.clean_and_reposition_hand()

	if Settings.fast_mode_enabled:
		_on_ok_pressed()
	else:
		current_play_state = PlayState.VERIFYING
		_toggle_verification_ui(true)

func _cancel_active_domino() -> void:
	print("_cancel_active_domino called | active: ", active_domino)
	if active_domino == null:
		return
	var domino = active_domino
	var origin = active_domino_origin
	domino.set_selected_visual(false)
	active_domino = null
	current_play_state = PlayState.IDLE
	board.clear_preview()

	_toggle_verification_ui(false)

	var current_parent = domino.get_parent()

	if current_parent == $DragLayer:
		var global_pos_before = domino.global_position
		$DragLayer.remove_child(domino)

		if not is_instance_valid(last_placed_slot) or last_placed_slot.get_parent() == null:
			last_placed_slot = Control.new()
			last_placed_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			last_placed_slot.rect_min_size = Vector2(48, 28)
			hand.add_child(last_placed_slot)

		last_placed_slot.add_child(domino)
		domino.position = last_placed_slot.get_global_transform().affine_inverse().xform(global_pos_before)

	domino.return_to_hand(origin)

	# Refresh AFTER the domino is back in its hand slot so the loop sees it.
	_refresh_domino_selection_visuals()

	# Also reset chain — the player cancelled, no match was committed.
	GameState.reset_chain()

func _sort_board_dominoes_by_y() -> void:
	var dominoes = []
	for child in board.get_children():
		if child is Area2D:
			dominoes.append(child)
	dominoes.sort_custom(self, "_sort_by_y")
	for domino in dominoes:
		board.remove_child(domino)
	for domino in dominoes:
		board.add_child(domino)

func _sort_by_y(a, b) -> bool:
	return a.global_position.y < b.global_position.y

func _toggle_verification_ui(show_verification: bool) -> void:
	ok_button.visible = show_verification
	undo_button.visible = show_verification
	if not Settings.mouse_mode_enabled and current_play_state == PlayState.DRAGGING and active_domino != null:
		rotate_button.visible = true
	else:
		rotate_button.visible = false

func _on_ok_pressed() -> void:
	if last_placed_domino == null:
		return

	# Apply the cached discounted cost from the actual placement evaluation.
	var cost = GameState.calculate_domino_cost_discounted(
		last_placed_domino.left_pip_value,
		last_placed_domino.right_pip_value,
		_last_placement_eval.get("matched_reduction", 0)
	)

	if GameState.current_player_energy < cost:
		# Failsafe - should never happen if the hand playability logic is correct. 
		return

	GameState.spend_player_energy(cost)

	# Update chain: increment if a pip-match occurred, reset if played isolated.
	if _last_placement_eval.get("has_any_match", false):
		GameState.increment_chain()
	else:
		GameState.reset_chain()

	_last_placement_eval = {"valid": false, "matched_reduction": 0, "has_any_match": false}

	last_placed_domino.lock_to_board()
	_sort_board_dominoes_by_y()
	last_placed_domino = null
	last_placed_origin = Vector2.ZERO

	# Move is fully committed: restore in-hand green highlights.
	_refresh_domino_selection_visuals()

	if current_play_state != PlayState.REPOSITIONING:
		current_play_state = PlayState.IDLE

	_toggle_verification_ui(false)

func _on_undo_pressed() -> void:
	print("_on_undo_pressed called")
	if last_placed_domino == null:
		return

	board.remove_domino_from_matrix(last_placed_domino)
	var board_parent = last_placed_domino.get_parent()
	var global_pos_before = last_placed_domino.global_position
	board_parent.remove_child(last_placed_domino)

	if not is_instance_valid(last_placed_slot) or last_placed_slot.get_parent() == null:
		last_placed_slot = Control.new()
		last_placed_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		last_placed_slot.rect_min_size = Vector2(48, 28)
		hand.add_child(last_placed_slot)

	last_placed_slot.add_child(last_placed_domino)
	last_placed_domino.position = last_placed_slot.get_global_transform().affine_inverse().xform(global_pos_before)

	last_placed_domino.current_status = last_placed_domino.StatusType.HAND
	last_placed_domino.input_pickable = true

	last_placed_domino.return_to_hand(last_placed_origin)

	last_placed_domino = null
	last_placed_origin = Vector2.ZERO
	last_placed_slot = null
	_last_placement_eval = {"valid": false, "matched_reduction": 0, "has_any_match": false}
	current_play_state = PlayState.IDLE
	_toggle_verification_ui(false)

	# Move cancelled: restore in-hand green highlights.
	_refresh_domino_selection_visuals()

	hand.clean_and_reposition_hand()

func _on_rotate_pressed() -> void:
	if current_play_state == PlayState.DRAGGING and active_domino != null:
		active_domino.rotate_domino()

# ===================================================================================
# Domino draw and stack management logic
# ===================================================================================
func prepare_combat_draw_pile() -> void:
	player_draw_pile.clear()
	player_discard_pile.clear()
	for base_resource in player_data.stack:  # was player_stack
		if base_resource is DominoData:
			var runtime_copy = base_resource.duplicate()
			player_draw_pile.append(runtime_copy)

func draw_dominoes(amount: int) -> void:
	for _i in range(amount):
		if player_draw_pile.empty():
			if player_discard_pile.empty():
				print("The player's deck is completely exhausted!")
				break
			_player_draw_pile_empty()
		var random_idx = randi() % player_draw_pile.size()
		var chosen_domino_data: DominoData = player_draw_pile[random_idx]
		player_draw_pile.remove(random_idx)
		print("Drawing domino index [", _i, "] - Left Pip: ", chosen_domino_data.base_left_pip, " Right Pip: ", chosen_domino_data.base_right_pip)
		if hand.has_method("add_domino_to_hand"):
			hand.add_domino_to_hand(chosen_domino_data)
		else:
			push_error("CRITICAL: player_hand script is missing the add_domino_to_hand function!")

func _recycle_player_discard_pile() -> void:
	print("Refilling draw pile from discard graveyard...")
	player_draw_pile = player_discard_pile.duplicate()
	player_discard_pile.clear()

func _player_draw_pile_empty() -> void:
	print("Player has no more dominoes to draw! Game over!")
	return

func _on_energy_adjusted(new_energy: int) -> void:
	energy_label.text = str(new_energy)
	_refresh_hand_playability()

func _on_chain_adjusted(new_chain: int) -> void:
	chain_label.text = str(new_chain)

# ===================================================================================
# Hand playability — determines which shader each hand domino gets.
# 
# For each hand domino we determine:
#   1. Can afford full cost with no adjacency needed?  → FULL_COST_PLAYABLE (outline)
#   2. Can't afford full cost, BUT there exists at least one board position (across all
#      4 rotations) where a valid pip-match reduces the cost to affordable?  → MATCH_PLAYABLE (outline2)
#   3. Neither?  → UNPLAYABLE
#
# Note: a domino that CAN afford full cost might ALSO have match opportunities.
# In that case FULL_COST_PLAYABLE takes priority — the player is free to play it
# either way and the base outline communicates "you can play this right now."
# ===================================================================================

func _refresh_hand_playability() -> void:
	for slot in hand.get_children():
		if slot.get_child_count() == 0:
			continue
		var domino = slot.get_child(0)
		if domino == null or not domino.has_method("set_playability_visual"):
			continue

		var full_cost = GameState.calculate_domino_cost(domino.left_pip_value, domino.right_pip_value)
		var can_afford_full = GameState.current_player_energy >= full_cost

		if not can_afford_full:
			# Check if a match discount makes it affordable
			var has_affordable_match = _scan_board_for_match_placement(domino, true)
			if has_affordable_match:
				domino.set_playability_visual(domino.PlayabilityMode.MATCH_PLAYABLE)
			else:
				domino.set_playability_visual(domino.PlayabilityMode.UNPLAYABLE)
		else:
			# Can afford full cost — check if a match exists anyway for shader2
			var has_any_match = _scan_board_for_match_placement(domino, false)
			if has_any_match:
				domino.set_playability_visual(domino.PlayabilityMode.MATCH_PLAYABLE)
			else:
				domino.set_playability_visual(domino.PlayabilityMode.FULL_COST_PLAYABLE)

# Tries all 4 rotations of the domino at every geometrically valid empty cell pair
# on the board. Returns true as soon as one valid pip-matching placement is found
# that the player can currently afford after the discount.
func _scan_board_for_match_placement(domino, require_affordable: bool = false) -> bool:
	var original_rotation = domino.rotation_step

	for rot in range(4):
		domino.rotation_step = rot
		var vertical = domino.is_vertical()

		for y in range(board.grid_size):
			for x in range(board.grid_size):
				if not board.is_geometry_valid(x, y, vertical):
					continue

				var eval = board.evaluate_candidate_placement(domino, x, y, vertical)

				if not eval.valid:
					continue
				if not eval.has_any_match:
					continue

				if require_affordable:
					var discounted_cost = GameState.calculate_domino_cost_discounted(
						domino.left_pip_value,
						domino.right_pip_value,
						eval.matched_reduction
					)
					if GameState.current_player_energy < discounted_cost:
						continue

				domino.rotation_step = original_rotation
				return true

	domino.rotation_step = original_rotation
	return false

func _refresh_domino_selection_visuals() -> void:
	if active_domino != null:
		# A domino is being dragged — suppress all other hand dominoes cleanly.
		# Use set_playability_visual(UNPLAYABLE) rather than set_selectable_visual(false)
		# so we go through the proper material/shader path and don't leave stale state.
		for slot in hand.get_children():
			if slot.get_child_count() == 0:
				continue
			var domino = slot.get_child(0)
			if domino == active_domino:
				domino.set_selected_visual(true)
			elif domino.has_method("set_playability_visual"):
				domino.set_selected_visual(false)
				domino.set_playability_visual(domino.PlayabilityMode.UNPLAYABLE)
	else:
		# No active drag — restore every hand domino to its correct shader state.
		# Delegate entirely to _refresh_hand_playability so shader1 vs shader2
		# is decided consistently in one place.
		for slot in hand.get_children():
			if slot.get_child_count() == 0:
				continue
			var domino = slot.get_child(0)
			domino.set_selected_visual(false)
		_refresh_hand_playability()

func _on_settings_pressed() -> void:
	if current_play_state == PlayState.DRAGGING:
		return
	var popup_instance = SETTINGS_POPUP_SCENE.instance()
	$UI.add_child(popup_instance)
	popup_instance.popup_centered()

func _on_end_turn_pressed() -> void:
	# For testing, draw dominos and reset energy/chain.
	# In a real game, this would trigger the enemy's turn and any end-of-turn
	
	draw_dominoes(GameState.player_draw_per_turn)
	GameState.restore_energy_for_turn()
	GameState.reset_chain()

