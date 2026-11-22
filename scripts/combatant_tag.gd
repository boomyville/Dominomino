extends PanelContainer
## The little box over a character: name, HP bar, shield and statuses, and (for the enemy) its intents.

const DominoText = preload("res://scripts/domino_text.gd")

@onready var title_l: Label = %Title
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_text: Label = %HpText
@onready var preview = %Preview
@onready var status: RichTextLabel = %Status
@onready var intent: RichTextLabel = %Intent


func _ready() -> void:
	DominoText.setup(status)
	DominoText.setup(intent)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	intent.autowrap_mode = TextServer.AUTOWRAP_OFF


## statuses is [{k, text}] (an icon and its text, "Shield 3/9" first), intents is [{k, text}].
## loss is the HP this combatant is about to lose (shown as a dark block on the bar); note is
## shown after the HP when nothing would be lost (for example "blocked").
func show_combatant(title: String, hp: int, max_hp: int, statuses: Array, intents: Array = [], loss: int = 0, note: String = "") -> void:
	title_l.text = title
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_text.text = "HP %d/%d" % [hp, max_hp]
	if loss > 0:
		hp_text.text += "  -%d" % loss
	elif note != "":
		hp_text.text += "  " + note
	preview.set_preview(hp, max_hp, loss)
	status.clear()
	for i in statuses.size():
		if i > 0:
			status.append_text("   ")
		DominoText.add_icon(status, statuses[i].k)
		DominoText.append_rich(status, " " + statuses[i].text)
	intent.clear()
	intent.visible = intents.size() > 0
	for it in intents:
		DominoText.icon_line(intent, it.k, it.text)
	# let the container shrink to fit the new text
	reset_size()
