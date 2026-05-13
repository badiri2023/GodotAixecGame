extends Button
# BotonRendirse.gd
# Adjunta este script al botón de rendirse en Game.tscn


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if not GameManager.partida_activa:
		return
	GameManager.jugador["vida"] = 0
	GameManager.emit_signal("vida_cambiada", "jugador", 0)
	GameManager._terminar_partida("oponente")
