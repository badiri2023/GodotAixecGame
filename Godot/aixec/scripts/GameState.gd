# GameState.gd
class_name GameState
extends Node

signal turn_changed(is_player_turn)
signal game_over(player_won)
signal log_message(text)

enum Phase { DRAW, MAIN, COMBAT, END }

var player: PlayerState
var bot: PlayerState
var is_player_turn: bool = true
var turn_number: int = 1
var current_phase: Phase = Phase.DRAW

# Criaturas que atacaron este turno (no pueden atacar de nuevo)
var attacked_this_turn: Array[Card] = []
# Criaturas recién invocadas (no pueden atacar el mismo turno - "summoning sickness")
var summoned_this_turn: Array[Card] = []

func setup() -> void:
	player = PlayerState.new()
	bot    = PlayerState.new()
	
	player.setup("Jugador", CardDatabase.get_starter_deck())
	bot.setup("Bot", CardDatabase.get_starter_deck())
	
	# Mano inicial: 5 cartas cada uno
	player.draw_cards(5)
	bot.draw_cards(5)
	
	emit_signal("log_message", "¡Partida iniciada! Turno del Jugador.")
	_start_turn()

func _start_turn() -> void:
	attacked_this_turn.clear()
	summoned_this_turn.clear()
	current_phase = Phase.DRAW
	
	var active = _active_player()
	active.gain_mana_for_turn(turn_number)
	active.draw_cards(1)
	
	current_phase = Phase.MAIN
	emit_signal("turn_changed", is_player_turn)
	
	var who = "Jugador" if is_player_turn else "Bot"
	emit_signal("log_message", "--- Turno %d: %s | Maná: %d ---" % [turn_number, who, active.mana])

# El jugador intenta jugar una carta de su mano
func play_card(card: Card) -> bool:
	if not is_player_turn:
		emit_signal("log_message", "No es tu turno.")
		return false
	
	if not player.spend_mana(card.mana_cost):
		emit_signal("log_message", "No tienes suficiente maná.")
		return false
	
	player.hand.erase(card)
	
	match card.card_type:
		Card.CardType.CREATURE:
			player.field.append(card)
			summoned_this_turn.append(card)
			emit_signal("log_message", "Jugaste: %s (%d/%d)" % [card.card_name, card.power, card.toughness])
		Card.CardType.SPELL, Card.CardType.INSTANT:
			bot.receive_damage(card.damage)
			player.graveyard.append(card)
			emit_signal("log_message", "%s inflige %d daños al bot." % [card.card_name, card.damage])
	
	_check_game_over()
	return true

# El jugador ataca con una criatura del campo
# target_index: índice en bot.field, o -1 para atacar directo al bot
func attack(attacker: Card, target_index: int) -> void:
	if not is_player_turn:
		return
	if attacker in attacked_this_turn:
		emit_signal("log_message", "%s ya atacó este turno." % attacker.card_name)
		return
	if attacker in summoned_this_turn:
		emit_signal("log_message", "%s no puede atacar el turno que es invocada." % attacker.card_name)
		return
	
	attacked_this_turn.append(attacker)
	
	if target_index == -1 or bot.field.is_empty():
		# Ataque directo
		bot.receive_damage(attacker.power)
		emit_signal("log_message", "%s ataca directo al Bot por %d daños." % [attacker.card_name, attacker.power])
	else:
		# Ataque a criatura
		var target = bot.field[target_index]
		_resolve_combat(attacker, target, player, bot)
	
	_check_game_over()

func _resolve_combat(attacker: Card, defender: Card, atk_player: PlayerState, def_player: PlayerState) -> void:
	emit_signal("log_message", "%s ataca a %s" % [attacker.card_name, defender.card_name])
	
	# Daño simultáneo
	var attacker_dies = attacker.toughness <= defender.power
	var defender_dies = defender.toughness <= attacker.power
	
	if attacker_dies:
		atk_player.field.erase(attacker)
		atk_player.graveyard.append(attacker)
		emit_signal("log_message", "%s muere." % attacker.card_name)
	
	if defender_dies:
		def_player.field.erase(defender)
		def_player.graveyard.append(defender)
		emit_signal("log_message", "%s muere." % defender.card_name)
	
	if not attacker_dies and not defender_dies:
		emit_signal("log_message", "Ambas criaturas sobreviven.")

func end_turn() -> void:
	if not is_player_turn:
		return
	
	emit_signal("log_message", "Jugador termina su turno.")
	is_player_turn = false
	turn_number += 1
	_start_turn()

func bot_take_turn() -> void:
	# El bot juega sus cartas y ataca (lo haremos en Fase 5)
	# Por ahora solo pasa turno
	emit_signal("log_message", "Bot pasa turno.")
	is_player_turn = true
	turn_number += 1
	_start_turn()

func _active_player() -> PlayerState:
	return player if is_player_turn else bot

func _check_game_over() -> void:
	if bot.is_dead():
		emit_signal("game_over", true)
		emit_signal("log_message", "¡Ganaste!")
	elif player.is_dead():
		emit_signal("game_over", false)
		emit_signal("log_message", "¡Perdiste!")
