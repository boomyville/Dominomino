extends GridContainer
# Preload your physical domino shell scene
const DOMINO_SCENE = preload("res://scenes/domino.tscn")

func add_domino_to_hand(data: DominoData) -> void:
	# 1. Create a lightweight, empty structural UI slot box
	var slot_wrapper = Control.new()
	
	# Tell the layout container exactly how much space to reserve for this tile
	# (Matches your horizontal footprint size!)
	slot_wrapper.rect_min_size = Vector2(48, 24)
	
	# 2. Add the empty slot wrapper box to the HBoxContainer tree first
	add_child(slot_wrapper)
	
	# 3. Spawn your actual physical, interactive domino object
	var new_domino = DOMINO_SCENE.instance()
	
	# Drop the domino INSIDE the placeholder box instead of raw in the hand container
	slot_wrapper.add_child(new_domino)
	
	# 4. Bind your cloned resource characteristics
	new_domino.domino_data = data
	new_domino.current_status = new_domino.StatusType.HAND
	new_domino.current_owner = new_domino.OwnerType.PLAYER
