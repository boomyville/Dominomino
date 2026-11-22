extends PanelContainer
## The victory screen, shown right after a battle is won (before the rewards and the screen between
## battles): damage you dealt, HP you lost, gems you earned. ask() waits for Continue.

signal continue_pressed

@onready var title_l: Label = %Title
@onready var rows: GridContainer = %Rows
@onready var continue_b: Button = %Continue


func _ready() -> void:
	visible = false
	continue_b.pressed.connect(func(): continue_pressed.emit())


func ask(game, summary: Dictionary) -> void:
	title_l.text = "VICTORY"
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	_row("Damage dealt", str(summary.dealt))
	_row("HP lost", str(summary.lost))
	_row("Gems earned", "+%d  (you have %d)" % [summary.gems, game.gems])
	visible = true
	await continue_pressed
	visible = false


func _row(k: String, v: String) -> void:
	var a := Label.new()
	a.text = k
	rows.add_child(a)
	var b := Label.new()
	b.text = v
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(b)
