tool
extends Area2D

# Enums
enum OwnerType { PLAYER, ENEMY, NONE }
enum StatusType { VOID, DISCARD, DRAW, HAND, BOARD, OPPONENT }
enum DragState { IDLE, CLICKED }
enum PlayabilityMode { UNPLAYABLE, FULL_COST_PLAYABLE, MATCH_PLAYABLE }

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
onready var domino_name_label = $DominoName
onready var outline_sprite = $OutlineSprite

# Shaders — two slots per visual node: base outline and match-discount outline
const OUTLINE_SHADER = preload("res://assets/shaders/playable_outline.shader")
const OUTLINE_SHADER_2 = preload("res://assets/shaders/playable_outline2.shader")

# ShaderMaterial instances — created once in _ready(), swapped via set_playability_visual()
var _outline_mat: ShaderMaterial = null
var _outline_mat2: ShaderMaterial = null

func set_value(left_val: int, right_val: int) -> void:
	left_pip_value = left_val
	right_pip_value = right_val
	_update_pip_visuals()

func _update_pip_visuals() -> void:
	if left_pip_sprite == null or right_pip_sprite == null:
		return
	left_pip_value = _sanitise_pip_value(left_pip_value)
	right_pip_value = _sanitise_pip_value(right_pip_value)
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
			base_sprite.texture = load("res://assets/domino/domino_base_0.png")
			base_sprite.self_modulate = Color.white
		DominoData.RarityType.BLIGHT:
			base_sprite.texture = load("res://assets/domino/domino_base_0.png")
			base_sprite.self_modulate = Color("8a2be2")
		DominoData.RarityType.STATUS:
			base_sprite.texture = load("res://assets/domino/domino_base_0.png")
			base_sprite.self_modulate = Color("8b0000")
		_:
			base_sprite.texture = load("res://assets/domino/domino_base_0.png")
			base_sprite.self_modulate = Color.white

func set_domino_data(new_data) -> void:
	domino_data = new_data
	if base_sprite == null:
		base_sprite = get_node_or_null("BaseSprite")
	if left_pip_sprite == null:
		left_pip_sprite = get_node_or_null("LeftPip/PipSprite")
	if right_pip_sprite == null:
		right_pip_sprite = get_node_or_null("RightPip/PipSprite")
	if domino_name_label == null:
		domino_name_label = get_node_or_null("DominoName")
	if is_inside_tree() and domino_data != null:
		left_pip_value = domino_data.base_left_pip
		right_pip_value = domino_data.base_right_pip
		if domino_name_label != null:
			domino_name_label.text = domino_data.domino_name
		_update_background_skin()
		_update_pip_visuals()

# ---------------------------------------------------------------------------
# Playability visuals
# ---------------------------------------------------------------------------

# Primary entry point called by game.gd._refresh_hand_playability().
# mode: PlayabilityMode enum value
#   UNPLAYABLE          → no shader active (is_active = false on both)
#   FULL_COST_PLAYABLE  → outline shader active, outline2 inactive
#   MATCH_PLAYABLE      → outline2 shader active, outline inactive
func set_playability_visual(mode: int) -> void:
	match mode:
		PlayabilityMode.UNPLAYABLE:
			if outline_sprite:
				outline_sprite.material = _outline_mat
				_outline_mat.set_shader_param("is_active", false)

		PlayabilityMode.FULL_COST_PLAYABLE:
			if outline_sprite:
				outline_sprite.material = _outline_mat
				_outline_mat.set_shader_param("is_active", true)
				_outline_mat2.set_shader_param("is_active", false)

		PlayabilityMode.MATCH_PLAYABLE:
			if outline_sprite:
				outline_sprite.material = _outline_mat2
				_outline_mat.set_shader_param("is_active", false)
				_outline_mat2.set_shader_param("is_active", true)

# Legacy wrapper — kept so existing callsites in domino.gd._input_event still compile.
# Performs a simple energy check only (no board context).
# game.gd._refresh_hand_playability() overrides this immediately after with the full result.
func check_playability() -> void:
	var cost = GameState.calculate_domino_cost(left_pip_value, right_pip_value)
	var can_afford = GameState.current_player_energy >= cost
	if can_afford:
		set_playability_visual(PlayabilityMode.FULL_COST_PLAYABLE)
	else:
		set_playability_visual(PlayabilityMode.UNPLAYABLE)

