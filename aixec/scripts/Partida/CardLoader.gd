extends Node
# CardLoader.gd
# ─────────────────────────────────────────────────────────────────────────────
# SINGLETON — Project > Project Settings > AutoLoad > nombre: "CardLoader"
#
# Carga cards.json UNA sola vez al arrancar y ofrece la función:
#
#   CardLoader.construir_baraja(ids: Array) -> Array
#
# que convierte una lista de IDs en la Array<Dictionary> que espera
# GameManager.iniciar_partida().
#
# USO DESDE TU LOGIN (sustituto directo de lo que tenías):
#
#   var baraja_j := CardLoader.construir_baraja(
#       [1,2,3,4,5,11,12,13,14,15,26,27,28,29,30,31,35,36,37,38])
#   var baraja_o := CardLoader.construir_baraja(
#       [1,2,3,4,5,11,12,13,14,15,26,27,28,29,30,31,35,36,37,38])
#   GameManager.iniciar_partida(baraja_j, baraja_o)
# ─────────────────────────────────────────────────────────────────────────────

const RUTA_JSON := "res://data/cards.json"

## Diccionario interno: { id(int) -> datos(Dictionary) }
var _cartas_por_id: Dictionary = {}
var _cargado:       bool       = false


# ═════════════════════════════════════════════
#  INICIALIZACIÓN
# ═════════════════════════════════════════════
func _ready() -> void:
	_cargar_json()


func _cargar_json() -> void:
	if _cargado:
		return

	var archivo := FileAccess.open(RUTA_JSON, FileAccess.READ)
	if archivo == null:
		push_error("[CardLoader] No se pudo abrir %s" % RUTA_JSON)
		return

	var texto:    String     = archivo.get_as_text()
	archivo.close()

	var resultado = JSON.parse_string(texto)
	if resultado == null:
		push_error("[CardLoader] Error al parsear cards.json")
		return

	# resultado es un Array de Dictionaries
	for carta in resultado:
		var card_id: int = carta.get("id", -1)
		if card_id >= 0:
			_cartas_por_id[card_id] = carta

	_cargado = true
	print("[CardLoader] %d cartas cargadas desde cards.json" % _cartas_por_id.size())


# ═════════════════════════════════════════════
#  API PÚBLICA
# ═════════════════════════════════════════════

## Convierte una lista de IDs en Array<Dictionary> lista para GameManager.
## · Admite IDs duplicados (una baraja puede tener dos copias del mismo ID).
## · Si un ID no existe en el JSON se imprime un aviso y se omite.
## · La baraja resultante se mezcla al azar antes de devolverse.
func construir_baraja(ids: Array) -> Array:
	if not _cargado:
		_cargar_json()

	var baraja: Array = []
	for id in ids:
		if _cartas_por_id.has(id):
			# .duplicate() para que cada instancia de carta sea independiente
			baraja.append(_cartas_por_id[id].duplicate(true))
		else:
			push_warning("[CardLoader] ID %d no encontrado en cards.json" % id)

	baraja.shuffle()
	return baraja


## Devuelve los datos de una sola carta por ID (o {} si no existe).
func get_carta(id: int) -> Dictionary:
	if not _cargado:
		_cargar_json()
	return _cartas_por_id.get(id, {}).duplicate(true)


## Devuelve todos los IDs disponibles.
func get_todos_los_ids() -> Array:
	if not _cargado:
		_cargar_json()
	return _cartas_por_id.keys()
