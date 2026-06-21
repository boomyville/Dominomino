# game_state.gd (Autoload Singleton)
extends Node

signal player_energy_changed(new_energy)
signal player_combo_changed(new_combo)

var current_player_energy: int = 10 setget set_player_energy
var player_domino_combo: int = 0 setget set_player_combo

func set_player_energy(value: int) -> void:
	current_player_energy = int(max(0, value))
	emit_signal("player_energy_changed", current_player_energy)

func set_player_combo(value: int) -> void:
	player_domino_combo = int(max(0, value))
	emit_signal("player_combo_changed", player_domino_combo)

func set_starting_player_energy(amount: int) -> void:
	self.current_player_energy = amount
	emit_signal("player_energy_changed", current_player_energy)

func spend_player_energy(amount: int) -> void:
	self.current_player_energy = max(0, current_player_energy - amount)
	emit_signal("player_energy_changed", current_player_energy)

func increment_combo() -> void:
	self.player_domino_combo = player_domino_combo + 1
	emit_signal("player_combo_changed", player_domino_combo)

func reset_combo() -> void:
	self.player_domino_combo = 0
	emit_signal("player_combo_changed", player_domino_combo)

# Base cost: sum of non-special pip values (unchanged, used as fallback)
func calculate_domino_cost(left_pip: int, right_pip: int) -> int:
	var total_cost: int = 0
	if left_pip >= 0:
		total_cost += left_pip
	if right_pip >= 0:
		total_cost += right_pip
	return total_cost

# Cost after subtracting matched pip values from adjacency (floored at 0).
# matched_pip_reduction = sum of the candidate's pip values on sides that matched a neighbour.
# e.g. [3,6] placed so the 3 matches: reduction=3, cost = (3+6)-3 = 6
func calculate_domino_cost_discounted(left_pip: int, right_pip: int, matched_pip_reduction: int) -> int:
	var base = calculate_domino_cost(left_pip, right_pip)
	return int(max(0, base - matched_pip_reduction))