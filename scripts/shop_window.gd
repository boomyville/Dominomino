extends PanelContainer
## The shop: 5 dominoes, 2 artifacts and 1 weapon for gems (game.shop). Buy with the button under each
## card. Leave shop closes it.

signal closed

const CardScene = preload("res://scenes/domino_card.tscn")

@onready var gems_l: Label = %Gems
@onready var grid: GridContainer = %Grid
@onready var leave_b: Button = %Leave

var _game = null


func _ready() -> void:
	visible = false
	leave_b.pressed.connect(close)


func open(game) -> void:
	_game = game
	_rebuild()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _rebuild() -> void:
	var g = _game
	gems_l.text = "Gems: %d" % g.gems
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for i in g.shop.size():
		var e: Dictionary = g.shop[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)         # in the tree first: the card sets itself up when it is added
		var card = CardScene.instantiate()
		cell.add_child(card)
		card.show_item(g, e.item)
		card.focus_mode = Control.FOCUS_NONE
		var kind: String = {"domino": "Domino", "relic": "Artifact", "weapon": "Weapon"}[e.kind]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 30)
		if e.sold:
			b.text = "Sold"
			b.disabled = true
			card.modulate.a = 0.4
		else:
			var price: int = g.shop_price(i)
			b.text = "%s: buy for %d" % [kind, price]
			b.disabled = g.gems < price
			b.pressed.connect(func(): g.buy(i); _rebuild())
		cell.add_child(b)
