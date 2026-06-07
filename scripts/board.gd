# board.gd
extends Control

onready var grid_container = $GridContainer

# A 2D Matrix Array representation of our board states: board_matrix[x][y]
var board_matrix = []

func _ready() -> void:
	_initialise_empty_matrix()
	_generate_visual_grid_slots()

func _initialise_empty_matrix() -> void:
	for x in range(16):
		board_matrix.append([])
		for y in range(16):
			board_matrix[x].append(null) # 'null' means the slot is completely empty

# Spawns physical visual boundary markers into the GridContainer layout tree
func _generate_visual_grid_slots() -> void:
	for i in range(16 * 16):
		var slot = TextureRect.new()
		slot.rect_min_size = Vector2(24, 24) # Matches your domino layout size!
		
		# Give it a subtle background or border texture so you can see your grid blocks
		slot.texture = load("res://assets/ui/empty_board_tile.png") 
		slot.expand = true
		slot.stretch_mode = TextureRect.STRETCH_SCALE
		
		# Store coordinates inside the slot metadata so we can identify clicks later
		var slot_x = i % 16
		var slot_y = int(i / 16)
		slot.set_meta("grid_pos", Vector2(slot_x, slot_y))
		
		grid_container.add_child(slot)
