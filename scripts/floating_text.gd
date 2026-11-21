extends Label
## A number or word that floats up from a character and fades ("-9", "+5 shield", "Blocked").


func start(txt: String, pos: Vector2) -> void:
	text = txt
	add_theme_color_override("font_outline_color", Color.WHITE)
	add_theme_constant_override("outline_size", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = pos - Vector2(get_minimum_size().x / 2.0, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", pos.y - 28.0, 1.1)
	tw.tween_property(self, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)
