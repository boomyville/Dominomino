extends PanelContainer
## The library: every domino, artifact and weapon in the game on three tabs, with what it does and how it has gone for you
## (scripts/library.gd): how often it was offered in rewards and in shops, how often you skipped it, and for dominoes how often you
## played it and how long it waited in your hand first.

signal closed

const CardScene = preload("res://scenes/domino_card.tscn")
const Library = preload("res://scripts/library.gd")
const Relics = preload("res://scripts/relics/relics.gd")

var tab_buttons := {}
var list: VBoxContainer
var close_b: Button
var kind := "domino"
var _game = null


func _ready() -> void:
	visible = false
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "LIBRARY"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	close_b = Button.new()
	close_b.text = "Close"
	close_b.custom_minimum_size = Vector2(90, 30)
	close_b.pressed.connect(close)
	head.add_child(close_b)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	var group := ButtonGroup.new()
	for k in [["domino", "Dominoes"], ["artifact", "Artifacts"], ["weapon", "Weapons"]]:
		var b := Button.new()
		b.text = k[1]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(130, 30)
		b.pressed.connect(show_tab.bind(k[0]))
		tabs.add_child(b)
		tab_buttons[k[0]] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)


func open(game) -> void:
	_game = game
	show_tab("domino")
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func show_tab(which: String) -> void:
	kind = which
	tab_buttons[which].set_pressed_no_signal(true)
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	match which:
		"domino":
			for base in _game.data:
				if ["c", "u", "r", "l"].has(base.rarity):
					_row(_game.make_domino(base.id), "domino", base.title)
		"artifact":
			for r in Relics.build():
				_row(r, "artifact", r.id)
		"weapon":
			for r in Relics.build_weapons():
				_row(r, "weapon", r.id)


func entries() -> int:
	return list.get_child_count()


func _row(item, which: String, id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	list.add_child(row)
	var card = CardScene.instantiate()
	card.custom_minimum_size = Vector2(380, 130)
	row.add_child(card)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if which == "domino":
		card.show_domino(_game, item)
	else:
		card.show_item(_game, item)
	var l := Label.new()
	l.text = stats_text(which, id)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)


## The numbers shown beside an item.
static func stats_text(which: String, id: String) -> String:
	var s := Library.get_stats(which, id)
	var lines := []
	lines.append("Offered in rewards: %d    skipped: %s" % [s.offered_reward, _rate(s.skipped_reward, s.offered_reward)])
	lines.append("Offered in shops: %d    skipped when you could afford it: %s" % [s.offered_shop, _rate(s.skipped_shop, s.offered_shop)])
	if which == "domino":
		lines.append("Played: %d times" % s.used)
		if s.used > 0:
			lines.append("Waited %.1f turns in your hand before it was played" % Library.average_wait(which, id))
		else:
			lines.append("Not played yet")
	return "\n".join(lines)


static func _rate(part: int, whole: int) -> String:
	return "%d (%d%%)" % [part, roundi(100.0 * part / whole)] if whole > 0 else "0"
