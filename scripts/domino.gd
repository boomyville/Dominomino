# domino.gd
tool
extends Area2D

# Enums
enum OwnerType { PLAYER, ENEMY, NONE }
enum StatusType { VOID, DISCARD, DRAW, HAND, BOARD, OPPONENT }

# Exportable data
export(Resource) var domino_data setget set_domino_data

# Core variables
var left_pip_value: int = 0
var right_pip_value: int = 0
var current_owner: int = OwnerType.NONE
var current_status: int = StatusType.VOID
var upgrade_level: int = 1

# Node references
onready var base_sprite = $BaseSprite
onready var left_pip_sprite = $LeftPip/PipSprite
onready var right_pip_sprite = $RightPip/PipSprite

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

	# Validate pip values
	left_pip_value = _sanitise_pip_value(left_pip_value)
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

func _ready() -> void:
	if base_sprite:
		shader_material = ShaderMaterial.new()
		shader_material.shader = OUTLINE_SHADER
		base_sprite.material = shader_material
		print("Created and assigned fresh ShaderMaterial to base_sprite.")
		
	if domino_data != null:
		left_pip_value = domino_data.base_left_pip
		right_pip_value = domino_data.base_right_pip
		_update_pip_visuals()
		_update_background_skin()
	check_playability()
