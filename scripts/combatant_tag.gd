extends PanelContainer
## The little box over a character: name, HP bar, shield and statuses, and (for the enemy) its intents.

const DominoText = preload("res://scripts/domino_text.gd")

@onready var title_l: Label = %Title
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_text: Label = %HpText
@onready var status: RichTextLabel = %Status
@onready var intent: RichTextLabel = %Intent


func _ready() -> void:
	DominoText.setup(status)
	DominoText.setup(intent)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	intent.autowrap_mode = TextServer.AUTOWRAP_OFF


## status_text is the line under the HP bar ("Shield 3   Impair 2"); intents is [{k, text}].
func show_combatant(title: String, hp: int, max_hp: int, status_text: String, intents: Array = []) -> void:
	title_l.text = title
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_text.text = "HP %d/%d" % [hp, max_hp]
	status.clear()
	status.append_text(status_text)
	intent.clear()
	intent.visible = intents.size() > 0
	for it in intents:
		DominoText.icon_line(intent, it.k, it.text)
	# let the container shrink to fit the new text
	reset_size()
