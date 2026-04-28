# api_servicio.gd  →  añádelo en Proyecto > Ajustes > Autoload
extends Node

const API_BASE = "http://aixec.eu-north-1.elasticbeanstalk.com/api"
const SAVE_PATH = "res://data/cards.json"

var token: String = ""

func get_headers() -> Array:
	return [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]
