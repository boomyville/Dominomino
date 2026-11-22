extends VBoxContainer
## The domino info screen: what the domino does, and (when Settings.show_status_info is on) one
## card under it for every status the domino uses. Used by the HUD for the selected domino and by
## the stack window for the domino you click.

const DominoText = preload("res://scripts/domino_text.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Settings = preload("res://scripts/settings.gd")

@onready var text: RichTextLabel = %InfoText
@onready var cards: VBoxContainer = %Cards


func _ready() -> void:
	DominoText.setup(text)


## index is the hand position of d (so "not met" can show), or -1 when d is not in the hand.
func show_domino(game, d, index: int = -1) -> void:
	DominoText.fill(text, game, d, index)
	for c in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
	if not Settings.show_status_info:
		return
	for id in Glossary.for_domino(d):
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rt := RichTextLabel.new()
		DominoText.setup(rt)
		rt.custom_minimum_size = Vector2(228, 0)
		DominoText.fill_status(rt, id)
		card.add_child(rt)
		cards.add_child(card)
