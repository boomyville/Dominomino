extends Button
## One choice in the pick window: the domino picture and its text.

const DominoText = preload("res://scripts/domino_text.gd")

@onready var picture = %Flat
@onready var body: RichTextLabel = %Text


func show_domino(game, d) -> void:
	picture.set_domino(d.a, d.b)
	DominoText.setup(body)
	DominoText.fill(body, game, d)
