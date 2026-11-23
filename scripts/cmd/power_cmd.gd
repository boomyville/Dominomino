extends RefCounted
## Stateless helper for statuses (Fury, Power, Boost). Effects and relics call apply() instead of
## touching a Combatant's statuses, so every change is logged and shown the same way.
## silent = true is for previews on copies of the combatants.


## Add n to a status (negative n removes it: Impair is negative Fury).
static func apply(game, target, status_id: String, n: int, silent: bool = false) -> void:
	target.add(status_id, n)
	if silent or game == null:
		return
	var side: String = game.side_of(target)
	game.history.add("power_applied", {"to": side, "power": status_id, "amount": n})
	if status_id == "fury":
		game.ui.float_text(side, target.fury_text())
	else:
		game.ui.float_text(side, "%s +%d" % [status_id.capitalize(), n])
