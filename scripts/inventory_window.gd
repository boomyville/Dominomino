extends PanelContainer
## The inventory: your artifacts (relics). Only the equipped ones (at most Game.EQUIP_SLOTS) have
## any effect. Equip / Unequip moves one between the two lists.

signal closed

const Icons = preload("res://scripts/icons.gd")
const DominoText = preload("res://scripts/domino_text.gd")

@onready var slots_l: Label = %Slots
@onready var rows: VBoxContainer = %Rows
@onready var close_b: Button = %Close

var _game = null


func _ready() -> void:
	visible = false
	close_b.pressed.connect(close)


func open(game) -> void:
	_game = game
	_rebuild()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _rebuild() -> void:
	var g = _game
	slots_l.text = "Artifact slots: %d / %d" % [g.relics.size(), g.EQUIP_SLOTS]
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	_header("WEAPON (one at a time, it cannot be unequipped, only replaced)")
	if g.weapon != null:
		_row(g.weapon, "weapon_now")
	for w in g.stored_weapons:
		_row(w, "weapon")
	_header("EQUIPPED (%d)" % g.relics.size())
	if g.relics.is_empty():
		_note("Nothing equipped.")
	for r in g.relics:
		_row(r, "equipped")
	_header("UNEQUIPPED (%d)  no effect until equipped" % g.stored_relics.size())
	if g.stored_relics.is_empty():
		_note("Nothing here.")
	for r in g.stored_relics:
		_row(r, "stored")


func _header(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 16)
	rows.add_child(l)


func _note(t: String) -> void:
	var l := Label.new()
	l.text = "  " + t
	l.modulate.a = 0.6
	rows.add_child(l)


func _row(r, mode: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = Icons.relic_texture(r)
	icon.custom_minimum_size = Vector2(Icons.RELIC_SIZE * 2, Icons.RELIC_SIZE * 2)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var rt := RichTextLabel.new()
	DominoText.setup(rt)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.custom_minimum_size = Vector2(380, 0)
	DominoText.fill_relic_line(rt, r)
	h.add_child(rt)
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 30)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if mode == "weapon_now":
		b.text = "Equipped"
		b.disabled = true
	elif mode == "weapon":
		b.text = "Equip"
		b.pressed.connect(func(): _game.equip_weapon(r); _rebuild())
	elif mode == "equipped":
		b.text = "Unequip"
		b.pressed.connect(func(): _game.unequip_relic(r); _rebuild())
	else:
		b.text = "Equip"
		b.disabled = _game.relics.size() >= _game.EQUIP_SLOTS
		b.tooltip_text = "All slots are full: unequip something first" if b.disabled else ""
		b.pressed.connect(func(): _game.equip_relic(r); _rebuild())
	h.add_child(b)
	rows.add_child(h)
