extends PanelContainer
## "Choose a domino" window: discard, find in the stack, reroll, and the battle reward (with a Skip button).
## ask() waits for the player and returns the index chosen, or -1 for Skip.

signal chosen(index)

const CardScene = preload("res://scenes/domino_card.tscn")

@onready var title_l: Label = %Title
@onready var sub_l: Label = %Sub
@onready var grid: GridContainer = %Grid
@onready var skip_b: Button = %Skip


func _ready() -> void:
	visible = false
	skip_b.pressed.connect(_choose.bind(-1))


func ask(game, title: String, sub: String, list: Array, skip_text: String = "") -> int:
	title_l.text = title
	sub_l.text = sub
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for i in list.size():
		var card = CardScene.instantiate()
		grid.add_child(card)
		card.show_item(game, list[i])
		card.pressed.connect(_choose.bind(i))
	skip_b.visible = skip_text != ""
	skip_b.text = skip_text
	visible = true
	var r: int = await chosen
	visible = false
	return r


func _choose(index: int) -> void:
	chosen.emit(index)
