extends PanelContainer
## Game over window: the statistics in two columns (each a name and a value) and a New game button.

signal new_game_pressed

@onready var rows: GridContainer = %Rows
@onready var new_game_b: Button = %NewGame


func _ready() -> void:
	visible = false
	new_game_b.pressed.connect(func(): new_game_pressed.emit())


## stats is a list of [name, value] pairs. The first half fills the left column, the rest the right one.
func show_stats(stats: Array) -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	var half := ceili(stats.size() / 2.0)
	for i in half:
		_add_pair(stats[i])
		_add_pair(stats[i + half] if i + half < stats.size() else null)
	visible = true


func _add_pair(r) -> void:
	var k := Label.new()
	k.text = str(r[0]) if r != null else ""
	rows.add_child(k)
	var v := Label.new()
	v.text = str(r[1]) if r != null else ""
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(v)
