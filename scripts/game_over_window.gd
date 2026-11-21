extends PanelContainer
## Game over window: a two-column table of statistics and a New game button.

signal new_game_pressed

@onready var rows: GridContainer = %Rows
@onready var new_game_b: Button = %NewGame


func _ready() -> void:
	visible = false
	new_game_b.pressed.connect(func(): new_game_pressed.emit())


## stats is a list of [name, value] pairs.
func show_stats(stats: Array) -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	for r in stats:
		var k := Label.new()
		k.text = str(r[0])
		rows.add_child(k)
		var v := Label.new()
		v.text = str(r[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(v)
	visible = true
