extends GridContainer
# Preload your physical domino shell scene
const DOMINO_SCENE = preload("res://scenes/domino.tscn")

# Spawns a domino card into the player's physical hand using a data resource packet
func add_domino_to_hand(data: DominoData) -> void:
	var new_domino = DOMINO_SCENE.instance()
	
	# Add it to the HBoxContainer tree first so its anchors are set
	add_child(new_domino)
	
	# Pass the card layout data and set states
	new_domino.domino_data = data
	new_domino.current_status = new_domino.StatusType.HAND
	new_domino.current_owner = new_domino.OwnerType.PLAYER
