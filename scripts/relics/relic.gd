extends "res://scripts/model.gd"
## One relic you own. A relic is a model (see model.gd). It is data (a row of relics.gd) plus this small interpreter:
##   WHEN it fires (hook), an optional CONDITION that must hold, and ONE ACTION with an amount.
##
## Hooks (the model hooks that game.gd dispatches; the name in "on" is the short form):
##   battle    on_battle_start   when a battle starts (the player has just been reset)
##   turn      on_turn_start     at the start of each of your turns, including the first turn of a battle
##   turn_end  on_turn_end       when you press End turn, before the enemy acts
##   play      on_domino_played  when you play a domino, before its effects (ctx = {a, b, cost})
##   victory   on_victory        when you win a battle (before the rewards)
##   passive   never fires: the amount is simply added to a number the game asks about
## A row can set "prio" (lower fires first; the default 0 keeps the order you got the relics in).
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
##   stalwart (v turns of doubled shields)  regenerative (v turns of doubled healing)
##   revive (gain v lives and heal half your max HP; for the "death" hook)
##   death     on_death          you are about to lose (HP 0 or no lives): a chance to be saved
## COUNTERS: a row can have "count": {...} and the relic shows a number on its icon.
##   {"mode": "down", "start": 3}   the counter starts at 3 and goes down by 1 each time the relic works; at 0 it
##                                  breaks. With "vc": true the amount is "v" times the counter (Fragile Gauntlet gives
##                                  3 Power, then 2, then 1, then it is gone).
##   {"mode": "up", "every": 3, "event": "attack", "reset": "turn"}   counts the attacks ("attack"), skills ("skill") or
##                                  all dominoes ("play") you play; every 3 it does its action and the counter drops by 3.
##                                  "reset": "turn" sets it back to 0 at the start of every turn. It never breaks.
## A row with "breaks": true crumbles after it has done its action once (it leaves your inventory for good).
## Passive keys: ignore_hand (every "you must hold N dominoes" condition on your dominoes is ignored), max_energy (energy you get each turn), max_hp (more max HP), rewards (extra dominoes offered
## after a battle), gems (extra gems after a battle), shop_discount (gems off every shop price) and rewind
## (the Time Pendant: shows the Rewind turn button).
##
## A WEAPON also has a LEVEL, like a domino: it can go up to level 4 (common), 3 (uncommon) or 2 (rare), or down to 0.
## The dominoes it adds are made at the weapon's level (as far as they can go), so upgrading the weapon upgrades them.
## A WEAPON is a relic with "weapon": true and no hook. It adds dominoes instead: each entry of "adds" is
## {t: domino name, n: how many, when: battle or turn, pos: stack, bottom, top or hand}. The dominoes have the pips of their kind.
## You can carry many weapons but have only ONE equipped: it cannot be unequipped, only replaced.
## "once": true means it can fire at most once per turn (it asks the combat log, see combat_log.gd).
## Conditions that look at earlier turns also ask the combat log; relics keep no counters of their own.

const CreatureCmd = preload("res://scripts/cmd/creature_cmd.gd")
const DamageCmd = preload("res://scripts/cmd/damage_cmd.gd")
const PowerCmd = preload("res://scripts/cmd/power_cmd.gd")
const DominoData = preload("res://scripts/domino_data.gd")

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
var breaks := false       # it crumbles after it has done its action once
var counter := 0                 # the number shown on the icon (see COUNTERS above)
var counter_mode := ""           # "" (no counter), "down" or "up"
var counter_every := 0           # up counters: the number it counts up to before it works
var counter_event := "play"      # up counters: attack, skill or play
var counter_reset := ""          # up counters: "turn" resets it at the start of every turn
var counter_scales := false      # down counters: the amount is v times the counter
var level := 1            # weapons only: 1 is normal, 0 downgraded, up to 4 / 3 / 2 for common / uncommon / rare

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
	priority = int(row.get("prio", 0))
	breaks = bool(row.get("breaks", false))
	var cnt: Dictionary = row.get("count", {})
	counter_mode = cnt.get("mode", "")
	counter = int(cnt.get("start", 0))
	counter_every = int(cnt.get("every", 0))
	counter_event = cnt.get("event", "play")
	counter_reset = cnt.get("reset", "")
	counter_scales = bool(row.get("vc", false))


func is_relic() -> bool:
	return true


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func kind_name() -> String:
	return "weapon" if weapon else "artifact"


## Weapons only: the highest level (4 common, 3 uncommon, 2 rare). Artifacts have one level.
func max_level() -> int:
	return DominoData.MAX_LEVEL.get(rarity, 1) if weapon else 1


func can_upgrade() -> bool:
	return weapon and level < max_level()


func can_downgrade() -> bool:
	return weapon and level > 0


func upgrade() -> bool:
	if not can_upgrade():
		return false
	level += 1
	return true


func downgrade() -> bool:
	if not can_downgrade():
		return false
	level -= 1
	return true


## "Short Sword", "Short Sword+" (level 2), "Short Sword-" (level 0) ...
func display_name() -> String:
	if not weapon or level == 1:
		return title
	return title + ("-" if level == 0 else "+".repeat(level - 1))


