extends Control
## A flat domino picture (pick window cards, and the "ghost" that follows the pointer while dragging).

const DominoArt = preload("res://scripts/domino_art.gd")

var a := 0
var b := 0
var ang := 0.0
var inverted := false
var dot_tex: Texture2D = null
var look: Array = []        # DominoArt.sides(): ranges and unstable / volatile marks


func _ready() -> void:
	custom_minimum_size = Vector2(56, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_domino(pips_a: int, pips_b: int, turn: float = 0.0, black: bool = false, sides: Array = []) -> void:
	a = pips_a
	b = pips_b
	look = sides
	ang = turn
	inverted = black
	queue_redraw()


func _draw() -> void:
	DominoArt.draw_flat(self, size / 2.0, ang, a, b, inverted, dot_tex, look)
