# enemy_state.gd (Autoload Singleton)
extends Node

signal enemy_energy_changed(new_energy)
signal enemy_chain_changed(new_chain)
signal enemy_hp_changed(new_hp)
signal enemy_lives_changed(new_lives)

var enemy_current_hp: int = 0
var enemy_max_hp: int = 0
var enemy_lives: int = 0
var enemy_max_energy: int = 0
var enemy_energy_per_turn: int = 0
var enemy_max_hand_size: int = 0
var enemy_draw_per_turn: int = 0
var enemy_starting_draw: int = 0
var current_enemy_energy: int = 10 setget set_enemy_energy
var enemy_domino_chain: int = 0 setget set_enemy_chain

func load_enemy(data: EnemyData) -> void:
	enemy_current_hp = data.current_hp
	enemy_max_hp = data.max_hp
	enemy_lives = data.lives
	enemy_max_energy = data.max_energy
	enemy_energy_per_turn = data.energy_per_turn
	enemy_max_hand_size = data.max_hand_size
	enemy_draw_per_turn = data.draw_per_turn
	enemy_starting_draw = data.starting_draw
	set_starting_enemy_energy(data.starting_energy)

func set_enemy_energy(value: int) -> void:
	current_enemy_energy = int(max(0, value))
	emit_signal("enemy_energy_changed", current_enemy_energy)

func modify_enemy_energy(amount: int) -> void:
	current_enemy_energy = int(clamp(current_enemy_energy + amount, 0, enemy_max_energy))
	emit_signal("enemy_energy_changed", current_enemy_energy)

func set_enemy_chain(value: int) -> void:
	enemy_domino_chain = int(max(0, value))
	emit_signal("enemy_chain_changed", enemy_domino_chain)

func set_starting_enemy_energy(amount: int) -> void:
	self.current_enemy_energy = amount
	print("Starting enemy energy set to: ", current_enemy_energy)
	emit_signal("enemy_energy_changed", current_enemy_energy)


func restore_energy_for_turn() -> void:
	self.current_enemy_energy = int(clamp(current_enemy_energy + enemy_energy_per_turn, 0, enemy_max_energy))
	emit_signal("enemy_energy_changed", current_enemy_energy)

func spend_enemy_energy(amount: int) -> void:
	self.current_enemy_energy = max(0, current_enemy_energy - amount)
	print("Enemy energy spent: ", amount)
	print("Remaining enemy energy: ", current_enemy_energy)
	emit_signal("enemy_energy_changed", current_enemy_energy)

func increment_chain() -> void:
	self.enemy_domino_chain = enemy_domino_chain + 1
	emit_signal("enemy_chain_changed", enemy_domino_chain)

func reset_chain() -> void:
	self.enemy_domino_chain = 0
	emit_signal("enemy_chain_changed", enemy_domino_chain)

# calculate_domino_cost and calculate_domino_cost_discounted can be derived from GameState
# We can call GameState.calculate_domino_cost()

func take_damage(amount: int) -> void:
	enemy_current_hp = int(clamp(enemy_current_hp - amount, 0, enemy_max_hp))
	emit_signal("enemy_hp_changed", enemy_current_hp)
	if enemy_current_hp <= 0:
		pass # Should be enemy death trigger

func heal(amount: int) -> void:
	enemy_current_hp = int(clamp(enemy_current_hp + amount, 0, enemy_max_hp))
	emit_signal("enemy_hp_changed", enemy_current_hp)

func lose_life(amount: int) -> void:
	enemy_lives = int(max(0, enemy_lives - amount))
	emit_signal("enemy_lives_changed", enemy_lives)
	if enemy_lives <= 0:
		pass # Should be enemy death trigger
