# Card.gd
class_name Card
extends Resource

enum CardType { CREATURE, SPELL, INSTANT }

@export var card_name: String = ""
@export var card_type: CardType = CardType.CREATURE
@export var mana_cost: int = 0
@export var description: String = ""

# Solo criaturas
@export var power: int = 0      # Ataque
@export var toughness: int = 0  # Vida

# Solo hechizos/instants
@export var damage: int = 0     # Daño directo que hace
