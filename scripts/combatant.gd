extends RefCounted
## Something that fights: the player or the enemy. Holds HP, shield and statuses, and knows how to
## take damage and work out the damage it deals. (The old code kept these as two loose dictionaries.)

const DamageCmd = preload("res://scripts/cmd/damage_cmd.gd")
const StatusFury = preload("res://scripts/status/status_fury.gd")
const StatusPower = preload("res://scripts/status/status_power.gd")
const StatusBoost = preload("res://scripts/status/status_boost.gd")
const StatusStalwart = preload("res://scripts/status/status_stalwart.gd")
const StatusBerserk = preload("res://scripts/status/status_berserk.gd")
const StatusRegenerative = preload("res://scripts/status/status_regenerative.gd")

## Order the statuses are listed in on a tag.
const STATUS_ORDER := ["fury", "power", "boost", "berserk", "stalwart", "regenerative"]

var hp := 50
var max_hp := 50
var shield := 0
var max_shield := 9
var statuses := {}     # id -> Status (each one is a model, see model.gd)


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
		"stalwart":
			return StatusStalwart.new()
		"berserk":
			return StatusBerserk.new()
		"regenerative":
			return StatusRegenerative.new()
	push_error("unknown status: " + id)
	return null


## The status with this id (it is created at 0 the first time it is asked for).
func status(id: String):
	if not statuses.has(id):
		statuses[id] = _make_status(id)
		statuses[id].owner = self
	return statuses[id]


## The models that live on this combatant (its statuses).
func models() -> Array:
	return statuses.values()


func value(id: String) -> int:
	return statuses[id].value if statuses.has(id) else 0


func add(id: String, n: int) -> void:
	var s = status(id)
	s.value += n


## Damage this combatant deals with only its own statuses counted (never below 0). The game asks
## DamageCmd.attack_value instead, which also counts the target, relics and every other model.
func attack_damage(base: int) -> int:
	return DamageCmd.calculate(models(), base, {"source": self, "base": base})


## Tick this combatant's own statuses after an attack (Fury / Impair toward 0, Boost used up, Power
## stays). Used for copies in previews. In the game, DamageCmd.finish_attack runs the after_attack
## hook on every model instead.
func finish_attack() -> void:
	for s in models():
		s.after_attack(null, {"source": self})


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


## Like status_lines(), but each status comes with its icon: [{k, text, name, num}].
func status_entries() -> Array:
	var out := []
	for id in STATUS_ORDER:
		if statuses.has(id):
			var s = statuses[id]
			var t: String = s.text()
			if t != "":
				out.append({"k": s.icon_id(), "text": t, "name": s.label(), "num": s.number()})
	return out


## Everything about this combatant as plain data, and the way back (for restarting a turn).
func get_state() -> Dictionary:
	var st := {}
	for id in statuses:
		st[id] = statuses[id].value
	return {"hp": hp, "max_hp": max_hp, "shield": shield, "max_shield": max_shield, "statuses": st}


func set_state(s: Dictionary) -> void:
	hp = s.hp
	max_hp = s.max_hp
	shield = s.shield
	max_shield = s.max_shield
	statuses.clear()
	for id in s.statuses:
		add(id, s.statuses[id])


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
