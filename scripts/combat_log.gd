extends RefCounted
## What has happened in this battle, as a list of small dictionaries. Cleared when a battle starts.
## Anything that needs a count ("attacks last turn", "HP lost this battle") asks the log when it is
## needed. It does not keep its own counter.
##
## Every event has type, turn (battle turn, 1 = first) and seq (running number), plus its own data.
## Keep event data to plain values (strings, ints, bools) so a query is a simple match.
##
## Event types: battle_started, turn_started, turn_ended {hand_empty}, domino_played {a, b, cost,
## attack}, card_drawn {title}, card_discarded {title}, damage {from, to, taken, absorbed, kind},
## hp_lost {who, amount, kind}, power_applied {to, power, amount}, attack_finished {who},
## relic_fired {relic}.   ("from" / "to" / "who" are "p" for you and "c" for the enemy.)

var turn := 1
var events: Array = []


func clear() -> void:
	events.clear()
	turn = 1


## The log as plain data, and the way back (restarting a turn puts the history back too).
func save() -> Dictionary:
	return {"turn": turn, "events": events.duplicate(true)}


func load_saved(data: Dictionary) -> void:
	turn = data.turn
	events = data.events.duplicate(true)


func next_turn() -> void:
	turn += 1


func add(type: String, data: Dictionary = {}) -> Dictionary:
	var e := data.duplicate()
	e["type"] = type
	e["turn"] = turn
	e["seq"] = events.size()
	events.append(e)
	return e


## Events of this type (all types when type is "") whose fields match every key in where.
func query(type: String = "", where: Dictionary = {}) -> Array:
	var out := []
	for e in events:
		if type != "" and e.type != type:
			continue
		var ok := true
		for k in where:
			if not e.has(k) or e[k] != where[k]:
				ok = false
				break
		if ok:
			out.append(e)
	return out


func count(type: String, where: Dictionary = {}) -> int:
	return query(type, where).size()


func has(type: String, where: Dictionary = {}) -> bool:
	return not query(type, where).is_empty()


## The most recent matching event, or {} if there is none.
func last(type: String, where: Dictionary = {}) -> Dictionary:
	var found := query(type, where)
	return found[found.size() - 1] if not found.is_empty() else {}


## Add up one numeric field over the matching events.
func sum(type: String, key: String, where: Dictionary = {}) -> int:
	var n := 0
	for e in query(type, where):
		n += int(e.get(key, 0))
	return n


## True when there was an earlier turn in this battle (some conditions look at the turn before).
func has_previous_turn() -> bool:
	return turn > 1


## The turn before this one, for use in a where filter: {"turn": log.prev()}.
func prev() -> int:
	return turn - 1
