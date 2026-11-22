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


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in KEYS:
		set_value(k, bool(cfg.get_value("options", k, get_value(k))))


static func save() -> void:
	var cfg := ConfigFile.new()
	for k in KEYS:
		cfg.set_value("options", k, get_value(k))
	cfg.save(PATH)
