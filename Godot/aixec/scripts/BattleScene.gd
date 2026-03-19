# BattleScene.gd
extends Node2D

@onready var game_state   = $GameState
@onready var player_hp    = $UI/PlayerZone/PlayerStats/PlayerHP
@onready var player_mana  = $UI/PlayerZone/PlayerStats/PlayerMana
@onready var bot_hp       = $UI/BotZone/BotStats/BotHP
@onready var bot_mana     = $UI/BotZone/BotStats/BotMana
@onready var player_hand  = $UI/PlayerHand
@onready var player_field = $UI/PlayerZone/PlayerField
@onready var bot_field    = $UI/BotZone/BotField
@onready var turn_label   = $UI/ActionBar/TurnLabel
@onready var log_label    = $UI/LogLabel
@onready var end_turn_btn = $UI/ActionBar/EndTurnButton

const CARD_UI_SCENE = preload("res://scenes/CardUI.tscn")

func _ready() -> void:
	# Conectar señales del GameState
	game_state.turn_changed.connect(_on_turn_changed)
	game_state.game_over.connect(_on_game_over)
	game_state.log_message.connect(_on_log_message)
	
	# Conectar señales de los jugadores
	game_state.player.hp_changed.connect(_update_player_stats)
	game_state.player.mana_changed.connect(_update_player_stats)
	game_state.bot.hp_changed.connect(_update_bot_stats)
	
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	
	game_state.setup()
	_refresh_ui()

func _refresh_ui() -> void:
	_update_player_stats()
	_update_bot_stats()
	_refresh_hand()
	_refresh_fields()

func _update_player_stats(_val = null) -> void:
	player_hp.text   = "❤️ " + str(game_state.player.hp)
	player_mana.text = "💎 " + str(game_state.player.mana) + "/" + str(game_state.player.max_mana)

func _update_bot_stats(_val = null) -> void:
	bot_hp.text   = "❤️ " + str(game_state.bot.hp)
	bot_mana.text = "💎 " + str(game_state.bot.mana) + "/" + str(game_state.bot.max_mana)

func _refresh_hand() -> void:
	# Borra cartas anteriores
	for child in player_hand.get_children():
		child.queue_free()
	
	# Crea una CardUI por cada carta en la mano
	for card in game_state.player.hand:
		var card_ui = CARD_UI_SCENE.instantiate()
		player_hand.add_child(card_ui)
		card_ui.setup(card)
		
		# Resalta si tiene maná suficiente
		var can_play = card.mana_cost <= game_state.player.mana and game_state.is_player_turn
		card_ui.set_playable(can_play)
		card_ui.card_clicked.connect(_on_card_clicked)

func _refresh_fields() -> void:
	for child in player_field.get_children():
		child.queue_free()
	for child in bot_field.get_children():
		child.queue_free()
	
	for card in game_state.player.field:
		var card_ui = CARD_UI_SCENE.instantiate()
		player_field.add_child(card_ui)
		card_ui.setup(card)
		var can_attack = game_state.is_player_turn \
			and card not in game_state.attacked_this_turn \
			and card not in game_state.summoned_this_turn
		card_ui.set_playable(can_attack)
		card_ui.card_clicked.connect(_on_field_card_clicked.bind(card))
	
	for card in game_state.bot.field:
		var card_ui = CARD_UI_SCENE.instantiate()
		bot_field.add_child(card_ui)
		card_ui.setup(card)

func _on_card_clicked(card_ui: CardUI) -> void:
	game_state.play_card(card_ui.card_data)
	_refresh_ui()

func _on_field_card_clicked(card: Card) -> void:
	# Ataque directo al bot (sin selección de objetivo por ahora)
	game_state.attack(card, -1)
	_refresh_ui()

func _on_end_turn_pressed() -> void:
	game_state.end_turn()
	_refresh_ui()
	# Pequeña pausa antes del turno del bot
	await get_tree().create_timer(0.5).timeout
	game_state.bot_take_turn()
	_refresh_ui()

func _on_turn_changed(is_player_turn: bool) -> void:
	turn_label.text = "Turno: " + ("Jugador" if is_player_turn else "Bot")
	end_turn_btn.disabled = not is_player_turn
	_refresh_hand()
	_refresh_fields()

func _on_game_over(player_won: bool) -> void:
	end_turn_btn.disabled = true
	log_label.text = "¡GANASTE! 🏆" if player_won else "¡PERDISTE! 💀"

func _on_log_message(text: String) -> void:
	log_label.text = text
