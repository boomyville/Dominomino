# domino.gd
tool
extends Area2D

# Enums
enum OwnerType { PLAYER, ENEMY, NONE }
enum StatusType { VOID, DISCARD, DRAW, HAND, BOARD, OPPONENT }
enum DragState { IDLE, CLICKED }

# Signals
signal domino_clicked(domino)

# Exportable data
export(Resource) var domino_data setget set_domino_data

# Core variables
var left_pip_value: int = 0
var right_pip_value: int = 0
var current_owner: int = OwnerType.NONE
var current_status: int = StatusType.VOID
var upgrade_level: int = 1
var drag_state: int = DragState.IDLE
var drag_offset: Vector2 = Vector2.ZERO
var rotation_step: int = 0  # 0=horizontal, 1=vertical CW, 2=flipped, 3=vertical CCW

# Node references
onready var base_sprite = $BaseSprite
onready var left_pip_sprite = $LeftPip/PipSprite
onready var right_pip_sprite = $RightPip/PipSprite
onready var lip_sprite = $LipPosition/LipSprite

# Shaders
const OUTLINE_SHADER = preload("res://assets/shaders/playable_outline.shader") 
var shader_material: ShaderMaterial = null

func set_value(left_val: int, right_val: int) -> void:
	left_pip_value = left_val
	right_pip_value = right_val
	_update_pip_visuals()

func _update_pip_visuals() -> void:
	# 1. TOOL SAFETY GUARD: Ensure nodes aren't Nil before changing textures
	if left_pip_sprite == null or right_pip_sprite == null:
		return

	left_pip_value = _sanitise_pip_value(left_pip_value)
	# Validate pip values
	right_pip_value = _sanitise_pip_value(right_pip_value)

	# Load pip textures
	left_pip_sprite.texture = _load_pip_texture(left_pip_value)
	right_pip_sprite.texture = _load_pip_texture(right_pip_value)

func _sanitise_pip_value(val: int) -> int:
	if val == -1:
		return -1 
	elif val == -2:
		return -2 
	return int(clamp(val, 0, 6))

func _load_pip_texture(val: int) -> Texture:
	var path: String = ""
	
	if val == -1:
		path = "res://assets/domino/pip_wild.png"
	elif val == -2:
		path = "res://assets/domino/pip_unplayable.png"
	else:
		path = "res://assets/domino/pip_" + str(val) + ".png"
		
	var file_checker = File.new()
	if file_checker.file_exists(path):
		return load(path) as Texture
		
	push_error("CRITICAL: Missing domino pip asset texture at path: " + path)
	return load("res://assets/domino/pip_error.png") as Texture

func uptick(amount: int) -> void:
	if left_pip_value >= 0:
		left_pip_value = int(clamp(left_pip_value + amount, 0, 6))
	if right_pip_value >= 0:
		right_pip_value = int(clamp(right_pip_value + amount, 0, 6))
	_update_pip_visuals()

func downtick(amount: int) -> void:
	if left_pip_value >= 1:
		left_pip_value = int(clamp(left_pip_value - amount, 0, 6))
	if right_pip_value >= 1:
		right_pip_value = int(clamp(right_pip_value - amount, 0, 6))
	_update_pip_visuals()

func get_max_upgrade_level() -> int:
	if domino_data == null:
		push_warning("Checking max level on a tile with no data template!")
		return 1 
		
	match domino_data.rarity:
		DominoData.RarityType.STATUS, DominoData.RarityType.BLIGHT:
			return 1
		DominoData.RarityType.LEGENDARY:
			return 2
		DominoData.RarityType.RARE:
			return 3
		DominoData.RarityType.UNCOMMON:
			return 4
		_:
			return 4
			
func upgrade() -> void:
	if upgrade_level < get_max_upgrade_level():
		upgrade_level += 1

func downgrade() -> void:
	if upgrade_level > 0:
		upgrade_level -= 1

