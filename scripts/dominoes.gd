extends RefCounted
## The domino catalogue: 112 dominoes plus Garbage (the last entry). The first 80 come from the web build.
## Ported from the web build (index.html). Edit the numbers here to rebalance.
## build() turns this table into DominoData objects (with Effect and Condition objects inside).
##
## Each domino: {"n": name, "r": rarity (c, u, r, g), "c": play condition id ("" = always playable), "p": pips, "fx": [effects]}
## Each effect: {"k": kind, "m": value mode, "a": a, "b": b, "t": hit count, "src": which pip number to use}
##
## PIPS ("p") are [left, right]. A pip is a number from 0 to 6 (STABLE: its value never changes, nearly every
## domino) or [lo, hi, "u"] (UNSTABLE: a value from lo to hi, rolled at the start of every battle and kept all
## battle) or [lo, hi, "v"] (VOLATILE, extremely rare: rolled again at the start of every turn until the domino is
## played). The pips are also what the domino costs in energy, so the stronger a domino is, the higher its pips.
## See pip_spec.gd. "src" picks the number an effect starts from: "sum" (the default: both pips added), "max"
## (the higher pip), "min" (the lower pip), "diff" (their difference) or "prod" (their product), see pip_metric.gd.
## "e": true makes a domino ephemeral. (pipdmg also has "p": which pip counts and "w": "board" or "hand")
## The effect size comes from the pip total s (0 to 12), so bigger pips mean bigger effects:
##   S = s*a + b      C = ceil(s/a) + b      F = floor(s/a) + b
##   K = b (constant) L = max(1, round(a*s + b))      no "m" = the effect has no number
##
## Effect kinds:
##   dmg hit(t hits)  shield  maxs (max shield)  draw  discR (discard random)  discP (discard of your choice)
##   tutor (find in stack)  power  boost  heal  rerollA (all in hand)  rerollP (one of your choice)
##   energy (lose energy)  endturn (playing it ends your turn)   [these two are mostly used by downgraded dominoes]
##   uptick (+1 to both pips of a domino in your hand, max 6, until the battle ends)
##   fury  impS (impair yourself)  impE (impair the enemy)  selfdmg (lose HP)  gen (add random dominoes to stack)  life
##   playedpips (damage = pips of every domino you played)  paylife (lose a life, pair with condition "lives2")  pipdmg (damage per pip of one number on the board / in hand)

