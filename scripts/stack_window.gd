extends PanelContainer
## The stack window: every domino of the deck, alphabetical. Click one to see its info.
## In battle (game.battle_deck_entries): dominoes not drawn yet are fully visible, dominoes in your
## hand are faded with a border, dominoes already drawn (played or discarded) are faded more.
## Between battles (game.collection_entries) everything is fully visible.
## open_discard() shows only the discard pile (the latest discarded first).

signal closed

const FlatScene = preload("res://scenes/flat_domino.tscn")
const DominoArt = preload("res://scripts/domino_art.gd")
const OPACITY := {"stack": 1.0, "hand": 0.6, "drawn": 0.3}

@onready var title_l: Label = %Title
@onready var legend_l: Label = %Legend
@onready var grid: GridContainer = %Grid
@onready var info = %Info
@onready var close_b: Button = %Close

var _game = null
var _selected = null


func _ready() -> void:
	visible = false
	close_b.pressed.connect(close)


## in_battle false = between battles: the whole collection at full opacity.
func open(game, in_battle: bool) -> void:
	var entries: Array = game.battle_deck_entries() if in_battle else game.collection_entries()
	_show(game, entries, "DOMINO STACK (%d)" % entries.size(),
			"Full: still in the stack.  Bordered: in your hand.  Faded: already drawn." if in_battle \
			else "Every domino you own.")


## Only the dominoes in the discard pile, the latest first, at full opacity.
func open_discard(game) -> void:
	var entries := []
	for i in range(game.discard.size() - 1, -1, -1):
		entries.append({"d": game.discard[i], "state": "stack"})
	_show(game, entries, "DISCARD PILE (%d)" % entries.size(),
			"Dominoes you discarded this battle, the latest first." if not entries.is_empty() \
			else "No dominoes in the discard pile.")


func _show(game, entries: Array, title: String, legend: String) -> void:
	_game = game
	title_l.text = title
	legend_l.text = legend
	legend_l.visible = true
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	info.visible = false
	for e in entries:
		grid.add_child(_entry(e))
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _entry(e: Dictionary) -> Button:
	var d = e.d
	var b := Button.new()
	b.custom_minimum_size = Vector2(172, 36)
	b.modulate.a = OPACITY[e.state]
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color.WHITE
	plain.content_margin_left = 4.0
	plain.content_margin_right = 4.0
	var framed := plain.duplicate()
	framed.set_border_width_all(2)
	framed.border_color = Color.BLACK
	var hover := plain.duplicate()
	hover.bg_color = Color(0.9, 0.9, 0.9)
	b.add_theme_stylebox_override("normal", framed if e.state == "hand" else plain)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	b.add_child(row)
	var flat = FlatScene.instantiate()
	row.add_child(flat)
	flat.set_domino(d.a, d.b, 0.0, false, DominoArt.sides(d))
	var l := Label.new()
	l.text = "%s  %s" % [d.data.title, d.pips_text()]
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	b.pressed.connect(_show_info.bind(d))
	return b


func _show_info(d) -> void:
	_selected = d
	info.visible = true
	info.show_domino(_game, d, _game.hand.find(d))


## Show the info again (the status cards option may have changed while the window was open).
func refresh_info() -> void:
	if visible and _selected != null and info.visible:
		info.show_domino(_game, _selected, _game.hand.find(_selected))
