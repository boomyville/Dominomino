# settings_menu.gd
extends PopupPanel

# Explicitly grab references to your toggle buttons
onready var mouse_mode_button = $VBoxContainer/MouseMode
onready var fast_mode_button = $VBoxContainer/FastMode
onready var speed_slider = $VBoxContainer/HBoxContainer/DominoSpeedSlider

func _ready() -> void:
	# 1. Sync the visual switches with whatever your global settings currently are
	mouse_mode_button.pressed = Settings.mouse_mode_enabled
	fast_mode_button.pressed = Settings.fast_mode_enabled
	speed_slider.value = Settings.domino_tween_duration
	
	# 2. Connect the button signals to change the global variables on click
	mouse_mode_button.connect("toggled", self, "_on_mouse_mode_toggled")
	fast_mode_button.connect("toggled", self, "_on_fast_mode_toggled")
	speed_slider.connect("value_changed", self, "_on_speed_slider_changed")

	var speed_display_value : float = 1.1 - Settings.domino_tween_duration
	$VBoxContainer/HBoxContainer/DominoSpeedSlider.value = speed_display_value
	
	# 3. Automatically pause the game world behind the popup if you want to!
	get_tree().paused = true

	connect("popup_hide", self, "_on_popup_hidden")

func _on_mouse_mode_toggled(button_pressed: bool) -> void:
	Settings.mouse_mode_enabled = button_pressed
	print("Global Mouse Mode updated to: ", Settings.mouse_mode_enabled)

func _on_fast_mode_toggled(button_pressed: bool) -> void:
	Settings.fast_mode_enabled = button_pressed
	print("Global Fast Mode updated to: ", Settings.fast_mode_enabled)

func _on_speed_slider_changed(raw_value) -> void:
	var sanitized_value: float = float(raw_value)
	if is_nan(sanitized_value):
		sanitized_value = 0.5
	sanitized_value = stepify(sanitized_value, 0.1)
	
	# NEW INVERSION MATH: 
	# High slider number = low tween time duration!
	var inverted_duration : float = 1.1 - sanitized_value
	
	Settings.domino_tween_duration = inverted_duration
	print("Slider Value: ", sanitized_value, " | Inverted Tween Duration saved as: ", Settings.domino_tween_duration)

# If the player clicks outside a Godot PopupPanel, it automatically closes itself.
# We intercept that hide event here to clean things up safely!
func _exit_tree() -> void:
	# Resume the game world when this UI is destroyed/removed
	get_tree().paused = false

func _on_popup_hidden() -> void:
	# Destroy this node completely when closed so it doesn't pile up in the background
	queue_free()
