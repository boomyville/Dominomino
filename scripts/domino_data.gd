# domino_data.gd
extends Resource
class_name DominoData

enum RarityType { STARTER, COMMON, UNCOMMON, RARE, LEGENDARY, BLIGHT, STATUS }
enum ElementalType { NONE, FIRE, TERRAIN, LIGHTNING, FROST }
enum OriginType { INSTRINSIC, WEAPON, EQUIPMENT, OTHER }

export(int) var id: int = 0
export(String) var domino_name: String = "Unknown Domino"
export(String, MULTILINE) var description: String = "" # MULTILINE gives you a nice text box
export(RarityType) var rarity = RarityType.COMMON
export(ElementalType) var elemental = ElementalType.NONE
export(OriginType) var origin = OriginType.INSTRINSIC

export(int, -2, 6) var base_left_pip: int = 0
export(int, -2, 6) var base_right_pip: int = 0

# Domino effects
# [ {"type": "damage", "value": 6}, {"type": "shield", "value": 4, "level": 1} ]
export(Array, Dictionary) var on_play_effects = []
export(Array, Dictionary) var on_discard_effects = [] 
export(Dictionary) var play_conditions = {}
