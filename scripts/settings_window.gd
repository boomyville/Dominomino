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

var _buttons := {}


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
	close_b.pressed.connect(close)


func open() -> void:
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(Settings.get_value(key))
		_update_text(key)
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
