extends RefCounted
## One relic you own. A relic is data (a row of relics.gd) plus this small interpreter:
##   WHEN it fires (hook), an optional CONDITION that must hold, and ONE ACTION with an amount.
##
## Hooks (when game.gd calls fire_relics):
##   battle    when a battle starts (the player has just been reset)
##   turn      at the start of each of your turns, including the first turn of a battle
##   turn_end  when you press End turn, before the enemy acts
##   play      when you play a domino, before its effects (ctx = {a, b, cost})
##   victory   when you win a battle (before the rewards)
##   passive   never fires: the amount is simply added to a number the game asks about
##
## Conditions ("if" in the row, "" = always):
##   noShield, fullShield, excessShield   your shield is 0 / equals max shield / is above max shield
##   energy4        you have 4 or more energy
##   noAtkLast      you played no attack dominoes last turn
##   emptyLast      you ended last turn with no dominoes in hand
##   spentAll       the domino you just played used up your last energy
##   pip            the domino you played has the pip number in "pip"
##   double         the domino you played has the same pip on both halves
##   lowLives       you have fewer lives than you started with
##   every3         the battle you just won was the 3rd, 6th, 9th ...
##   oneLife        you have exactly 1 life
##   halfHp         your HP is half or less
##
## Actions ("do" in the row, "v" is the amount):
##   energy  shield  max_shield  draw  fury  power  boost  impair (on the enemy)  heal  damage (to the enemy)
##   restack (shuffle v random discarded dominoes back into the stack)  max_hp  life
## Passive keys: max_energy (energy you get each turn), max_hp (more max HP), rewards (extra dominoes offered
## after a battle), gems (extra gems after a battle), shop_discount (gems off every shop price) and rewind
## (the Time Pendant: shows the Rewind turn button).
##
## A WEAPON is a relic with "weapon": true and no hook. It adds dominoes instead: each entry of "adds" is
## {t: domino name, n: how many, a, b: pips (-1 = random), when: battle or turn, pos: stack, bottom, top or hand}.
## You can carry many weapons but have only ONE equipped: it cannot be unequipped, only replaced.
## "once": true means it can fire at most once per turn.

var id := ""
var title := ""
var rarity := "c"
var text := ""
var hook := ""
var cond := ""
var act := ""
var amount := 0
var pip := -1
var once := false
var weapon := false
var starter := false      # you start the run with it: never offered as a reward or sold
var adds := []
var _last_key := -1

const RARITY_NAMES := {"c": "Common", "u": "Uncommon", "r": "Rare"}


func setup(row: Dictionary, icons) -> void:
	title = row.n
	id = icons.slug(title)
	rarity = row.r
	text = row.text
	cond = row.get("if", "")
	amount = int(row.get("v", 0))
	pip = int(row.get("pip", -1))
	once = bool(row.get("once", false))
	weapon = bool(row.get("weapon", false))
	starter = bool(row.get("starter", false))
	adds = row.get("adds", [])
	hook = row.get("on", "")
	act = row.get("do", "")


func is_relic() -> bool:
	return true


## Forget "once per turn" memory (after a battle or turn is restarted).
func reset_runtime() -> void:
	_last_key = -1


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func kind_name() -> String:
	return "weapon" if weapon else "artifact"


## The description without :icon: tokens (for tooltips and toasts).
func plain_text() -> String:
	var re := RegEx.new()
	re.compile(":([a-z_]+):")
	return re.sub(text, "$1", true).replace("_", " ")


func tooltip() -> String:
	return "%s (%s %s)\n%s" % [title, rarity_name(), kind_name(), plain_text()]


## How much this relic adds to a passive number (0 if it is not a passive for that key).
func passive_value(key: String) -> int:
	return amount if hook == "passive" and act == key else 0


## Called by game.gd for every hook. Does nothing unless this is the right hook and the condition holds.
func trigger(game, which: String, ctx: Dictionary = {}) -> void:
	if which != hook or hook == "passive":
		return
	if not _holds(game, ctx):
		return
	if once:
		var key: int = game.battle_no * 1000 + game.bat.turn
		if key == _last_key:
			return
		_last_key = key
	_do(game)


func _holds(game, ctx: Dictionary) -> bool:
	match cond:
		"":
			return true
		"noShield":
			return game.pl.shield == 0
		"fullShield":
			return game.pl.shield == game.pl.max_shield
		"excessShield":
			return game.pl.shield > game.pl.max_shield
		"energy4":
			return game.energy >= 4
		"noAtkLast":
			return game.bat.last_attacks == 0
		"emptyLast":
			return game.bat.last_empty
		"spentAll":
			return game.energy == 0 and int(ctx.get("cost", 0)) > 0
		"pip":
			return int(ctx.get("a", -1)) == pip or int(ctx.get("b", -1)) == pip
		"double":
			return ctx.has("a") and ctx.get("a") == ctx.get("b")
		"lowLives":
			return game.lives < game.START_LIVES
		"halfHp":
			return game.pl.hp * 2 <= game.pl.max_hp
		"every3":
			return game.battle_no % 3 == 0
		"oneLife":
			return game.lives == 1
	push_error("unknown relic condition: " + cond)
	return false


func _do(game) -> void:
	match act:
		"energy":
			game.gain_energy(amount)
		"shield":
			game.gain_shield(amount)
		"max_shield":
			game.pl.max_shield += amount
			game.ui.float_text("p", "Max shield +%d" % amount)
		"draw":
			if hook == "play":
				game.relic_draw(amount)
			else:
				# turn and battle hooks only count the extra cards: game.gd draws them with the others
				game.bat.extra_draw += amount
		"fury":
			game.pl.add("fury", amount)
			game.ui.float_text("p", game.pl.fury_text())
		"power":
			game.pl.add("power", amount)
			game.ui.float_text("p", "Power +%d" % amount)
		"boost":
			game.pl.add("boost", amount)
			game.ui.float_text("p", "Boost +%d" % amount)
		"impair":
			game.foe.add("fury", -amount)
			game.ui.float_text("c", game.foe.fury_text())
		"heal":
			var healed: int = game.pl.heal(amount)
			game.stats.healed += healed
			game.ui.float_text("p", "+%d HP" % healed)
		"damage":
			game.hit_foe(amount)
		"restack":
			game.restack_random(amount)
		"max_hp":
			game.pl.max_hp += amount
			game.pl.hp += amount
			game.ui.float_text("p", "Max HP +%d" % amount)
		"life":
			game.lives += amount
			game.ui.float_text("p", "+%d life" % amount)
		_:
			push_error("unknown relic action: " + act)
