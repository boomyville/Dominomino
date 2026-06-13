# board.gd
tool
extends Control

var previewed_slots: Array = []

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

	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	grid_container.set("custom_constants/hseparation", 0)
	grid_container.set("custom_constants/vseparation", 0)

	for child in grid_container.get_children():
		child.queue_free()

	for i in range(16 * 16):
		var slot = TextureRect.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func place_domino_on_matrix(domino_instance: Area2D, target_x: int, target_y: int) -> void:
	board_matrix[target_y][target_x] = domino_instance
	if domino_instance.is_vertical():
		board_matrix[target_y + 1][target_x] = domino_instance
		print("Domino registered at col: ", target_x, " rows: ", target_y, "-", target_y + 1)
	else:
		board_matrix[target_y][target_x + 1] = domino_instance
		print("Domino registered at row: ", target_y, " cols: ", target_x, "-", target_x + 1)


# We call this function when we undo a domino placement on the board
func remove_domino_from_matrix(domino_instance: Area2D) -> void:
	for y in range(16):
		for x in range(16):
			if board_matrix[y][x] == domino_instance:
				board_matrix[y][x] = null


func is_placement_valid(start_x: int, start_y: int, vertical: bool = false) -> bool:
	if start_x < 0 or start_y < 0:
		return false
	if vertical:
		if start_x >= 16 or start_y + 1 >= 16:
			return false
		return board_matrix[start_y][start_x] == null and board_matrix[start_y + 1][start_x] == null
	else:
		if start_x + 1 >= 16 or start_y >= 16:
			return false
		return board_matrix[start_y][start_x] == null and board_matrix[start_y][start_x + 1] == null


func highlight_preview(start_x: int, start_y: int, vertical: bool = false) -> void:
	clear_preview()
	if not is_placement_valid(start_x, start_y, vertical):
		return
	for child in grid_container.get_children():
		var gp = child.get_meta("grid_pos")
		var highlight = false
		if vertical:
			highlight = gp.x == start_x and (gp.y == start_y or gp.y == start_y + 1)
		else:
			highlight = gp.y == start_y and (gp.x == start_x or gp.x == start_x + 1)
		if highlight:
			child.texture = load("res://assets/ui/empty_board_tile3.png")
			previewed_slots.append(child)
			
func clear_preview() -> void:
	for slot in previewed_slots:
		if is_instance_valid(slot):
			var gp = slot.get_meta("grid_pos")
			var check_val = (int(gp.x) + int(gp.y)) % 2
			if check_val == 0:
				slot.texture = load("res://assets/ui/empty_board_tile.png")
			else:
				slot.texture = load("res://assets/ui/empty_board_tile2.png")
	previewed_slots.clear()

func world_to_grid(world_pos: Vector2) -> Vector2:
	var origin = grid_container.get_global_transform_with_canvas().origin
	var local_pos = world_pos - origin
	return Vector2(int(local_pos.x / 24), int(local_pos.y / 24))

func grid_to_world(cell_x: int, cell_y: int) -> Vector2:
	var origin = grid_container.get_global_transform_with_canvas().origin
	return origin + Vector2(cell_x * 24, cell_y * 24)
