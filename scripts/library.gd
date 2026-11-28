extends RefCounted
## The library's numbers, kept between runs in user://library.dat. For every domino, artifact and weapon:
##   offered_reward / skipped_reward   it was one of the choices of a reward screen / you did not take it
##   offered_shop / skipped_shop       it was for sale / you could afford it when you left the shop and did not buy it
##   used / wait                       dominoes only: how often it was played, and how many turns it had been in your hand
##                                     when it was played (wait / used = the average; 0 means it was played the turn it arrived)
## Keys are "domino:<title>", "artifact:<id>" and "weapon:<id>". Nothing is written to disk until flush().
## Tests set `path` to another file so they never touch the player's numbers.

static var path := "user://library.dat"
static var stats := {}
static var _loaded := false
static var _dirty := false


static func key(kind: String, id: String) -> String:
	return "%s:%s" % [kind, id]


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(path):
		var v = str_to_var(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			stats = v


## Forget everything in memory (tests) and read again on the next use.
static func reset_memory() -> void:
	stats = {}
	_loaded = true
	_dirty = false


static func entry(kind: String, id: String) -> Dictionary:
	ensure_loaded()
	var k := key(kind, id)
	if not stats.has(k):
		stats[k] = {"offered_reward": 0, "skipped_reward": 0, "offered_shop": 0, "skipped_shop": 0, "used": 0, "wait": 0}
	return stats[k]


## source: "reward" or "shop"
static func offer(kind: String, id: String, source: String) -> void:
	entry(kind, id)["offered_" + source] += 1
	_dirty = true


static func skip(kind: String, id: String, source: String) -> void:
	entry(kind, id)["skipped_" + source] += 1
	_dirty = true


## A domino was played after waiting `waited` turns in your hand.
static func use(title: String, waited: int) -> void:
	var e := entry("domino", title)
	e["used"] += 1
	e["wait"] += maxi(0, waited)
	_dirty = true


## The numbers of one item (all zero if it was never seen).
static func get_stats(kind: String, id: String) -> Dictionary:
	ensure_loaded()
	return stats.get(key(kind, id), {"offered_reward": 0, "skipped_reward": 0, "offered_shop": 0, "skipped_shop": 0, "used": 0, "wait": 0})


static func average_wait(kind: String, id: String) -> float:
	var e := get_stats(kind, id)
	return float(e.wait) / e.used if e.used > 0 else 0.0


## Write the numbers to disk if they changed.
static func flush() -> void:
	if not _dirty:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(var_to_str(stats))
		f.close()
		_dirty = false