func _update_background_skin() -> void:
	if base_sprite == null:
		return
		
	if domino_data == null:
		return
		
	match domino_data.rarity:
		DominoData.RarityType.LEGENDARY:
			base_sprite.texture = load("res://assets/domino/domino_base.png")
			base_sprite.self_modulate = Color.white
		DominoData.RarityType.BLIGHT:
			base_sprite.texture = load("res://assets/domino/domino_base.png")
			base_sprite.self_modulate = Color("8a2be2")    
		DominoData.RarityType.STATUS:
			base_sprite.texture = load("res://assets/domino/domino_base.png")
			base_sprite.self_modulate = Color("8b0000") 
		_:
			base_sprite.texture = load("res://assets/domino/domino_base.png")
			base_sprite.self_modulate = Color.white
			
func set_domino_data(new_data) -> void:
	domino_data = new_data
	
	# If the editor sets this before _ready() has run, onready vars are null.
	# We manually grab the node references if they aren't initialised yet!
	if base_sprite == null:
		base_sprite = get_node_or_null("BaseSprite")
	if left_pip_sprite == null:
		left_pip_sprite = get_node_or_null("LeftPip/PipSprite")
	if right_pip_sprite == null:
		right_pip_sprite = get_node_or_null("RightPip/PipSprite")
	
	if is_inside_tree() and domino_data != null:
		left_pip_value = domino_data.base_left_pip
		right_pip_value = domino_data.base_right_pip
		
		_update_background_skin()
		_update_pip_visuals()

func check_playability() -> void:
	# 1. Calculate total resource cost from global state
	var cost = GameState.calculate_domino_cost(left_pip_value, right_pip_value)
	var can_afford = GameState.current_player_energy >= cost
	print("Domino energy cost: ", cost, " | Global Energy: ", GameState.current_player_energy, " | Can Afford: ", can_afford)
	
	# 2. Safely verify base_sprite exists and has a material assigned
	if base_sprite and base_sprite.material:
		# Explicitly cast generic Material to ShaderMaterial so we can use set_shader_param()
		var active_material = base_sprite.material as ShaderMaterial
		if active_material:
			active_material.set_shader_param("is_active", can_afford)
	else:
		print("WARNING: check_playability called but shader_material is target uniform null.")

	if lip_sprite and lip_sprite.material:
		# Explicitly cast generic Material to ShaderMaterial so we can use set_shader_param()
		var active_material = lip_sprite.material as ShaderMaterial
		if active_material:
			active_material.set_shader_param("is_active", can_afford)
	else:
		print("WARNING: check_playability called but shader_material is target uniform null.")

func _ready() -> void:
	input_pickable = true
	print("Domino _ready | input_pickable: ", input_pickable, " | monitoring: ", monitoring)
   
	if base_sprite:
		shader_material = ShaderMaterial.new()
		shader_material.shader = OUTLINE_SHADER
		base_sprite.material = shader_material
	
	if lip_sprite:
		var lip_shader_material = ShaderMaterial.new()
		lip_shader_material.shader = OUTLINE_SHADER
		lip_sprite.material = lip_shader_material
		
	if domino_data != null:
		left_pip_value = domino_data.base_left_pip
		right_pip_value = domino_data.base_right_pip
		_update_pip_visuals()
		_update_background_skin()
	check_playability()

func _input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		if current_status == StatusType.HAND and drag_state == DragState.IDLE:
			rotate_domino()
	
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		if drag_state == DragState.IDLE and (current_status == StatusType.HAND or current_status == StatusType.BOARD):
			var cost = GameState.calculate_domino_cost(left_pip_value, right_pip_value)
			if GameState.current_player_energy < cost:
				return
			emit_signal("domino_clicked", self)

func start_drag() -> void:
	drag_state = DragState.CLICKED
	z_as_relative = false
	z_index = 1000
	set_process(true)

