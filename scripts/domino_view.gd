extends Control
## One domino in the hand tray. It draws itself (flat domino, effect icons with numbers underneath,
## the blinking ring when it can be played) and turns mouse / touch into signals:
##   tapped          press and release without moving
##   drag_started    the pointer moved far enough to count as a drag
##   drag_moved      while dragging (global position)
##   drag_released   the drag ended (global position)
##   rotate_requested  right-click while dragging
## While locked (the domino is still flying into the hand) it draws nothing and ignores the mouse.
## Godot keeps sending mouse events to this control until the button is released, so it can follow a
## drag all the way onto the board.

signal tapped(view)
signal drag_started(view)
signal drag_moved(view, pos)
signal drag_released(view, pos)
signal rotate_requested(view)

const DominoArt = preload("res://scripts/domino_art.gd")
const Icons = preload("res://scripts/icons.gd")
const DRAG_DISTANCE := 8.0
const CAP_FONT_SIZE := 10

var domino = null              # the Domino shown
var index := 0                 # its position in the hand
var selected := false          # drawn black
var playable := false          # blinking ring
var chips: Array = []          # effect icons + numbers, from game.caps()
var locked := false            # a flying copy is on its way (or away): draw nothing, take no input
var hidden_in_drag := false    # draws nothing while it is being dragged, but still gets the mouse events
var dot_tex: Texture2D = null

var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(56, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func update_view(d, i: int, is_selected: bool, can_play: bool, new_chips: Array, hide_it: bool, is_locked: bool = false) -> void:
	domino = d
	locked = is_locked
	index = i
	selected = is_selected
	playable = can_play
	chips = new_chips
	hidden_in_drag = hide_it
	set_process(playable)     # only a playable domino needs to redraw for the blinking ring
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


## Hide the domino while its flying copy is on screen; a locked domino cannot be selected or dragged.
func set_locked(value: bool) -> void:
	locked = value
	_pressing = false
	_dragging = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
				_dragging = false
				_press_pos = event.global_position
			else:
				if _dragging:
					drag_released.emit(self, event.global_position)
				elif _pressing:
					tapped.emit(self)
				_pressing = false
				_dragging = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _dragging:
			rotate_requested.emit(self)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_pos) > DRAG_DISTANCE:
			_dragging = true
			drag_started.emit(self)
		if _dragging:
			drag_moved.emit(self, event.global_position)
		accept_event()


func _draw() -> void:
	if domino == null or hidden_in_drag or locked:
		return
	var c := Vector2(size.x / 2.0, 30.0)
	DominoArt.draw_flat(self, c, domino.ang, domino.a, domino.b, selected, dot_tex)
	if playable:
		var blink := int(Time.get_ticks_msec() / 250.0) % 2 == 0
		var half := Vector2(28, 16) if posmod(int(domino.ang / 90.0), 2) == 0 else Vector2(16, 28)
		draw_rect(Rect2(c - half, half * 2), Color.BLACK if blink else Color(0.5, 0.5, 0.5), false, 2.0)
	_draw_caps(Vector2(c.x, c.y + 36))


## Effect icons with numbers, centred under the domino. A red X means it cannot be played.
func _draw_caps(top_center: Vector2) -> void:
	var font := get_theme_default_font()
	var widths := []
	for ch in chips:
		var tw := 0.0
		if ch.num != "":
			tw = font.get_string_size(ch.num, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT_SIZE).x + 2
		widths.append(Icons.SIZE + 1 + tw)
	var row_y := top_center.y
	var i := 0
	while i < chips.size():
		# as many chips on this row as fit under the domino
		var j := i
		var rw := 0.0
		while j < chips.size() and (j == i or rw + 4 + widths[j] <= size.x + 8):
			rw += widths[j] + (4 if j > i else 0)
			j += 1
		var x := top_center.x - rw / 2.0
		for k in range(i, j):
			Icons.draw(self, chips[k].k, Vector2(round(x), round(row_y)))
			if chips[k].num != "":
				draw_string(font, Vector2(round(x) + Icons.SIZE + 1, round(row_y) + 8), chips[k].num,
						HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT_SIZE, Color.BLACK)
			x += widths[k] + 4
		row_y += 11
		i = j
