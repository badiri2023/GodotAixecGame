# CardUI.gd
class_name CardUI
extends PanelContainer

signal card_clicked(card_ui)

var card_data: Card = null
var is_playable: bool = false

@onready var card_name_label = $VBoxContainer/CardName
@onready var card_type_label = $VBoxContainer/CardType
@onready var card_desc_label  = $VBoxContainer/CardDesc
@onready var card_stats_label = $VBoxContainer/CardStats

func setup(data: Card) -> void:
	card_data = data
	card_name_label.text = data.card_name
	card_type_label.text  = _type_string(data.card_type) + " | 💎" + str(data.mana_cost)
	card_desc_label.text  = data.description
	
	if data.card_type == Card.CardType.CREATURE:
		card_stats_label.text = str(data.power) + "/" + str(data.toughness)
	else:
		card_stats_label.text = "💥 " + str(data.damage)

func set_playable(value: bool) -> void:
	is_playable = value
	# Resalta en verde si se puede jugar, gris si no
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.2) if value else Color(0.3, 0.3, 0.3)
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_playable:
				emit_signal("card_clicked", self)

func _type_string(t: Card.CardType) -> String:
	match t:
		Card.CardType.CREATURE: return "Criatura"
		Card.CardType.SPELL:    return "Hechizo"
		Card.CardType.INSTANT:  return "Instantáneo"
	return ""
