extends RefCounted
## Base class for a play condition: a domino with a condition can only be played while it holds.
## Make a new one by adding a child class and registering it in condition_factory.gd.

var id := ""
var text := ""     # finishes the sentence "Only if ...", for example "you have no shield"


## Is the condition met for the hand domino at index i right now?
func met(_game, _i: int) -> bool:
	return true
