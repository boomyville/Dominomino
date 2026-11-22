extends PanelContainer
## The screen between battles: a blank page with your stats and three buttons.
## ask() shows it and waits until Next battle is pressed.

signal stack_pressed
signal inventory_pressed
signal next_pressed

@onready var title_l: Label = %Title
@onready var note_l: Label = %Note
@onready var hp_bar: ProgressBar = %HpBar
@onready var rows: GridContainer = %Rows
@onready var stack_b: Button = %StackButton
@onready var inv_b: Button = %InventoryButton
@onready var next_b: Button = %NextButton


func _ready() -> void:
	visible = false
	stack_b.pressed.connect(func(): stack_pressed.emit())
	inv_b.pressed.connect(func(): inventory_pressed.emit())
	next_b.pressed.connect(func(): next_pressed.emit())


func ask(game) -> void:
	show_stats(game)
	visible = true
	await next_pressed
	visible = false


func show_stats(game) -> void:
	var pl = game.pl
	title_l.text = "BATTLE %d WON" % game.battle_no
	note_l.text = game.reward_note
	note_l.visible = game.reward_note != ""
	hp_bar.max_value = pl.max_hp
	hp_bar.value = pl.hp
	var s: Dictionary = game.stats
	var list := [
		["HP", "%d / %d" % [pl.hp, pl.max_hp]],
		["Lives", "x%d" % game.lives],
		["Next battle", "Battle %d" % (game.battle_no + 1)],
		["Dominoes owned", game.collection.size()],
		["Artifacts equipped", "%d / %d" % [game.relics.size(), game.EQUIP_SLOTS]],
		["Artifacts unequipped", game.stored_relics.size()],
		["Damage dealt", s.dealt],
		["Damage taken", s.taken],
	]
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	for r in list:
		var k := Label.new()
		k.text = str(r[0])
		rows.add_child(k)
		var v := Label.new()
		v.text = str(r[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(v)