const TY := [
	{"n": "Slash", "r": "c", "c": "", "p": [1, 4], "fx": [{"k": "dmg", "m": "S", "a": 1, "b": 2}]},
	{"n": "Twin Fang", "r": "c", "c": "", "p": [3, 1], "fx": [{"k": "hit", "m": "C", "a": 2, "b": 1, "t": 2}]},
	{"n": "Triple Thorn", "r": "u", "c": "", "p": [1, 2], "fx": [{"k": "hit", "m": "F", "a": 3, "b": 1, "t": 3}]},
	{"n": "Iron Guard", "r": "c", "c": "", "p": [3, 3], "fx": [{"k": "shield", "m": "S", "a": 1, "b": 3}]},
	{"n": "Fortify", "r": "u", "c": "", "p": [2, 0], "fx": [{"k": "maxs", "m": "F", "a": 4, "b": 1}, {"k": "shield", "m": "C", "a": 2, "b": 1}]},
	{"n": "Parry", "r": "c", "c": "", "p": [4, 2], "fx": [{"k": "shield", "m": "S", "a": 1, "b": 1}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Quick Study", "r": "c", "c": "", "p": [0, 2], "fx": [{"k": "draw", "m": "F", "a": 5, "b": 1}]},
	{"n": "Reckless Strike", "r": "c", "c": "", "p": [1, 4], "fx": [{"k": "dmg", "m": "S", "a": 1, "b": 4}, {"k": "discR", "m": "K", "a": 0, "b": 1}]},
	{"n": "Gambit", "r": "u", "c": "", "p": [2, 3], "fx": [{"k": "dmg", "m": "S", "a": 2, "b": 1}, {"k": "discP", "m": "K", "a": 0, "b": 1}]},
	{"n": "Scout", "r": "u", "c": "", "p": [2, 0], "fx": [{"k": "tutor", "m": "K", "a": 0, "b": 1}, {"k": "shield", "m": "F", "a": 3, "b": 1}]},
	{"n": "War Cry", "r": "u", "c": "", "p": [2, 3], "fx": [{"k": "power", "m": "F", "a": 4, "b": 1}]},
	{"n": "Sharpen", "r": "c", "c": "", "p": [1, 4], "fx": [{"k": "boost", "m": "S", "a": 1, "b": 2}]},
	{"n": "Mend", "r": "c", "c": "", "p": [2, 1], "fx": [{"k": "heal", "m": "S", "a": 1, "b": 2}]},
	{"n": "Chaos Dice", "r": "u", "c": "", "p": [2, 1], "fx": [{"k": "rerollA"}, {"k": "shield", "m": "C", "a": 2, "b": 4}]},
	{"n": "Loaded Dice", "r": "u", "c": "", "p": [1, 1], "fx": [{"k": "rerollP"}, {"k": "draw", "m": "K", "a": 0, "b": 2}]},
	{"n": "Second Wind", "r": "c", "c": "", "p": [2, 2], "fx": [{"k": "heal", "m": "C", "a": 2, "b": 1}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Battle Trance", "r": "u", "c": "", "p": [3, 1], "fx": [{"k": "dmg", "m": "C", "a": 2, "b": 1}, {"k": "power", "m": "K", "a": 0, "b": 1}]},
	{"n": "Shield Bash", "r": "c", "c": "", "p": [3, 3], "fx": [{"k": "dmg", "m": "C", "a": 2, "b": 2}, {"k": "shield", "m": "C", "a": 2, "b": 2}]},
	{"n": "Precision", "r": "u", "c": "", "p": [3, 1], "fx": [{"k": "boost", "m": "C", "a": 2, "b": 3}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Lifesteal", "r": "u", "c": "", "p": [2, 1], "fx": [{"k": "dmg", "m": "C", "a": 2, "b": 2}, {"k": "heal", "m": "F", "a": 3, "b": 1}]},
	{"n": "Rage Up", "r": "c", "c": "", "p": [2, 1], "fx": [{"k": "fury", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Sting", "r": "c", "c": "", "p": [1, 2], "fx": [{"k": "impE", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Blood Ward", "r": "c", "c": "", "p": [1, 5], "fx": [{"k": "shield", "m": "L", "a": 1.2, "b": 4}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Blood Rage", "r": "c", "c": "", "p": [2, 2], "fx": [{"k": "fury", "m": "L", "a": 0.6, "b": 2}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Cheap Shot", "r": "c", "c": "first", "p": [2, 4], "fx": [{"k": "dmg", "m": "L", "a": 1.2, "b": 4}]},
	{"n": "Opening Guard", "r": "c", "c": "first", "p": [3, 3], "fx": [{"k": "shield", "m": "L", "a": 1.4, "b": 4}]},
	{"n": "Desperate Swing", "r": "c", "c": "lowHp", "p": [4, 1], "fx": [{"k": "dmg", "m": "L", "a": 1.25, "b": 2}]},
	{"n": "Second Skin", "r": "c", "c": "noShield", "p": [4, 2], "fx": [{"k": "shield", "m": "L", "a": 1.4, "b": 5}]},
	{"n": "Light Hands", "r": "c", "c": "handLe3", "p": [3, 1], "fx": [{"k": "draw", "m": "L", "a": 0, "b": 3}]},
	{"n": "Clean Hands", "r": "c", "c": "noSix", "p": [1, 4], "fx": [{"k": "dmg", "m": "L", "a": 1, "b": 3}]},
	{"n": "Full Grip", "r": "c", "c": "hand6", "p": [5, 1], "fx": [{"k": "dmg", "m": "L", "a": 0.75, "b": 2}, {"k": "shield", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Steady Guard", "r": "c", "c": "noAtk", "p": [2, 4], "fx": [{"k": "shield", "m": "L", "a": 1, "b": 3}, {"k": "heal", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Flawless Blow", "r": "c", "c": "noHpLost", "p": [5, 1], "fx": [{"k": "dmg", "m": "L", "a": 1.25, "b": 3}]},
	{"n": "Taunt", "r": "c", "c": "", "p": [2, 4], "fx": [{"k": "impE", "m": "L", "a": 0.5, "b": 1}, {"k": "shield", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Spite", "r": "c", "c": "", "p": [1, 5], "fx": [{"k": "dmg", "m": "L", "a": 0.5, "b": 1}, {"k": "impE", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Warm Up", "r": "c", "c": "", "p": [1, 5], "fx": [{"k": "fury", "m": "L", "a": 0.4, "b": 1}, {"k": "draw", "m": "L", "a": 0, "b": 1}]},
	{"n": "Reckless Blow", "r": "c", "c": "", "p": [2, 0], "fx": [{"k": "dmg", "m": "L", "a": 1.25, "b": 5}, {"k": "impS", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Quick Patch", "r": "c", "c": "lowHp", "p": [4, 1], "fx": [{"k": "heal", "m": "L", "a": 1.2, "b": 4}]},
	{"n": "Rummage", "r": "c", "c": "", "p": [3, 1], "fx": [{"k": "draw", "m": "L", "a": 0, "b": 3}, {"k": "discP", "m": "L", "a": 0, "b": 1}]},
	{"n": "Pile Driver", "r": "c", "c": "", "p": [1, 4], "fx": [{"k": "hit", "m": "L", "a": 0.5, "b": 1, "t": 2}]},
	{"n": "Reset", "r": "c", "c": "", "p": [2, 1], "fx": [{"k": "rerollA"}, {"k": "draw", "m": "L", "a": 0, "b": 2}]},
	{"n": "Fury Guard", "r": "c", "c": "", "p": [3, 2], "fx": [{"k": "shield", "m": "L", "a": 0.5, "b": 1}, {"k": "fury", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Sharp Eyes", "r": "c", "c": "first", "p": [2, 1], "fx": [{"k": "boost", "m": "L", "a": 1, "b": 2}]},
	{"n": "Jab", "r": "c", "c": "", "p": [3, 3], "fx": [{"k": "dmg", "m": "L", "a": 0.9, "b": 2}, {"k": "draw", "m": "L", "a": 0, "b": 1}]},
	{"n": "Berserker", "r": "u", "c": "", "p": [3, 5], "fx": [{"k": "fury", "m": "L", "a": 0.5, "b": 2}, {"k": "dmg", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Crippling Blow", "r": "u", "c": "", "p": [4, 3], "fx": [{"k": "dmg", "m": "L", "a": 0.75, "b": 2}, {"k": "impE", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Hex", "r": "u", "c": "", "p": [4, 4], "fx": [{"k": "impE", "m": "L", "a": 1, "b": 2}]},
	{"n": "Battle Lust", "r": "u", "c": "", "p": [6, 2], "fx": [{"k": "fury", "m": "L", "a": 0.8, "b": 3}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Iron Resolve", "r": "u", "c": "", "p": [5, 3], "fx": [{"k": "shield", "m": "L", "a": 1, "b": 4}, {"k": "fury", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Hard Bargain", "r": "u", "c": "", "p": [2, 1], "fx": [{"k": "dmg", "m": "L", "a": 1.8, "b": 5}, {"k": "impS", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Veteran’s Edge", "r": "u", "c": "played9", "p": [4, 3], "fx": [{"k": "dmg", "m": "L", "a": 1.7, "b": 5}]},
	{"n": "Last Stand", "r": "u", "c": "lowHp", "p": [1, 6], "fx": [{"k": "dmg", "m": "L", "a": 2.2, "b": 6}]},
	{"n": "Bare Knuckle", "r": "u", "c": "handLe3", "p": [6, 2], "fx": [{"k": "dmg", "m": "L", "a": 2, "b": 5}]},
	{"n": "Meditate", "r": "u", "c": "noAtk", "p": [1, 2], "fx": [{"k": "heal", "m": "L", "a": 0.8, "b": 3}, {"k": "draw", "m": "L", "a": 0, "b": 1}]},
	{"n": "Siphon Fury", "r": "u", "c": "", "p": [3, 3], "fx": [{"k": "fury", "m": "L", "a": 0.9, "b": 2}, {"k": "heal", "m": "L", "a": 0.4, "b": 1}]},
	{"n": "Whirlwind", "r": "u", "c": "noShield", "p": [4, 1], "fx": [{"k": "hit", "m": "L", "a": 0.5, "b": 1, "t": 3}]},
	{"n": "Spare Parts", "r": "u", "c": "", "p": [2, 1], "fx": [{"k": "gen", "m": "L", "a": 0, "b": 1}, {"k": "shield", "m": "L", "a": 1, "b": 3}]},
	{"n": "Calm Mind", "r": "u", "c": "handLe3", "p": [2, 2], "fx": [{"k": "draw", "m": "L", "a": 0, "b": 5}]},
	{"n": "Overclock", "r": "u", "c": "", "p": [5, 1], "fx": [{"k": "power", "m": "L", "a": 0.5, "b": 1}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Mulligan", "r": "u", "c": "hand6", "p": [1, 2], "fx": [{"k": "rerollA"}, {"k": "draw", "m": "L", "a": 0, "b": 3}]},
	{"n": "Shatter", "r": "u", "c": "enShield", "p": [5, 3], "fx": [{"k": "dmg", "m": "L", "a": 1.5, "b": 4}, {"k": "impE", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Patient Strike", "r": "u", "c": "first", "p": [4, 4], "fx": [{"k": "dmg", "m": "L", "a": 2, "b": 4}]},
	{"n": "Second Chance", "r": "r", "c": "", "p": [6, 2], "fx": [{"k": "life", "m": "L", "a": 0, "b": 2}, {"k": "gen", "m": "L", "a": 0, "b": 2}]},
	{"n": "Rampage", "r": "r", "c": "", "p": [5, 4], "fx": [{"k": "hit", "m": "L", "a": 0.6, "b": 2, "t": 3}, {"k": "fury", "m": "L", "a": 0.6, "b": 2}]},
	{"n": "Annihilate", "r": "r", "c": "", "p": [4, 5], "fx": [{"k": "dmg", "m": "L", "a": 1.5, "b": 4}, {"k": "impE", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Bulwark of Ages", "r": "r", "c": "", "p": [6, 1], "fx": [{"k": "shield", "m": "L", "a": 1.5, "b": 5}, {"k": "maxs", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Phoenix Draught", "r": "r", "c": "", "p": [5, 4], "fx": [{"k": "heal", "m": "L", "a": 2, "b": 6}, {"k": "draw", "m": "L", "a": 0, "b": 2}, {"k": "shield", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Blood Frenzy", "r": "r", "c": "", "p": [1, 6], "fx": [{"k": "fury", "m": "L", "a": 1, "b": 3}, {"k": "dmg", "m": "L", "a": 1, "b": 2}, {"k": "selfdmg", "m": "L", "a": 0, "b": 3}]},
	{"n": "Time Warp", "r": "r", "c": "", "p": [3, 2], "fx": [{"k": "draw", "m": "L", "a": 0, "b": 3}, {"k": "boost", "m": "L", "a": 1, "b": 3}]},
	{"n": "Warlord", "r": "r", "c": "", "p": [3, 4], "fx": [{"k": "power", "m": "L", "a": 0.25, "b": 1}, {"k": "fury", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Grand Design", "r": "r", "c": "", "p": [2, 2], "fx": [{"k": "tutor"}, {"k": "tutor"}, {"k": "shield", "m": "L", "a": 1, "b": 3}]},
	{"n": "Soul Rend", "r": "r", "c": "", "p": [3, 4], "fx": [{"k": "dmg", "m": "L", "a": 1, "b": 4}, {"k": "impE", "m": "L", "a": 0.5, "b": 1}, {"k": "heal", "m": "L", "a": 0.25, "b": 1}]},
	{"n": "Fortress", "r": "r", "c": "noShield", "p": [4, 1], "fx": [{"k": "shield", "m": "L", "a": 2.5, "b": 8}]},
	{"n": "Pure Heart", "r": "r", "c": "noHpLost", "p": [5, 1], "fx": [{"k": "dmg", "m": "L", "a": 3, "b": 7}]},
	{"n": "Fortune’s Wheel", "r": "r", "c": "", "p": [1, 5], "fx": [{"k": "rerollA"}, {"k": "draw", "m": "L", "a": 0, "b": 3}, {"k": "shield", "m": "L", "a": 1, "b": 3}]},
	{"n": "Hundred Cuts", "r": "r", "c": "noSix", "p": [4, 1], "fx": [{"k": "hit", "m": "L", "a": 1, "b": 2, "t": 3}]},
	{"n": "Dominion", "r": "r", "c": "hand6", "p": [5, 3], "fx": [{"k": "dmg", "m": "L", "a": 1.5, "b": 5}, {"k": "shield", "m": "L", "a": 1.25, "b": 3}]},
	{"n": "Last Gasp", "r": "r", "c": "lowHp", "p": [4, 2], "fx": [{"k": "dmg", "m": "L", "a": 3.5, "b": 8}, {"k": "selfdmg", "m": "L", "a": 0, "b": 4}]},
	{"n": "Overwhelm", "r": "r", "c": "", "p": [3, 4], "fx": [{"k": "impE", "m": "L", "a": 1, "b": 2}, {"k": "boost", "m": "L", "a": 0.75, "b": 3}]},
	{"n": "Ascension", "r": "r", "c": "", "p": [3, 3], "fx": [{"k": "fury", "m": "L", "a": 0.5, "b": 2}, {"k": "power", "m": "L", "a": 0.25, "b": 0}, {"k": "maxs", "m": "L", "a": 0, "b": 0}]},
	# ---- elements: damage for every pip of one number (1 light, 2 earth, 3 water, 4 fire, 5 lightning, 6 darkness)
	{"n": "Sunburst", "r": "c", "c": "", "p": [1, 3], "fx": [{"k": "pipdmg", "p": 1, "w": "board", "m": "K", "a": 0, "b": 2}]},
	{"n": "Landslide", "r": "c", "c": "", "p": [2, 3], "fx": [{"k": "pipdmg", "p": 2, "w": "board", "m": "K", "a": 0, "b": 2}]},
	{"n": "Tidal Crash", "r": "u", "c": "", "p": [3, 3], "fx": [{"k": "pipdmg", "p": 3, "w": "board", "m": "K", "a": 0, "b": 3}]},
	{"n": "Inferno", "r": "u", "c": "", "p": [4, 2], "fx": [{"k": "pipdmg", "p": 4, "w": "board", "m": "K", "a": 0, "b": 3}]},
	{"n": "Fireball", "r": "r", "c": "", "p": [4, 4], "fx": [{"k": "pipdmg", "p": 4, "w": "board", "m": "K", "a": 0, "b": 6}]},
	{"n": "Thunderclap", "r": "u", "c": "", "p": [5, 1], "fx": [{"k": "pipdmg", "p": 5, "w": "hand", "m": "K", "a": 0, "b": 4}]},
	{"n": "Eclipse", "r": "u", "c": "", "p": [6, 1], "fx": [{"k": "pipdmg", "p": 6, "w": "hand", "m": "K", "a": 0, "b": 4}]},
	# ---- paid for with a life (cannot be played when you have only 1 life)
	{"n": "Blood Pact", "r": "u", "c": "lives2", "p": [3, 5], "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "dmg", "m": "L", "a": 2.4, "b": 7}]},
	{"n": "Soul Tithe", "r": "u", "c": "lives2", "p": [2, 2], "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "draw", "m": "L", "a": 0.25, "b": 3}]},
	{"n": "Hex of Ruin", "r": "u", "c": "lives2", "p": [6, 2], "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "impE", "m": "L", "a": 1.75, "b": 6}]},
	{"n": "Crimson Ritual", "r": "r", "c": "lives2", "p": [4, 3], "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "fury", "m": "L", "a": 1.2, "b": 5}, {"k": "power", "m": "L", "a": 0.3, "b": 1}]},
	{"n": "Sacrificial Blade", "r": "r", "c": "lives2", "p": [6, 2], "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "hit", "m": "L", "a": 1.2, "b": 3, "t": 3}]},
	# ---- ephemeral: stronger than the normal kind, but discarded at the end of the turn if you do not play them
	{"n": "Lunge", "r": "c", "c": "", "e": true, "p": [5, 1], "fx": [{"k": "dmg", "m": "L", "a": 1.25, "b": 3}]},
	{"n": "Flash Guard", "r": "c", "c": "", "e": true, "p": [3, 3], "fx": [{"k": "shield", "m": "L", "a": 1.6, "b": 5}]},
	{"n": "Focus", "r": "u", "c": "", "e": true, "p": [5, 3], "fx": [{"k": "fury", "m": "L", "a": 1.0, "b": 3}]},
	{"n": "Quick Draw", "r": "u", "c": "", "e": true, "p": [3, 3], "fx": [{"k": "draw", "m": "L", "a": 0.5, "b": 5}]},
	{"n": "Overpower", "r": "r", "c": "", "e": true, "p": [3, 2], "fx": [{"k": "dmg", "m": "L", "a": 3.0, "b": 9}]},
	# ---- weapon dominoes (rarity w): only a weapon adds them, they are never offered as rewards
	{"n": "Quick Strike", "r": "w", "c": "first", "e": true, "p": [1, 1], "fx": [{"k": "dmg", "m": "L", "a": 2.5, "b": 3}]},
	{"n": "Heavy Blade", "r": "w", "c": "", "p": [4, 3], "fx": [{"k": "dmg", "m": "L", "a": 2, "b": 5}]},
	{"n": "En Garde", "r": "w", "c": "", "e": true, "p": [2, 2], "fx": [{"k": "shield", "m": "L", "a": 1.0, "b": 4}, {"k": "dmg", "m": "L", "a": 1.2, "b": 3}]},
	{"n": "Rip and Shred", "r": "w", "c": "", "p": [3, 2], "fx": [{"k": "playedpips", "m": "K", "a": 0, "b": 1}]},
	{"n": "Cutting Edge", "r": "w", "c": "", "p": [2, 2], "fx": [{"k": "hit", "m": "K", "a": 0, "b": 4, "t": 3}]},
	# ---- unstable pips: a range, rolled at the start of each battle and kept for the whole battle
	{"n": "Uptick", "r": "c", "c": "", "p": [1, 1], "fx": [{"k": "uptick"}]},
	{"n": "Wild Swing", "r": "c", "c": "", "p": [[1, 5, "u"], [1, 3, "u"]], "fx": [{"k": "dmg", "src": "max", "m": "S", "a": 2, "b": 1}]},
	{"n": "Lucky Guard", "r": "c", "c": "", "p": [[2, 6, "u"], [1, 4, "u"]], "fx": [{"k": "shield", "src": "min", "m": "S", "a": 3, "b": 2}]},
	{"n": "Skew Strike", "r": "u", "c": "", "p": [[0, 6, "u"], [0, 6, "u"]], "fx": [{"k": "dmg", "src": "diff", "m": "S", "a": 3, "b": 3}]},
	{"n": "Rolling Thunder", "r": "u", "c": "", "p": [[2, 5, "u"], [2, 5, "u"]], "fx": [{"k": "hit", "src": "min", "m": "S", "a": 2, "b": 2, "t": 2}]},
	{"n": "Chaos Force", "r": "r", "c": "", "p": [[1, 6, "u"], 6], "fx": [{"k": "power", "src": "min", "m": "S", "a": 1, "b": 0}, {"k": "fury", "src": "min", "m": "S", "a": 1, "b": 0}]},
	# ---- volatile pips (extremely rare): rolled again at the start of every turn, even in the stack and the discard pile
	{"n": "Risky Manoeuvre", "r": "r", "c": "", "p": [[3, 6, "v"], [3, 6, "v"]], "fx": [{"k": "dmg", "src": "prod", "m": "S", "a": 1, "b": 0}]},
	{"n": "Flakey Shield", "r": "r", "c": "", "p": [[1, 6, "v"], [1, 6, "v"]], "fx": [{"k": "shield", "src": "diff", "m": "S", "a": 1, "b": 4}, {"k": "maxs", "src": "min", "m": "S", "a": 1, "b": 1}, {"k": "draw", "m": "K", "a": 0, "b": 2}]},
	{"n": "Product Smash", "r": "r", "c": "", "p": [[4, 6, "v"], [3, 6, "v"]], "fx": [{"k": "dmg", "src": "prod", "m": "S", "a": 1, "b": 0}]},
	{"n": "Fickle Fury", "r": "r", "c": "", "p": [[1, 5, "v"], [1, 5, "v"]], "fx": [{"k": "fury", "src": "max", "m": "S", "a": 1, "b": 2}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Garbage", "r": "g", "c": "never", "p": [0, 0], "fx": []},
]

## Index of Garbage: always the last row of TY.
const GARBAGE := 112

const DominoData = preload("res://scripts/domino_data.gd")
const PipSpec = preload("res://scripts/pip_spec.gd")
const EffectFactory = preload("res://scripts/effects/effect_factory.gd")
const ConditionFactory = preload("res://scripts/conditions/condition_factory.gd")


## Build the catalogue: one DominoData per row of TY (the Garbage entry is the last).
static func build() -> Array:
	var out := []
	for i in TY.size():
		out.append(make_data(i, TY[i]))
	return out


## One DominoData from a row. upgrades.gd uses it for the other levels of a domino (the row is a changed copy).
static func make_data(i: int, row: Dictionary):
	var d = DominoData.new()
	d.id = i
	d.row = row
	d.title = row.n
	d.rarity = row.r
	d.condition = ConditionFactory.make(row.c)
	d.ephemeral = row.get("e", false)
	var p: Array = row.get("p", [0, 0])
	d.pips = [PipSpec.parse(p[0]), PipSpec.parse(p[1])]
	for e in row.fx:
		d.effects.append(EffectFactory.make(e))
	return d


## A random kind of domino (never Garbage or a weapon domino): 60% common, 30% uncommon, 10% rare.
## Pass the game's RandomNumberGenerator to make it repeatable from the seed.
## exclude: kinds (ids) not to pick, so a shop or a reward screen does not offer the same domino twice.
static func rand_type(rng: RandomNumberGenerator = null, exclude: Array = []) -> int:
	var x: float = rng.randf() if rng != null else randf()
	var r := "c" if x < 0.6 else ("u" if x < 0.9 else "r")
	return rand_type_of(r, rng, exclude)


## A random kind of this rarity.
static func rand_type_of(r: String, rng: RandomNumberGenerator = null, exclude: Array = []) -> int:
	var pool := []
	for i in TY.size():
		if TY[i].r == r and not exclude.has(i):
			pool.append(i)
	if pool.is_empty():       # everything of this rarity is excluded: allow repeats rather than fail
		for i in TY.size():
			if TY[i].r == r:
				pool.append(i)
	var k: int = rng.randi() if rng != null else randi()
	return pool[k % pool.size()]


## Position of a kind in the catalogue by its name (-1 if there is none).
static func index_of(title: String) -> int:
	for i in TY.size():
		if TY[i].n == title:
			return i
	return -1
