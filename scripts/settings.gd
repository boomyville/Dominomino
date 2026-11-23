extends RefCounted
## Player options, saved to user://settings.cfg. Read them anywhere as Settings.show_damage_taken ...
## The Settings window (settings_window.gd) changes them and calls save().

const PATH := "user://settings.cfg"

## Show how much HP you would lose to the enemy's attacks (on the intent line and on your HP bar).
static var show_damage_taken := true
## Show the status name next to its icon ("Impair 3" instead of just "3").
static var show_status_names := false
## Show a card for every status the selected domino uses, under the domino info.
static var show_status_info := false

const KEYS := ["show_damage_taken", "show_status_names", "show_status_info"]

## Animation speed: how long dominoes take to fly (draw, discard, added to hand) and how long the game
## waits between steps. "medium" is the original pacing, "instant" skips the flying and the waiting.
const SPEEDS := {"slow": 1.75, "medium": 1.0, "fast": 0.5, "instant": 0.0}
const SPEED_ORDER := ["slow", "medium", "fast", "instant"]
static var anim_speed := "medium"


static func get_value(key: String) -> bool:
	match key:
		"show_damage_taken":
			return show_damage_taken
		"show_status_names":
			return show_status_names
		"show_status_info":
			return show_status_info
	push_error("unknown setting: " + key)
	return false


static func set_value(key: String, value: bool) -> void:
	match key:
		"show_damage_taken":
			show_damage_taken = value
		"show_status_names":
			show_status_names = value
		"show_status_info":
			show_status_info = value
		_:
			push_error("unknown setting: " + key)


## 1.0 = the original pacing, bigger = slower, 0 = instant.
static func speed_scale() -> float:
	return SPEEDS[anim_speed]


## Change the animation speed and save it. An unknown id is ignored.
static func set_speed(id: String) -> void:
	if SPEEDS.has(id):
		anim_speed = id
		save()


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in KEYS:
		set_value(k, bool(cfg.get_value("options", k, get_value(k))))
	var id := str(cfg.get_value("options", "anim_speed", "medium"))
	anim_speed = id if SPEEDS.has(id) else "medium"


static func save() -> void:
	var cfg := ConfigFile.new()
	for k in KEYS:
		cfg.set_value("options", k, get_value(k))
	cfg.set_value("options", "anim_speed", anim_speed)
	cfg.save(PATH)
