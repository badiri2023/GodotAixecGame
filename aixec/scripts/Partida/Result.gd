extends Control

# Referencia al script singleton/autoload ApiServicio
@onready var api_servicio = ApiServicio

func _ready():
	$BotonReplay.pressed.connect(_on_boton_replay_pressed)
	$BotonExit.pressed.connect(_on_boton_exit_pressed)


func _on_boton_replay_pressed():
	# Reiniciar variables
	api_servicio.token = ""
	api_servicio.usuario_id = 0
	api_servicio.usuario_nombre = ""

	# Cambiar a la escena Login
	get_tree().change_scene_to_file("res://scenes/Login.tscn")


func _on_boton_exit_pressed():
	# Cerrar el juego
	get_tree().quit()
