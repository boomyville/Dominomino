extends RefCounted
## Headless stand-in for the UI. game.gd calls these hooks while it plays a turn;
## main.gd provides the real versions. In tests you can queue answers for pick().

var picks: Array = []    # queued answers for pick(); when empty, pick() answers 0 (the first option)
var log: Array = []      # every float / toast / flash is recorded here so tests can look at it
var flashes := 0
var swings: Array = []
var finished_count := 0


func refresh() -> void:
	pass


## Waits for sec seconds in the real UI. Here it returns at once.
func pause(_sec: float) -> void:
	pass


## Ask the player to choose one of the dominoes in list. Returns its index, or -1 for skip.
func pick(title: String, _sub: String, _list: Array, _skip: String = "") -> int:
	log.append("pick: " + title)
	if picks.size() > 0:
		return picks.pop_front()
	return 0


func float_text(who: String, text: String) -> void:
	log.append("%s: %s" % [who, text])


func toast(text: String) -> void:
	log.append("toast: " + text)


func hand_full() -> void:
	log.append("toast: Hand size is maxed")


func flash() -> void:
	flashes += 1


func swing(who: String) -> void:
	swings.append(who)


func fresh(_index: int) -> void:
	pass


func note_play() -> void:
	pass


func finished() -> void:
	finished_count += 1
