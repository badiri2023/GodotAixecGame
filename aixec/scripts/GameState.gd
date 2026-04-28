# GameState.gd — añádelo como Autoload en Proyecto > Ajustes de Proyecto
extends Node

var ronda: int = 1
var turno: int = 1          # 1 = jugador con prioridad, 2 = el otro
var jugador_prioridad: int  # 1 o 2, asignado por moneda

var jugadores = {
	1: { "nombre": "Jugador 1", "vida": 5, "mana_actual": 1, "mana_max": 1, "mano": [], "despliegue": [] },
	2: { "nombre": "Jugador 2", "vida": 5, "mana_actual": 1, "mana_max": 1, "mano": [], "despliegue": [] }
}

const MANA_TOPE = 8
const VIDA_INICIAL = 5
const CARTAS_INICIALES = 5
const MAX_DESPLIEGUE = 3

func lanzar_moneda() -> int:
	jugador_prioridad = randi() % 2 + 1
	return jugador_prioridad

func nueva_ronda():
	ronda += 1
	turno = 1
	for id in jugadores:
		var j = jugadores[id]
		j["mana_max"] = min(j["mana_max"] + 1, MANA_TOPE)
		j["mana_actual"] = j["mana_max"]
	# también se reparte 1 carta a cada jugador aquí

func es_primera_ronda() -> bool:
	return ronda == 1
