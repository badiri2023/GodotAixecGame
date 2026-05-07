# GameState.gd — Autoload con nombre "GameState"
extends Node

# ─────────────────────────────────────────
#  CONSTANTES
# ─────────────────────────────────────────
const VIDA_INICIAL    : int = 5
const MANA_TOPE       : int = 15
const CARTAS_INICIALES: int = 5
const MAX_MONSTRUOS   : int = 3
const MAX_HECHIZOS    : int = 3

const TIPO_MONSTRUO     : int = 1
const TIPO_HECHIZO      : int = 2
const TIPO_EQUIPAMIENTO : int = 3

# ─────────────────────────────────────────
#  ESTADO DE PARTIDA
# ─────────────────────────────────────────
var ronda            : int = 1
var turno_jugador    : int = 1   # id del jugador que tiene el turno
var jugador_prioridad: int = 1   # id del jugador que ganó la moneda

var jugadores : Dictionary = {
	1: {
		"nombre":      "Jugador 1",
		"vida":        VIDA_INICIAL,
		"mana_actual": 5,
		"mana_max":    5,
		"mano":        [],   # Array de nodos Card en la zona disponibles
		"monstruos":   [],   # Array de nodos Card desplegados
		"hechizos":    [],   # Array de nodos Card desplegados
	},
	2: {
		"nombre":      "Jugador 2",
		"vida":        VIDA_INICIAL,
		"mana_actual": 5,
		"mana_max":    5,
		"mano":        [],
		"monstruos":   [],
		"hechizos":    [],
	}
}

# ─────────────────────────────────────────
#  MONEDA
# ─────────────────────────────────────────
func lanzar_moneda() -> int:
	jugador_prioridad = randi() % 2 + 1
	turno_jugador     = jugador_prioridad
	return jugador_prioridad

# ─────────────────────────────────────────
#  RONDA
# ─────────────────────────────────────────
func es_primera_ronda() -> bool:
	return ronda == 1

func nueva_ronda():
	ronda += 1
	turno_jugador = jugador_prioridad
	for id in jugadores:
		var j          = jugadores[id]
		j["mana_max"]    = min(j["mana_max"] + 1, MANA_TOPE)
		j["mana_actual"] = j["mana_max"]

# ─────────────────────────────────────────
#  MANA
# ─────────────────────────────────────────
func gastar_mana(id_jugador: int, cantidad: int) -> bool:
	var j = jugadores[id_jugador]
	if j["mana_actual"] < cantidad:
		return false
	j["mana_actual"] -= cantidad
	return true

func devolver_mana(id_jugador: int, cantidad: int):
	var j            = jugadores[id_jugador]
	j["mana_actual"] = min(j["mana_actual"] + cantidad, j["mana_max"])

# ─────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────
func get_enemigo(id_jugador: int) -> int:
	return 3 - id_jugador

func get_cartas_desplegadas(id_jugador: int) -> Array:
	return jugadores[id_jugador]["monstruos"] + jugadores[id_jugador]["hechizos"]

func jugador_ha_perdido(id_jugador: int) -> bool:
	var j = jugadores[id_jugador]
	if j["vida"] <= 0:
		return true
	if j["mano"].is_empty() and j["monstruos"].is_empty() and j["hechizos"].is_empty():
		return true
	return false

# ─────────────────────────────────────────
#  RESET (para cuando se vuelva a jugar)
# ─────────────────────────────────────────
func reset():
	ronda             = 1
	turno_jugador     = 1
	jugador_prioridad = 1
	for id in jugadores:
		var j          = jugadores[id]
		j["vida"]        = VIDA_INICIAL
		j["mana_actual"] = 1
		j["mana_max"]    = 1
		j["mano"]        = []
		j["monstruos"]   = []
		j["hechizos"]    = []
