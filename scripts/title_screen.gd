extends Control
## The title screen: New game, Load game, Achievements (later), Library, Settings, Quit game. It covers the whole screen
## (the HUD shows it with show_title) and only says which button was pressed.

signal new_game_pressed
signal load_game_pressed
signal achievements_pressed
signal library_pressed
signal settings_pressed
signal quit_pressed

var load_b: Button
var achievements_b: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "DOMINO DOMINION"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "a domino deckbuilder"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap)
	_button(box, "New game", new_game_pressed)
	load_b = _button(box, "Load game", load_game_pressed)
	achievements_b = _button(box, "Achievements", achievements_pressed)
	achievements_b.disabled = true
	achievements_b.tooltip_text = "Coming soon"
	_button(box, "Library", library_pressed)
	_button(box, "Settings", settings_pressed)
	var quit_b := _button(box, "Quit game", quit_pressed)
	quit_b.visible = not OS.has_feature("web")       # a web page cannot close itself


func _button(parent: Control, text: String, sig: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 38)
	b.pressed.connect(func(): sig.emit())
	parent.add_child(b)
	return b


## Load game only works when there is a saved run.
func set_has_save(value: bool) -> void:
	if load_b != null:
		load_b.disabled = not value
