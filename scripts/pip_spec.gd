extends RefCounted
## What one half of a domino can show (its pip_stability).
##   stable    a fixed value (almost every domino): lo == hi
##   unstable  a range lo-hi (e.g. 1-6). Rolled once at the start of each battle and then kept all battle.
##   volatile  a range lo-hi, extremely rare. Rolled at the start of the battle AND again at the start of every
##             turn, even while the domino is in the stack or the discard pile. Once it is played on the board the
##             pips on the board never change.
## A domino keeps one PipSpec for each half: that is its core definition. The pips it shows right now (which
## can be changed in a battle by a reroll or an Uptick) are Domino.a and Domino.b.
## In the catalogue (dominoes.gd) a half is written as a number (stable) or [lo, hi, "u"] / [lo, hi, "v"].

const STABLE := "stable"
const UNSTABLE := "unstable"
const VOLATILE := "volatile"
const MAX_PIP := 6
const SELF_PATH := "res://scripts/pip_spec.gd"

var lo := 0
var hi := 0
var stability := STABLE


func _init(p_lo: int = 0, p_hi: int = -1, p_stability: String = STABLE) -> void:
	lo = clampi(p_lo, 0, MAX_PIP)
	hi = clampi(p_hi if p_hi >= 0 else p_lo, lo, MAX_PIP)
	stability = p_stability if lo != hi else STABLE


## A number is stable. [lo, hi, "u"] is unstable and [lo, hi, "v"] is volatile.
static func parse(raw):
	var script = load(SELF_PATH)
	if raw is Array:
		return script.new(int(raw[0]), int(raw[1]), VOLATILE if raw.size() > 2 and raw[2] == "v" else UNSTABLE)
	return script.new(int(raw))


static func stable(value: int):
	return load(SELF_PATH).new(value)


## Does this half have a range (unstable or volatile) rather than a fixed value?
func ranged() -> bool:
	return stability != STABLE


func is_volatile() -> bool:
	return stability == VOLATILE


## A random value from the range (the fixed value when stable).
func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(lo, hi)


func contains(v: int) -> bool:
	return v >= lo and v <= hi


## "4" for a stable half, "1-6" for a range.
func text() -> String:
	return str(lo) if not ranged() else "%d-%d" % [lo, hi]


func copy():
	return load(SELF_PATH).new(lo, hi, stability)


## Move the whole range up or down (a permanent change from an event): pips stay between 0 and 6.
func shift(delta: int) -> void:
	var width := hi - lo
	lo = clampi(lo + delta, 0, MAX_PIP - width)
	hi = lo + width
