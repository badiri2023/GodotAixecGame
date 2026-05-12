extends Node

const API_BASE = "http://aixec.eu-north-1.elasticbeanstalk.com/api"

# Cambiado a user:// para que puedas escribir y sobreescribir el archivo en el juego final
const SAVE_PATH = "user://cards.json" 

var token: String = ""
var usuario_id: int = 0
# Cambiamos Array por PackedStringArray para que Godot 4 no tire errores
func get_headers() -> PackedStringArray:
	var headers = PackedStringArray()
	headers.append("Content-Type: application/json")
	
	# Solo añadimos el token si realmente existe (por si llamas a la API antes del login)
	if token != "":
		headers.append("Authorization: Bearer " + token)
		
	return headers
