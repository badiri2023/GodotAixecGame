# CardDatabase.gd
class_name CardDatabase
extends Node

static func get_starter_deck() -> Array[Card]:
	var deck: Array[Card] = []
	
	# Añadimos copias de cada carta
	for i in 4:
		deck.append(_make_goblin())
		deck.append(_make_elf())
		deck.append(_make_fireball())
		deck.append(_make_lightning())
		deck.append(_make_troll())
	
	return deck

static func _make_goblin() -> Card:
	var c = Card.new()
	c.card_name = "Goblin Berserker"
	c.card_type = Card.CardType.CREATURE
	c.mana_cost = 1
	c.power = 2
	c.toughness = 1
	c.description = "Rápido y furioso."
	return c

static func _make_elf() -> Card:
	var c = Card.new()
	c.card_name = "Elfa del Bosque"
	c.card_type = Card.CardType.CREATURE
	c.mana_cost = 2
	c.power = 2
	c.toughness = 3
	c.description = "Guardiana del bosque."
	return c

static func _make_troll() -> Card:
	var c = Card.new()
	c.card_name = "Troll de Piedra"
	c.card_type = Card.CardType.CREATURE
	c.mana_cost = 4
	c.power = 4
	c.toughness = 5
	c.description = "Casi inamovible."
	return c

static func _make_fireball() -> Card:
	var c = Card.new()
	c.card_name = "Bola de Fuego"
	c.card_type = Card.CardType.SPELL
	c.mana_cost = 3
	c.damage = 4
	c.description = "Inflige 4 daños."
	return c

static func _make_lightning() -> Card:
	var c = Card.new()
	c.card_name = "Rayo"
	c.card_type = Card.CardType.INSTANT
	c.mana_cost = 1
	c.damage = 2
	c.description = "Inflige 2 daños. Instantáneo."
	return c
