extends PanelContainer
## The Settings window: one toggle button per option in settings.gd. Changes are saved at once.

signal changed
signal closed

const Settings = preload("res://scripts/settings.gd")

const LABELS := {
	"show_damage_taken": "Show estimated damage taken",
	"show_status_names": "Show status names next to their icons",
	"show_status_info": "Show status effect info under the domino info",
}

@onready var list: VBoxContainer = %Options
@onready var close_b: Button = %Close
@onready var seed_edit: LineEdit = %Seed

var _buttons := {}
var _speed_buttons := {}


func _ready() -> void:
	visible = false
	for key in Settings.KEYS:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 32)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggled.connect(_on_toggled.bind(key))
		list.add_child(b)
		_buttons[key] = b
	_build_speed_row()
	close_b.pressed.connect(close)


## "Animation speed" and one button for each of Slow, Medium, Fast and Instant, under the toggles.
func _build_speed_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = "Animation speed"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var group := ButtonGroup.new()
	for id in Settings.SPEED_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = id.capitalize()
		b.custom_minimum_size = Vector2(64, 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_speed.bind(id))
		row.add_child(b)
		_speed_buttons[id] = b
	var box := list.get_parent()
	box.add_child(row)
	box.move_child(row, list.get_index() + 1)


func _on_speed(id: String) -> void:
	Settings.set_speed(id)
	changed.emit()


func open(game = null) -> void:
	seed_edit.text = str(game.seed_value) if game != null else ""
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(Settings.get_value(key))
		_update_text(key)
	for id in _speed_buttons:
		_speed_buttons[id].set_pressed_no_signal(id == Settings.anim_speed)
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _on_toggled(on: bool, key: String) -> void:
	Settings.set_value(key, on)
	Settings.save()
	_update_text(key)
	changed.emit()


func _update_text(key: String) -> void:
	_buttons[key].text = "%s: %s" % [LABELS[key], "ON" if Settings.get_value(key) else "OFF"]
