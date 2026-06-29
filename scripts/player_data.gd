extends Resource
class_name PlayerData

export var player_name: String = "Player"
export var max_hp: int = 70
export var current_hp: int = 70
export var lives: int = 3
export var starting_energy: int = 10
export var max_energy: int = 12
export var energy_per_turn: int = 12
export var max_hand_size: int = 12
export var draw_per_turn: int = 3
export var starting_draw: int = 6
export var inventory_size: int = 12
export var equipment_slots: int = 6

export var equipped_weapon: Resource = null
export(Array, Resource) var stack = []
export(Array, Resource) var equipped_items = []
export(Array, Resource) var inventory = []
