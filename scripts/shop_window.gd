extends PanelContainer
## The shop: 5 dominoes, 2 artifacts, 1 weapon and 1 upgrade for gems (game.shop). Buy with the button under
## each card. The upgrade is one of: pick a domino (5 gems), a random domino (3) or 2 random dominoes (6).
## Buying "pick" first shows the dominoes you can upgrade, each as it would look after the upgrade.
## Leave shop closes it (Back, while you are choosing).

signal closed

const CardScene = preload("res://scenes/domino_card.tscn")

@onready var gems_l: Label = %Gems
@onready var grid: GridContainer = %Grid
@onready var leave_b: Button = %Leave

var _game = null
var _note_l: Label = null
var _picking := -1       # index of the upgrade being paid for while you choose a domino, else -1


func _ready() -> void:
	visible = false
	leave_b.pressed.connect(_on_leave)
	_note_l = Label.new()
	_note_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var box := gems_l.get_parent().get_parent()
	box.add_child(_note_l)
	box.move_child(_note_l, gems_l.get_parent().get_index() + 1)


func open(game) -> void:
	_game = game
	_picking = -1
	_rebuild()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _on_leave() -> void:
	if _picking >= 0:
		_picking = -1
		_rebuild()
	else:
		close()


func _clear() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()


func _rebuild() -> void:
	var g = _game
	gems_l.text = "Gems: %d" % g.gems
	_note_l.text = g.shop_note
	_note_l.visible = g.shop_note != ""
	leave_b.text = "Leave shop"
	_clear()
	for i in g.shop.size():
		var e: Dictionary = g.shop[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)         # in the tree first: the card sets itself up when it is added
		var card = CardScene.instantiate()
		cell.add_child(card)
		card.show_item(g, e.item)
		card.focus_mode = Control.FOCUS_NONE
		var kind: String = {"domino": "Domino", "relic": "Artifact", "weapon": "Weapon", "upgrade": "Upgrade"}[e.kind]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 30)
		if e.sold:
			b.text = "Sold"
			b.disabled = true
			card.modulate.a = 0.4
		else:
			var price: int = g.shop_price(i)
			b.text = "%s: buy for %d" % [kind, price]
			if e.kind == "upgrade" and e.mode == "pick":
				b.text = "Upgrade: choose, %d" % price
			b.disabled = not g.can_buy(i)
			if e.kind == "upgrade" and g.gems >= price and g.upgradable_dominoes().is_empty():
				b.text = "Nothing to upgrade"
			if e.kind == "upgrade" and e.mode == "pick":
				b.pressed.connect(_start_pick.bind(i))
			else:
				b.pressed.connect(func(): g.buy(i); _rebuild())
		cell.add_child(b)


func _start_pick(i: int) -> void:
	_picking = i
	_rebuild_picker()


## The dominoes you can upgrade, each shown as it would be after the upgrade.
func _rebuild_picker() -> void:
	var g = _game
	gems_l.text = "Choose a domino to upgrade (%d gems)" % g.shop_price(_picking)
	_note_l.visible = false
	leave_b.text = "Back"
	_clear()
	for d in g.upgradable_dominoes():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		var card = CardScene.instantiate()
		cell.add_child(card)
		var after = d.copy()
		after.upgrade()
		card.show_domino(g, after)
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(_on_pick.bind(d))
		var l := Label.new()
		l.text = "%s: level %d to %d" % [d.data.title, d.level(), d.level() + 1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)


func _on_pick(d) -> void:
	_game.buy(_picking, d)
	_picking = -1
	_rebuild()