func stop_drag() -> void:
	drag_state = DragState.IDLE
	z_index = 0
	set_process(false)

func start_drag_from(click_global_pos: Vector2) -> void:
	drag_offset = global_position - click_global_pos
	start_drag()

func _process(_delta) -> void:
	if drag_state == DragState.CLICKED:
		global_position = get_global_mouse_position() + drag_offset

func lock_to_board() -> void:
	stop_drag()
	current_status = StatusType.BOARD
	if base_sprite:
		base_sprite.material = null
	if lip_sprite:
		lip_sprite.material = null
	input_pickable = false
	z_as_relative = false

func return_to_hand(origin: Vector2) -> void:
	drag_state = DragState.IDLE
	z_index = 0
	set_process(false)
	
	print("return_to_hand | current pos: ", position, " | target local origin: Vector2.ZERO")
	
	var tween = Tween.new()
	add_child(tween)
	
	# FIX: Animate local "position" back to its container home (0, 0)
	var result = tween.interpolate_property(
		self, 
		"position", 
		position, 
		Vector2.ZERO, 
		Settings.domino_tween_duration, 
		Tween.TRANS_CUBIC, 
		Tween.EASE_OUT
	)
	
	tween.start()
	tween.connect("tween_all_completed", tween, "queue_free")

func rotate_domino() -> void:
	rotation_step = (rotation_step + 1) % 4
	rotation_degrees = rotation_step * 90.0

	if base_sprite:
		base_sprite.texture = load("res://assets/domino/domino_base_" + str(rotation_step) + ".png")

	# Counter-rotate the lip so it always stays upright
	lip_sprite.rotation_degrees = -rotation_degrees
	
	# Swap lip texture based on orientation
	if is_vertical():
		lip_sprite.texture = load("res://assets/domino/lip_narrow.png")
	else:
		lip_sprite.texture = load("res://assets/domino/lip_wide.png")
	
	# Reposition lip to always sit at the bottom of the current bounding box
	match rotation_step:
		0: lip_sprite.position = Vector2(24, 12)
		1: lip_sprite.position = Vector2(51, -3)
		2: lip_sprite.position = Vector2(24, -18)
		3: lip_sprite.position = Vector2(-2, -3)

func get_top_pip() -> int:
	match rotation_step:
		1: return left_pip_value
		3: return right_pip_value
	return -1  # horizontal orientations have no top pip

func get_bottom_pip() -> int:
	match rotation_step:
		1: return right_pip_value
		3: return left_pip_value
	return -1

func get_left_pip() -> int:
	match rotation_step:
		0: return left_pip_value
		2: return right_pip_value
	return -1

func get_right_pip() -> int:
	match rotation_step:
		0: return right_pip_value
		2: return left_pip_value
	return -1

func is_horizontal() -> bool:
	return rotation_step % 2 == 0

func is_vertical() -> bool:
	return rotation_step % 2 == 1

func get_facing_pip(direction: String) -> int:
	match direction:
		"top": return get_top_pip()
		"bottom": return get_bottom_pip()
		"left": return get_left_pip()
		"right": return get_right_pip()
	return -1

func get_placement_offset() -> Vector2:
	match rotation_step:
		0: return Vector2(24, 7)
		1: return Vector2(12, 19)
		2: return Vector2(24, 7)
		3: return Vector2(12, 19)
	return Vector2.ZERO

# Functions to handle visual state changes on the dominoes based on playability and selection status.

func set_selected_visual(selected: bool) -> void:
	if selected:
		modulate = Color(1, 1, 1, 0.75)
		# scale = Vector2(1.5, 1.5)
	else:
		modulate = Color.white
		scale = Vector2.ONE

func set_selectable_visual(selectable: bool) -> void:
	if base_sprite and base_sprite.material:
		var mat = base_sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_param("is_active", selectable)

	if lip_sprite and lip_sprite.material:
		var mat = lip_sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_param("is_active", selectable)
