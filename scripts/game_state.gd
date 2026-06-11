# game_state.gd (Autoload Singleton)
extends Node

signal player_energy_changed(new_energy)

var current_player_energy: int = 10 setget set_player_energy

func set_player_energy(value: int) -> void:
	current_player_energy = int(max(0, value))
	emit_signal("player_energy_changed", current_player_energy)

func set_starting_player_energy(amount: int) -> void:
    self.current_player_energy = amount
    emit_signal("player_energy_changed", current_player_energy)

func spend_player_energy(amount: int) -> void:
    self.current_player_energy = max(0, current_player_energy - amount)
    emit_signal("player_energy_changed", current_player_energy)

# Calculates resource cost, treating wild (-1) and unplayable (-2) indicators as 0 cost
func calculate_domino_cost(left_pip: int, right_pip: int) -> int:
	var total_cost: int = 0
	if left_pip >= 0:
		total_cost += left_pip
	if right_pip >= 0:
		total_cost += right_pip
	return total_cost