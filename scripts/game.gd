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

func _process(_delta) -> void:
	if active_domino != null and current_play_state == PlayState.DRAGGING:
		var grid_pos = board.world_to_grid(get_global_mouse_position())
		var gx = int(grid_pos.x)
		var gy = int(grid_pos.y)
		if board.is_placement_valid(gx, gy):
			board.highlight_preview(gx, gy)
		else:
			board.clear_preview()

func _on_domino_clicked(domino) -> void:
	if current_play_state != PlayState.IDLE:
		return
	active_domino = domino
	current_play_state = PlayState.DRAGGING
	domino.start_drag()

func _input(event) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		if current_play_state == PlayState.DRAGGING and active_domino != null:
			_try_place_active_domino()

func _try_place_active_domino() -> void:
	var grid_pos = board.world_to_grid(get_global_mouse_position())
	var gx = int(grid_pos.x)
	var gy = int(grid_pos.y)
	
	if not board.is_placement_valid(gx, gy):
		return  # Stay in drag state, invalid placement
	
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

	# Lock it — removes shader, disables input
	active_domino.lock_to_board()
	
	_sort_board_dominoes_by_y()
	active_domino = null
	current_play_state = PlayState.IDLE
	_toggle_verification_ui(true)


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
