extends Control
## Sits on top of an HP bar and marks the part of it that is about to be lost: a dark, pulsing
## block from (hp - loss) up to hp. Used for the damage the selected domino would do to the enemy,
## and for the damage the enemy's attacks would do to you.

var hp := 0
var max_hp := 1
var loss := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Show a loss of `lost` HP on a bar that holds `current` of `maximum`. 0 hides it.
func set_preview(current: int, maximum: int, lost: int) -> void:
	hp = current
	max_hp = maxi(1, maximum)
	loss = clampi(lost, 0, current)
	set_process(loss > 0)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if loss <= 0:
		return
	var inner := size.x - 2.0           # the bar has a 1 px border
	var x0 := 1.0 + inner * float(hp - loss) / max_hp
	var x1 := 1.0 + inner * float(hp) / max_hp
	var r := Rect2(x0, 1.0, maxf(x1 - x0, 1.0), size.y - 2.0)
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 130.0)
	draw_rect(r, Color(0, 0, 0, pulse))
	draw_rect(r, Color.BLACK, false, 1.0)
