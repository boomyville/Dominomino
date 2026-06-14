# game.gd
extends Node2D

onready var board = $GridPosition/Board
onready var hand = $PlayerHandPosition/PlayerHand 
onready var ok_button = $UI/UIPosition/UIContainer/OKButton
onready var undo_button = $UI/UIPosition/UIContainer/UndoButton
onready var energy_label = $UI/EnergyPosition/Label
onready var settings_button = $UI/SettingsPosition/SettingsButton
onready var rotate_button = $UI/UIPosition/UIContainer/RotateButton

const SETTINGS_POPUP_SCENE = preload("res://scenes/settings.tscn")

# We can drop your template domino .tres files directly into this array via the inspector!
export(Array, Resource) var player_stack = []

enum PlayState { IDLE, DRAGGING, VERIFYING, PROCESSING }

var player_draw_pile: Array = []
var player_discard_pile: Array = []
var player_void_pile: Array = []
var current_play_state = PlayState.IDLE
var active_domino = null
var active_domino_origin = Vector2.ZERO 
var last_placed_domino = null
var last_placed_origin = Vector2.ZERO
var last_placed_slot = null  # Track the original hand slot of the last placed domino for undo purposes
var domino_snap_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Randomize Godot's internal math engine seed so every run is unique
	randomize()
	
	# Set up and draw an initial starting hand
	prepare_combat_draw_pile()
	draw_dominoes(3)

	# Connect validation button click events safely
	ok_button.connect("pressed", self, "_on_ok_pressed")
	undo_button.connect("pressed", self, "_on_undo_pressed")
	rotate_button.connect("pressed", self, "_on_rotate_pressed")
	_toggle_verification_ui(false)
	
	# Connect the settings button to our popup opening function
	settings_button.connect("pressed", self, "_on_settings_pressed")

	GameState.connect("player_energy_changed", self, "_on_energy_adjusted")
	GameState.set_starting_player_energy(20)  # ADD THIS — must be after signal connect
	
	_refresh_hand_playability()

	# Calculate domino snap offset from actual sprite dimensions
	# When the domino is placed over the board, we have to account for the difference 
	# between the sprite's center point and the grid slot's center point to get a clean snap
	# We calculate this once when the game starts by loading a temporary domino instance, 
	# measuring its sprite, and then freeing it immediately 
	var temp = preload("res://scenes/domino.tscn").instance()
	var sprite = temp.get_node_or_null("BaseSprite")
	if sprite and sprite.texture:
		var size = sprite.texture.get_size() * sprite.scale
		#domino_snap_offset = Vector2(size.x * 0.25, size.y * 0.5)
		domino_snap_offset = Vector2(0, 0)  # ADJUST THIS if your domino sprite isn't perfectly centered on its grid slot
	temp.free()

func _process(_delta) -> void:
	if active_domino != null and current_play_state == PlayState.DRAGGING:
		var visual_offset = active_domino.get_placement_offset()
		
		var logical_pos = active_domino.global_position - visual_offset
		var grid_pos = board.world_to_grid(logical_pos)
		var gx = int(grid_pos.x)
		var gy = int(grid_pos.y)
		var vertical = active_domino.is_vertical()
		if board.is_placement_valid(gx, gy, vertical):
			board.highlight_preview(gx, gy, vertical)
		else:
			board.clear_preview()

