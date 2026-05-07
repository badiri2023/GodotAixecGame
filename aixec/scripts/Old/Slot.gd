# res://scripts/Slot.gd
extends Panel

signal slot_clickado(slot)

# En Slot.gd, añade exports para configurar desde el editor:
@export var indice     : int    = 0
@export var tipo       : String = "monstruo"
@export var es_enemigo : bool   = false

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("slot_clickado", self)
