extends RefCounted
## Something that fights: the player or the enemy. Holds HP, shield and statuses, and knows how to
## take damage and work out the damage it deals. (The old code kept these as two loose dictionaries.)

const StatusFury = preload("res://scripts/status/status_fury.gd")
const StatusPower = preload("res://scripts/status/status_power.gd")
const StatusBoost = preload("res://scripts/status/status_boost.gd")

## Order the statuses are listed in on a tag.
const STATUS_ORDER := ["fury", "power", "boost"]

var hp := 50
var max_hp := 50
var shield := 0
var max_shield := 9
var statuses := {}     # id -> Status


func _init(hit_points: int = 50) -> void:
	hp = hit_points
	max_hp = hit_points


static func _make_status(id: String):
	match id:
		"fury":
			return StatusFury.new()
		"power":
			return StatusPower.new()
		"boost":
			return StatusBoost.new()
	push_error("unknown status: " + id)
	return null


## The status with this id (it is created at 0 the first time it is asked for).
func status(id: String):
	if not statuses.has(id):
		statuses[id] = _make_status(id)
	return statuses[id]


func value(id: String) -> int:
	return statuses[id].value if statuses.has(id) else 0


func add(id: String, n: int) -> void:
	var s = status(id)
	s.value += n


## Damage this combatant deals after every status has had its say (never below 0).
func attack_damage(base: int) -> int:
	var n := base
	for s in statuses.values():
		n = s.modify_damage(n)
	return maxi(0, n)


## Call once after an attack: Fury / Impair tick toward 0 and Boost is used up. Power stays.
func finish_attack() -> void:
	for s in statuses.values():
		s.on_attack_done()


## Shield soaks damage first. Returns {absorbed, taken}.
func take_damage(n: int) -> Dictionary:
	n = maxi(0, n)
	var absorbed := mini(shield, n)
	var taken := n - absorbed
	shield -= absorbed
	hp = maxi(0, hp - taken)
	return {"absorbed": absorbed, "taken": taken}


func lose_hp(n: int) -> void:
	hp = maxi(0, hp - n)


## Heals up to max HP. Returns how much was actually healed.
func heal(n: int) -> int:
	var h := mini(n, max_hp - hp)
	hp += h
	return h


## One text per status that is on, in tag order ("Fury 3", "Power +1" ...).
func status_lines() -> Array:
	var out := []
	for id in STATUS_ORDER:
		if statuses.has(id):
			var t: String = statuses[id].text()
			if t != "":
				out.append(t)
	return out


## Like status_lines(), but each status comes with its icon: [{k, text}].
func status_entries() -> Array:
	var out := []
	for id in STATUS_ORDER:
		if statuses.has(id):
			var s = statuses[id]
			var t: String = s.text()
			if t != "":
				out.append({"k": s.icon_id(), "text": t})
	return out


## A plain Combatant with the same HP, shield and statuses, for working out "what would happen"
## (the damage previews) without touching the real one.
func snapshot():
	var c = load("res://scripts/combatant.gd").new(max_hp)
	c.hp = hp
	c.shield = shield
	c.max_shield = max_shield
	for id in statuses:
		c.add(id, statuses[id].value)
	return c


## Text shown when Fury / Impair changes (never empty).
func fury_text() -> String:
	var t: String = status("fury").text()
	return t if t != "" else "Fury 0"
