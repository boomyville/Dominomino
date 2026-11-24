extends Control
## A domino flying across the screen, for show only. It cannot be clicked. The real domino in the
## hand waits (locked and not drawn) until arrive() finishes.
##   arrive(): flies from where it comes from to its slot in the hand in a parabola, growing and
##             untwisting on the way. The slot can move (the hand re-centres), so it is asked for
##             every frame; if the slot is gone the flyer just disappears.
##   fling():  speeds up, spins and leaves the screen (a discard). Can be called while it is arriving.
## finished(landed) fires once: landed is false when the flyer was cancelled.

signal finished(landed)

const DominoArt = preload("res://scripts/domino_art.gd")
const SIZE := Vector2(72, 72)

var a := 0
var b := 0
var ang := 0.0
var dot_tex: Texture2D = null
var look: Array = []

var _mode := ""
var _from_fn := Callable()
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _target := Callable()
var _dur := 0.5
var _delay := 0.0
var _t := 0.0
var _arc := 0.0
var _spin := 0.0
var _started := false
var _center := Vector2.ZERO


func _ready() -> void:
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func setup(d, tex: Texture2D) -> void:
	a = d.a
	b = d.b
	ang = d.ang
	look = DominoArt.sides(d)
	dot_tex = tex


## from_fn() gives the start (screen position of the centre), target() gives the landing spot or
## null when the slot has gone. arc is how high the path bulges (pixels).
func arrive(from_fn: Callable, target: Callable, duration: float, delay: float, arc: float) -> void:
	_mode = "arrive"
	_from_fn = from_fn
	_target = target
	_dur = maxf(duration, 0.01)
	_delay = delay
	_arc = arc
	_spin = -PI * 0.75
	_t = 0.0
	_started = false
	visible = false


## Leave towards `to` from where it is now (or from `from` if it has not started yet).
func fling(from: Vector2, to: Vector2, duration: float, arc: float, spin: float) -> void:
	_mode = "fling"
	_from = _center if _started else from
	_to = to
	_dur = maxf(duration, 0.01)
	_arc = arc
	_spin = spin
	_delay = 0.0
	_t = 0.0
	_started = true
	visible = true


func center() -> Vector2:
	return _center


func _process(delta: float) -> void:
	_t += delta
	if _t < _delay:
		return
	if not _started:
		_from = _from_fn.call()
		_started = true
		_t = _delay
	visible = true
	var t := clampf((_t - _delay) / _dur, 0.0, 1.0)
	if _mode == "arrive":
		var end = _target.call() if _target.is_valid() else null
		if end == null:
			finished.emit(false)
			queue_free()
			return
		var e := 1.0 - pow(1.0 - t, 2.0)                    # slows down as it lands
		_center = _from.lerp(end, e) + Vector2(0.0, -_arc * 4.0 * t * (1.0 - t))
		rotation = _spin * (1.0 - e)
		scale = Vector2.ONE * lerpf(0.5, 1.0, e)
	else:
		var e := t * t                                      # speeds up as it leaves
		_center = _from.lerp(_to, e) + Vector2(0.0, -_arc * 4.0 * t * (1.0 - t))
		rotation = _spin * e
		scale = Vector2.ONE * lerpf(1.0, 0.8, t)
	position = _center - SIZE / 2.0
	if t >= 1.0:
		finished.emit(true)
		queue_free()


func _draw() -> void:
	DominoArt.draw_flat(self, SIZE / 2.0, ang, a, b, false, dot_tex, look)
