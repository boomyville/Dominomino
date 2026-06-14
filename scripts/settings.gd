# settings_menu.gd
extends PopupPanel

# Explicitly grab references to your toggle buttons
onready var mouse_mode_button = $VBoxContainer/MouseMode
onready var fast_mode_button = $VBoxContainer/FastMode

func _ready() -> void:
	# 1. Sync the visual switches with whatever your global settings currently are
	mouse_mode_button.pressed = Settings.mouse_mode_enabled
	fast_mode_button.pressed = Settings.fast_mode_enabled
	
	# 2. Connect the button signals to change the global variables on click
	mouse_mode_button.connect("toggled", self, "_on_mouse_mode_toggled")
	fast_mode_button.connect("toggled", self, "_on_fast_mode_toggled")
	
	# 3. Automatically pause the game world behind the popup if you want to!
	get_tree().paused = true

	connect("popup_hide", self, "_on_popup_hidden")

func _on_mouse_mode_toggled(button_pressed: bool) -> void:
	Settings.mouse_mode_enabled = button_pressed
	print("Global Mouse Mode updated to: ", Settings.mouse_mode_enabled)

func _on_fast_mode_toggled(button_pressed: bool) -> void:
	Settings.fast_mode_enabled = button_pressed
	print("Global Fast Mode updated to: ", Settings.fast_mode_enabled)

# If the player clicks outside a Godot PopupPanel, it automatically closes itself.
# We intercept that hide event here to clean things up safely!
func _exit_tree() -> void:
	# Resume the game world when this UI is destroyed/removed
	get_tree().paused = false

func _on_popup_hidden() -> void:
	# Destroy this node completely when closed so it doesn't pile up in the background
	queue_free()
