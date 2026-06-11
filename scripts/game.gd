# game.gd
extends Node2D

onready var board = $GridPosition/Board
onready var hand = $PlayerHandPosition/PlayerHand 
onready var ok_button = $UI/UIPosition/UIContainer/OKButton
onready var undo_button = $UI/UIPosition/UIContainer/UndoButton

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
	_toggle_verification_ui(false)
	
	GameState.connect("player_energy_changed", self, "_on_energy_adjusted")
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
		domino_snap_offset = Vector2(size.x * 0.25, size.y * 0.5)
	temp.free()

func _process(_delta) -> void:
	if active_domino != null and current_play_state == PlayState.DRAGGING:
		var grid_pos = board.world_to_grid(active_domino.global_position + domino_snap_offset)
		var gx = int(grid_pos.x)
		var gy = int(grid_pos.y)
		if board.is_placement_valid(gx, gy):
			board.highlight_preview(gx, gy)
		else:
			board.clear_preview()

func _on_domino_clicked(domino) -> void:
	print("_on_domino_clicked | state: ", current_play_state, " | domino: ", domino, " | last_placed: ", last_placed_domino)
	if current_play_state == PlayState.VERIFYING and domino == last_placed_domino:
		board.remove_domino_from_matrix(last_placed_domino)
		active_domino = last_placed_domino
		active_domino_origin = last_placed_origin
		active_domino.current_status = active_domino.StatusType.HAND
		last_placed_domino = null
		current_play_state = PlayState.DRAGGING
		_toggle_verification_ui(false)
		active_domino.start_drag_from(get_global_mouse_position())
		return
	if current_play_state != PlayState.IDLE:
		return
	if last_placed_domino != null:  # ADD THIS — block new picks while verifying a placed domino
		return
	active_domino = domino
	active_domino_origin = domino.global_position
	last_placed_slot = domino.get_parent()
	current_play_state = PlayState.DRAGGING
	domino.start_drag()

func _input(event) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		print("Mouse release | state: ", current_play_state, " | active: ", active_domino)
		if current_play_state == PlayState.DRAGGING and active_domino != null:
			_try_place_active_domino()

func _try_place_active_domino() -> void:
	var grid_pos = board.world_to_grid(active_domino.global_position + domino_snap_offset)
	var gx = int(grid_pos.x)
	var gy = int(grid_pos.y)
	
	if not board.is_placement_valid(gx, gy):
		board.clear_preview()
		_cancel_active_domino()
		return
	
	board.clear_preview()
	
	# Remove the domino from its hand slot first
	var old_parent = active_domino.get_parent()
	old_parent.remove_child(active_domino)
	board.add_child(active_domino)

	# NOW set position AFTER reparenting so it's in board's coordinate space
	var snap_world = board.grid_to_world(gx, gy)
	active_domino.global_position = snap_world + Vector2(0, -2)  
	
	# Register in matrix
	board.place_domino_on_matrix(active_domino, gx, gy)
	
	# Z-level
	active_domino.z_index = gy  # Lower Y = further back
	active_domino.stop_drag()  # ADD THIS — stops _process tracking mouse
	active_domino.current_status = active_domino.StatusType.BOARD  # ADD THIS

	# Enter verification phase where we show the OK/UNDO buttons and wait for 
	# player input before finalising the placement
	last_placed_domino = active_domino
	last_placed_origin = active_domino_origin
	active_domino = null
	current_play_state = PlayState.VERIFYING
	_toggle_verification_ui(true)


func _cancel_active_domino() -> void:

	print("_cancel_active_domino called | active: ", active_domino)
	if active_domino == null:
		return
	var domino = active_domino
	var origin = active_domino_origin
	active_domino = null
	current_play_state = PlayState.IDLE
	board.clear_preview()
	domino.return_to_hand(origin)  # domino handles its own tween

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
	
func _toggle_verification_ui(show: bool) -> void:
	ok_button.visible = show
	undo_button.visible = show

func _on_ok_pressed() -> void:
	if last_placed_domino == null:
		return
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
	_refresh_hand_playability()

func _refresh_hand_playability() -> void:
	for slot in hand.get_children():
		if slot.get_child_count() > 0:
			var domino = slot.get_child(0)
			if domino and domino.has_method("check_playability"):
				domino.check_playability()	
