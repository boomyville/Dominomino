extends RefCounted
## What each pip number stands for. The element name is also the icon name (img/icons/fire.png ...).
##   1 light   2 earth   3 water / ice   4 fire   5 lightning / storm   6 darkness

const NAMES := {1: "light", 2: "earth", 3: "water", 4: "fire", 5: "lightning", 6: "darkness"}


static func icon(pip: int) -> String:
	return NAMES.get(pip, "")


static func label(pip: int) -> String:
	return NAMES.get(pip, "%d" % pip)
