# PlayerState.gd
class_name PlayerState
extends RefCounted

signal hp_changed(new_hp)
signal mana_changed(new_mana)

var player_name: String = ""
var hp: int = 20
var max_hp: int = 20
var mana: int = 0
var max_mana: int = 0

var deck: Array[Card] = []
var hand: Array[Card] = []
var field: Array[Card] = []   # criaturas en mesa
var graveyard: Array[Card] = []

func setup(name: String, starter_deck: Array[Card]) -> void:
	player_name = name
	deck = starter_deck.duplicate()
	_shuffle_deck()

func _shuffle_deck() -> void:
	deck.shuffle()

# Roba n cartas del mazo a la mano
func draw_cards(amount: int) -> void:
	for i in amount:
		if deck.is_empty():
			# Sin cartas: pierde 1 HP por carta que debería robar
			hp -= 1
			emit_signal("hp_changed", hp)
		else:
			hand.append(deck.pop_back())

# Aumenta el maná máximo en 1 (hasta 10) y lo recarga
func gain_mana_for_turn(turn_number: int) -> void:
	max_mana = min(turn_number, 10)
	mana = max_mana
	emit_signal("mana_changed", mana)

func spend_mana(amount: int) -> bool:
	if mana < amount:
		return false
	mana -= amount
	emit_signal("mana_changed", mana)
	return true

func receive_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	emit_signal("hp_changed", hp)

func is_dead() -> bool:
	return hp <= 0