## "Level 2 of 4: the dominoes it adds are level 2." (weapons only)
func level_line() -> String:
	if not weapon:
		return ""
	return "Level %d of %d: the dominoes it adds are level %d." % [level, max_level(), level]


## The description without :icon: tokens (for tooltips and toasts).
func plain_text() -> String:
	var re := RegEx.new()
	re.compile(":([a-z_]+):")
	return re.sub(text, "$1", true).replace("_", " ")


## What the relic does with its amount: v, or v times the counter for a down counter that scales.
func _amount() -> int:
	return amount * counter if counter_mode == "down" and counter_scales else amount


## The number on the relic's icon: the counter, or "2/3" for a counter that counts up. "" for no counter.
func counter_text() -> String:
	match counter_mode:
		"down":
			return str(counter)
		"up":
			return "%d/%d" % [counter, counter_every]
	return ""


## One line about the counter for the info window ("" for no counter).
func counter_line() -> String:
	match counter_mode:
		"down":
			return "Counter: %d. It goes down by 1 each time this works and the artifact breaks at 0." % counter
		"up":
			var what: String = {"attack": "attacks", "skill": "skills", "play": "dominoes"}.get(counter_event, "dominoes")
			return "Counter: %d of %d %s played%s." % [counter, counter_every, what, " this turn" if counter_reset == "turn" else ""]
	return ""


func reset_up_counter() -> void:
	if counter_mode == "up" and counter_reset == "turn":
		counter = 0


## Does this played domino count for an up counter? (ctx comes from the domino_played event)
func _counts(ctx: Dictionary) -> bool:
	match counter_event:
		"attack":
			return ctx.get("attack", false)
		"skill":
			return not ctx.get("attack", false)
	return true


func tooltip() -> String:
	var extra := counter_line()
	return "%s (%s %s)\n%s%s" % [display_name(), rarity_name(), kind_name(), plain_text(), "\n" + extra if extra != "" else ""]


## How much this relic adds to a passive number (0 if it is not a passive for that key).
func passive_value(key: String) -> int:
	return amount if hook == "passive" and act == key else 0


func on_battle_start(game, ctx: Dictionary) -> void:
	if counter_mode == "up":
		counter = 0
	trigger(game, "battle", ctx)


func on_turn_start(game, ctx: Dictionary) -> void:
	reset_up_counter()
	trigger(game, "turn", ctx)


func on_turn_end(game, ctx: Dictionary) -> void:
	trigger(game, "turn_end", ctx)


func on_domino_played(game, ctx: Dictionary) -> void:
	if counter_mode == "up":
		if _counts(ctx):
			counter += 1
			if counter >= counter_every:
				counter -= counter_every
				if _holds(game, ctx):
					_do(game)
		return
	trigger(game, "play", ctx)


func on_victory(game, ctx: Dictionary) -> void:
	trigger(game, "victory", ctx)


func on_death(game, ctx: Dictionary) -> void:
	trigger(game, "death", ctx)


## Does nothing unless this is the right hook and the condition holds.
func trigger(game, which: String, ctx: Dictionary = {}) -> void:
	if which != hook or hook == "passive":
		return
	if not _holds(game, ctx):
		return
	if once:
		if game.history.has("relic_fired", {"relic": id, "turn": game.history.turn}):
			return
		game.history.add("relic_fired", {"relic": id})
	_do(game)
	if counter_mode == "down":
		counter -= 1
		if counter <= 0:
			game.break_relic(self)
			return
	if breaks:
		game.break_relic(self)


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
			return game.history.has_previous_turn() and not game.history.has(
					"domino_played", {"turn": game.history.prev(), "attack": true})
		"emptyLast":
			return game.history.has_previous_turn() and game.history.has(
					"turn_ended", {"turn": game.history.prev(), "hand_empty": true})
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
	var n := _amount()
	match act:
		"energy":
			game.gain_energy(n)
		"shield":
			game.gain_shield(n)
		"max_shield":
			CreatureCmd.gain_max_shield(game, game.pl, n)
		"draw":
			if hook == "play":
				game.relic_draw(n)
			else:
				# turn and battle hooks only count the extra cards: game.gd draws them with the others
				game.bat.extra_draw += n
		"fury":
			PowerCmd.apply(game, game.pl, "fury", n)
		"power":
			PowerCmd.apply(game, game.pl, "power", n)
		"boost":
			PowerCmd.apply(game, game.pl, "boost", n)
		"impair":
			PowerCmd.apply(game, game.foe, "fury", -n)
		"heal":
			CreatureCmd.heal(game, game.pl, n)
		"damage":
			DamageCmd.deal(game, game.pl, game.foe, n, false, "relic")
		"restack":
			game.restack_random(n)
		"max_hp":
			CreatureCmd.gain_max_hp(game, game.pl, n)
		"life":
			game.gain_life(n)
		"stalwart":
			PowerCmd.apply(game, game.pl, "stalwart", n)
		"regenerative":
			PowerCmd.apply(game, game.pl, "regenerative", n)
		"revive":
			game.gain_life(n)
			CreatureCmd.heal(game, game.pl, ceili(game.pl.max_hp / 2.0))
		_:
			push_error("unknown relic action: " + act)
