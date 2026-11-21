extends Control
## A flat domino picture (pick window cards, and the "ghost" that follows the pointer while dragging).

const DominoArt = preload("res://scripts/domino_art.gd")

var a := 0
var b := 0
var ang := 0.0
var inverted := false
var dot_tex: Texture2D = null


func _ready() -> void:
	custom_minimum_size = Vector2(56, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_domino(pips_a: int, pips_b: int, turn: float = 0.0, black: bool = false) -> void:
	a = pips_a
	b = pips_b
	ang = turn
	inverted = black
	queue_redraw()


func _draw() -> void:
	DominoArt.draw_flat(self, size / 2.0, ang, a, b, inverted, dot_tex)