func _ready() -> void:
	input_pickable = true
	print("Domino _ready | input_pickable: ", input_pickable, " | monitoring: ", monitoring)

	# Initialize the materials once
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE_SHADER
	_outline_mat2 = ShaderMaterial.new()
	_outline_mat2.shader = OUTLINE_SHADER_2

	if outline_sprite:
		outline_sprite.material = _outline_mat

	if domino_data != null:
		left_pip_value = domino_data.base_left_pip
		right_pip_value = domino_data.base_right_pip
		if domino_name_label:
			domino_name_label.text = domino_data.domino_name
		_update_pip_visuals()
		_update_background_skin()

	check_playability()

	# Pass the aspect tracking size of the whole outline layout
	if outline_sprite and outline_sprite.texture:
		var o_size = outline_sprite.texture.get_size()
		_outline_mat.set_shader_param("object_scale", o_size)
		_outline_mat2.set_shader_param("object_scale", o_size)

func _input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		if current_status == StatusType.HAND and drag_state == DragState.IDLE:
			rotate_domino()

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		if drag_state == DragState.IDLE and (current_status == StatusType.HAND or current_status == StatusType.BOARD):
			emit_signal("domino_clicked", self)

func start_drag() -> void:
	drag_state = DragState.CLICKED
	z_as_relative = false
	z_index = 1000
	set_process(true)
	_set_label_visible(false)

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
	if outline_sprite:
		outline_sprite.material = null
	input_pickable = false
	z_as_relative = false
	_set_label_visible(false)

func return_to_hand(origin: Vector2) -> void:
	drag_state = DragState.IDLE
	z_index = 0
	set_process(false)
	_set_label_visible(false)
	rotation_step = 3
	rotate_domino()

	var distance = position.length()  # distance from Vector2.ZERO (home)
	var duration = clamp(distance / 200.0, 0.05, Settings.domino_tween_duration)

	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(
		self,
		"position",
		position,
		Vector2.ZERO,
		duration,
		Tween.TRANS_CUBIC,
		Tween.EASE_OUT
	)
	tween.start()
	tween.connect("tween_all_completed", self, "_on_return_tween_completed")
	tween.connect("tween_all_completed", tween, "queue_free")

func _on_return_tween_completed() -> void:
	_set_label_visible(true)

func rotate_domino() -> void:
	rotation_step = (rotation_step + 1) % 4
	rotation_degrees = rotation_step * 90.0
	
	# Handle base skin textures
	if base_sprite:
		base_sprite.texture = load("res://assets/domino/domino_base_" + str(rotation_step) + ".png")
		
	# Update your shader aspect ratio bounds to match the new texture size
	# Assign the correct outline layout file paths dynamically
	if outline_sprite:
		var outline_path = "res://assets/domino/domino_outline_" + str(rotation_step) + ".png"
		outline_sprite.texture = load(outline_path)
		
		# Keep the scaling metrics synchronous in memory
		if outline_sprite.texture:
			var o_size = outline_sprite.texture.get_size()
			if _outline_mat: _outline_mat.set_shader_param("object_scale", o_size)
			if _outline_mat2: _outline_mat2.set_shader_param("object_scale", o_size)
	# Counter-rotate the label so it always reads upright
	if domino_name_label:
		domino_name_label.rect_rotation = -rotation_degrees
		
	# 3. Handle bottom lip positioning and textures
	lip_sprite.rotation_degrees = -rotation_degrees
	if is_vertical():
		lip_sprite.texture = load("res://assets/domino/lip_narrow.png")
	else:
		lip_sprite.texture = load("res://assets/domino/lip_wide.png")
		
	match rotation_step:
		0: # Horizontal Default
			lip_sprite.position = Vector2(24, 11)
			domino_name_label.rect_position = Vector2(-24, 20)
			if outline_sprite: 
				outline_sprite.position = Vector2(-24, -8)
		1: # 90 deg CW
			lip_sprite.position = Vector2(52, -5)
			domino_name_label.rect_position = Vector2(36, 24)
			if outline_sprite: 
				outline_sprite.position = Vector2(-21, -10) 
		2: # 180 deg Flipped Horizontal
			lip_sprite.position = Vector2(24, -21)
			domino_name_label.rect_position = Vector2(24, -20)
			if outline_sprite: 
				outline_sprite.position = Vector2(-24, -13)
		3: # 270 deg CCW
			lip_sprite.position = Vector2(-4, -5)
			domino_name_label.rect_position = Vector2(-34, -24)
			if outline_sprite: 
				outline_sprite.position = Vector2(-27, -10)

func get_top_pip() -> int:
	match rotation_step:
		1: return left_pip_value
		3: return right_pip_value
	return -1

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

func set_selected_visual(selected: bool) -> void:
	if selected:
		modulate = Color(1, 1, 1, 0.75)
	else:
		modulate = Color.white
		scale = Vector2.ONE

func set_selectable_visual(selectable: bool) -> void:
	if outline_sprite and outline_sprite.material:
		var mat = outline_sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_param("is_active", selectable)

func _set_label_visible(visible: bool) -> void:
	if domino_name_label:
		domino_name_label.visible = visible
