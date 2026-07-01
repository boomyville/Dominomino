# game_state.gd (Autoload Singleton)
extends Node

signal player_energy_changed(new_energy)
signal player_chain_changed(new_chain)
signal player_hp_changed(new_hp)
signal player_lives_changed(new_lives)

var player_current_hp: int = 0
var player_max_hp: int = 0
var player_lives: int = 0
var player_max_energy: int = 0
var player_energy_per_turn: int = 0
var player_max_hand_size: int = 0
var player_draw_per_turn: int = 0
var player_starting_draw: int = 0
var current_player_energy: int = 10 setget set_player_energy
var player_domino_chain: int = 0 setget set_player_chain

func load_player(data: PlayerData) -> void:
	player_current_hp = data.current_hp
	player_max_hp = data.max_hp
	player_lives = data.lives
	player_max_energy = data.max_energy
	player_energy_per_turn = data.energy_per_turn
	player_max_hand_size = data.max_hand_size
	player_draw_per_turn = data.draw_per_turn
	player_starting_draw = data.starting_draw
	set_starting_player_energy(data.starting_energy)

func set_player_energy(value: int) -> void:
	current_player_energy = int(max(0, value))
	emit_signal("player_energy_changed", current_player_energy)

func modify_player_energy(amount: int) -> void:
	current_player_energy = int(clamp(current_player_energy + amount, 0, player_max_energy))
	emit_signal("player_energy_changed", current_player_energy)

func set_player_chain(value: int) -> void:
	player_domino_chain = int(max(0, value))
	emit_signal("player_chain_changed", player_domino_chain)

func set_starting_player_energy(amount: int) -> void:
	self.current_player_energy = amount
	print("Starting player energy set to: ", current_player_energy)
	emit_signal("player_energy_changed", current_player_energy)


func restore_energy_for_turn() -> void:
	self.current_player_energy = int(clamp(current_player_energy + player_energy_per_turn, 0, player_max_energy))
	emit_signal("player_energy_changed", current_player_energy)

func spend_player_energy(amount: int) -> void:
	self.current_player_energy = max(0, current_player_energy - amount)
	print("Player energy spent: ", amount)
	print("Remaining player energy: ", current_player_energy)
	emit_signal("player_energy_changed", current_player_energy)

func increment_chain() -> void:
	self.player_domino_chain = player_domino_chain + 1
	emit_signal("player_chain_changed", player_domino_chain)

func reset_chain() -> void:
	self.player_domino_chain = 0
	emit_signal("player_chain_changed", player_domino_chain)

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

func take_damage(amount: int) -> void:
	player_current_hp = int(clamp(player_current_hp - amount, 0, player_max_hp))
	emit_signal("player_hp_changed", player_current_hp)
	if player_current_hp <= 0:
		pass # Should be game over trigger

func heal(amount: int) -> void:
	player_current_hp = int(clamp(player_current_hp + amount, 0, player_max_hp))
	emit_signal("player_hp_changed", player_current_hp)

func lose_life(amount: int) -> void:
	player_lives = int(max(0, player_lives - amount))
	emit_signal("player_lives_changed", player_lives)
	if player_lives <= 0:
		pass # Should be game over trigger