func _on_domino_clicked(domino) -> void:
	print("_on_domino_clicked | state: ", current_play_state, " | domino: ", domino, " | last_placed: ", last_placed_domino)
	
	# 1. Handle picking up a domino that is already on the board awaiting verification
	if current_play_state == PlayState.VERIFYING and domino == last_placed_domino:
		board.remove_domino_from_matrix(last_placed_domino)
		active_domino = last_placed_domino
		active_domino_origin = last_placed_origin
		active_domino.current_status = active_domino.StatusType.HAND
		last_placed_domino = null
		current_play_state = PlayState.DRAGGING
		_toggle_verification_ui(false)

		# Reparent to DragLayer so it renders above UI, same as initial pickup
		var global_pos = active_domino.global_position
		var old_parent = active_domino.get_parent()
		old_parent.remove_child(active_domino)
		$DragLayer.add_child(active_domino)
		active_domino.global_position = global_pos
		
		active_domino.start_drag_from(get_global_mouse_position())
		return
	
	# If we are waiting for confirmation on a placed domino, ignore clicking other dominoes
	if last_placed_domino != null:
		return
	
	# 2. CLICK-TO-SELECT MODE: Second click on the SAME dragging domino drops it down
	if not Settings.mouse_mode_enabled and current_play_state == PlayState.DRAGGING and active_domino == domino:
		_try_place_active_domino()
		return
	
	# 3. Standard initial pickup from hand
	if current_play_state != PlayState.IDLE:
		return

	# SET VALUES FIRST: Capture the original home parent before breaking the chain!
	active_domino = domino
	active_domino_origin = domino.global_position
	last_placed_slot = domino.get_parent() 
	current_play_state = PlayState.DRAGGING

	# REPARENT SECOND: Now safe to remove since last_placed_slot is populated
	var global_pos = domino.global_position
	last_placed_slot.remove_child(domino)
	$DragLayer.add_child(domino)
	domino.global_position = global_pos
	
	if Settings.mouse_mode_enabled:
		domino.start_drag()
	else:
		domino.start_drag_from(get_global_mouse_position())
		
	# Refresh UI states at the very end so the Rotate button knows we are DRAGGING
	_toggle_verification_ui(false)

func _input(event) -> void:
	# If the player clicks or releases the mouse over a UI button, 
	# ignore the event completely so it doesn't cancel the dragging domino!
	if event is InputEventMouseButton:
		# Check if the mouse is currently over our UI action container or settings position
		var ui_rect = $UI/UIPosition/UIContainer.get_global_rect()
		var settings_rect = $UI/SettingsPosition/SettingsButton.get_global_rect()
		var mouse_pos = get_global_mouse_position()
		
		if ui_rect.has_point(mouse_pos) or settings_rect.has_point(mouse_pos):
			return # Abort! Let the button handle the click, don't drop the domino.

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
	# Convert global_position back to "logical" anchor by removing the visual offset
	# that placement applies, based on the domino's CURRENT rotation
	var visual_offset = active_domino.get_placement_offset()
	
	var logical_pos = active_domino.global_position - visual_offset
	var grid_pos = board.world_to_grid(logical_pos)
	var gx = int(grid_pos.x)
	var gy = int(grid_pos.y)
	var vertical = active_domino.is_vertical()

	if not board.is_placement_valid(gx, gy, vertical):
		board.clear_preview()
		_cancel_active_domino()
		return

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
	active_domino = null
	if Settings.fast_mode_enabled:
		_on_ok_pressed()
	else:
		current_play_state = PlayState.VERIFYING
		_toggle_verification_ui(true)


func _cancel_active_domino() -> void:
	
	print("Call _cancel_active_domino at:", OS.get_ticks_msec())
	print("_cancel_active_domino called | active: ", active_domino)
	if active_domino == null:
		return
	var domino = active_domino
	var origin = active_domino_origin
	active_domino = null
	current_play_state = PlayState.IDLE
	board.clear_preview()
	_toggle_verification_ui(false)

	var current_parent = domino.get_parent()

	if current_parent != last_placed_slot and last_placed_slot != null:
		var global_pos_before = domino.global_position
		current_parent.remove_child(domino)
		last_placed_slot.add_child(domino)
		domino.position = last_placed_slot.get_global_transform().affine_inverse().xform(global_pos_before)

	domino.return_to_hand(origin)

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
	# OK and Undo only show up when a domino is waiting on the board to be confirmed
	ok_button.visible = show_verification
	undo_button.visible = show_verification
	
	# Rotate button rules: 
	# 1. Mouse Mode must be OFF (Click-to-Select)
	# 2. The player must be actively dragging/floating a domino (NOT verifying a placed one)
	if not Settings.mouse_mode_enabled and current_play_state == PlayState.DRAGGING and active_domino != null:
		rotate_button.visible = true
	else:
		rotate_button.visible = false

func _on_ok_pressed() -> void:
	if last_placed_domino == null:
		return
	# Deduct energy for the pips played
	var cost = GameState.calculate_domino_cost(last_placed_domino.left_pip_value, last_placed_domino.right_pip_value)
	GameState.spend_player_energy(cost)
	
	last_placed_domino.lock_to_board()
	_sort_board_dominoes_by_y()
	last_placed_domino = null
	last_placed_origin = Vector2.ZERO
	current_play_state = PlayState.IDLE
	_toggle_verification_ui(false)

