extends "res://scripts/effects/effect.gd"
## Find a domino in your stack and add it to your hand.


func text(_game, _s: int) -> String:
	return "Find a domino in your stack and add it to your hand"


func apply(game, _domino, _s: int) -> void:
	if game.stack.is_empty():
		game.ui.toast("Your stack is empty")
	elif game.hand.size() >= game.MAXH:
		game.ui.hand_full()
	else:
		var order: Array = game.stack_order_by_title()
		var list: Array = []
		for k in order:
			list.append(game.stack[k])
		var c: int = await game.ui.pick("Find a domino", "Choose a domino from your stack to add to your hand.", list)
		await game.tutor_take(order, c)
