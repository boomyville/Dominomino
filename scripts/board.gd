# board.gd
tool
extends Control

onready var grid_container = $GridContainer

var board_matrix = []

func _ready() -> void:
	_initialise_empty_matrix()
	_generate_visual_grid_slots()

func _initialise_empty_matrix() -> void:
	board_matrix = [] # Reset array
	for _y in range(16):
		var row = []
		for _x in range(16):
			row.append(null)
		board_matrix.append(row)

func _generate_visual_grid_slots() -> void:
	if grid_container == null:
		grid_container = get_node_or_null("GridContainer")
	
	if grid_container == null:
		return
		
	grid_container.set("custom_constants/hseparation", 0)
	grid_container.set("custom_constants/vseparation", 0)

	for child in grid_container.get_children():
		child.queue_free()

	for i in range(16 * 16):
		var slot = TextureRect.new()
		slot.rect_min_size = Vector2(24, 24) 
		slot.expand = true
		slot.stretch_mode = TextureRect.STRETCH_SCALE
		
		var slot_x = i % 16
		var slot_y = int(i / 16.0)
		slot.set_meta("grid_pos", Vector2(slot_x, slot_y))
		
		var check_val = (slot_x + slot_y) % 2
		# print("Slot: ", slot_x, ",", slot_y, " Modulo result: ", check_val)
		
		if check_val == 0:
			slot.texture = load("res://assets/ui/empty_board_tile.png") 
		else:
			slot.texture = load("res://assets/ui/empty_board_tile2.png")
			
		grid_container.add_child(slot)
		
func get_domino_at(x: int, y: int) -> Area2D:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		return board_matrix[y][x] as Area2D
	return null

func is_placement_valid(start_x: int, start_y: int) -> bool:
	# 1. BOUNDARY CHECK: Ensure the 2x1 shape doesn't spill off the right edge of columns
	if start_x + 1 >= 16 or start_y >= 16:
		return false
		
	# 2. OVERLAP PREVENTION: Read row array data lines to ensure BOTH slots are completely vacant (null)
	var left_cell = board_matrix[start_y][start_x]
	var right_cell = board_matrix[start_y][start_x + 1]
	
	if left_cell != null or right_cell != null:
		# If either cell holds an existing domino node reference, reject the placement outright!
		return false 
		
	return true

# Locks out both matrix positions to point to our active domino piece container instance
func place_domino_on_matrix(domino_instance: Area2D, target_x: int, target_y: int) -> void:
	board_matrix[target_y][target_x] = domino_instance
	board_matrix[target_y][target_x + 1] = domino_instance
	print("Domino successfully registered at matrix row: ", target_y, " across columns: ", target_x, "-", target_x + 1)