func _on_undo_pressed() -> void:

	print("_on_undo_pressed called")
	if last_placed_domino == null:
		return
	board.remove_domino_from_matrix(last_placed_domino)
	var board_parent = last_placed_domino.get_parent()
	
	# Capture global position BEFORE reparenting
	var global_pos_before = last_placed_domino.global_position
	
	board_parent.remove_child(last_placed_domino)
	last_placed_slot.add_child(last_placed_domino)
	
	# Convert to slot-local space so the tween starts from the right place
	last_placed_domino.position = last_placed_slot.get_global_transform().affine_inverse().xform(global_pos_before)
	
	last_placed_domino.current_status = last_placed_domino.StatusType.HAND
	last_placed_domino.input_pickable = true
	last_placed_domino.return_to_hand(last_placed_origin)
	last_placed_domino = null
	last_placed_origin = Vector2.ZERO
	last_placed_slot = null
	current_play_state = PlayState.IDLE
	_toggle_verification_ui(false)

func _on_rotate_pressed() -> void:
	# Only allow button rotation if a domino is actively floating/dragging
	if current_play_state == PlayState.DRAGGING and active_domino != null:
		active_domino.rotate_domino()	

# ===================================================================================
# Domino draw and stack management logic
# ===================================================================================

# Safely clones the master files into unique, isolated RAM packets for this battle
func prepare_combat_draw_pile() -> void:
	player_draw_pile.clear()
	player_discard_pile.clear()
	print("Stack array size: ", player_stack.size())
	
	for base_resource in player_stack:
		if base_resource is DominoData:
			# We use duplicate() so that any changes to the data during combat won't affect the original .tres template file
			var runtime_copy = base_resource.duplicate()
			player_draw_pile.append(runtime_copy)

# Pulls random data packets out of the stack and commands the hand to spawn them
func draw_dominoes(amount: int) -> void:
	for _i in range(amount):
		# If you completely run out of dominos, recycle the discard pile
		if player_draw_pile.empty():
			if player_discard_pile.empty():
				print("The player's deck is completely exhausted!")
				break
			_player_draw_pile_empty()
			
		# Pick a random domino position index remaining in our draw stack
		var random_idx = randi() % player_draw_pile.size()
		var chosen_domino_data: DominoData = player_draw_pile[random_idx]
		
		# Remove the data packet from the draw stack
		player_draw_pile.remove(random_idx)
		print("Drawing domino index [", _i, "] - Left Pip: ", chosen_domino_data.base_left_pip, " Right Pip: ", chosen_domino_data.base_right_pip)
		
		# Send the isolated data packet to your physical hand container UI to display it
		if hand.has_method("add_domino_to_hand"):
			hand.add_domino_to_hand(chosen_domino_data)
		else:
			push_error("CRITICAL: player_hand script is missing the add_domino_to_hand function!")

# Shuffles discarded tiles back into active rotation when empty
func _recycle_player_discard_pile() -> void:
	print("Refilling draw pile from discard graveyard...")
	player_draw_pile = player_discard_pile.duplicate()
	player_discard_pile.clear()

func _player_draw_pile_empty() -> void:
	# Game over when we 'deck out'
	print("Player has no more dominoes to draw! Game over!")
	return;

func _on_energy_adjusted(new_energy: int) -> void:

	energy_label.text = str(new_energy)
	_refresh_hand_playability()

func _refresh_hand_playability() -> void:
	for slot in hand.get_children():
		if slot.get_child_count() > 0:
			var domino = slot.get_child(0)
			if domino and domino.has_method("check_playability"):
				domino.check_playability()	

func _on_settings_pressed() -> void:
	# 1. Block any accidental clicks or drag events while menu is open
	if current_play_state == PlayState.DRAGGING:
		return # Don't let them open menus mid-drag!
		
	# 2. Instance the popup
	var popup_instance = SETTINGS_POPUP_SCENE.instance()
	
	# 3. Add it straight to your CanvasLayer UI so it draws over the game world
	$UI.add_child(popup_instance)
	
	# 4. Tell the PopupPanel to center itself on screen and show up!
	popup_instance.popup_centered()
