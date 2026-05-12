extends Node
# GameManager.gd
# SINGLETON — Project > Project Settings > AutoLoad > nombre: "GameManager"


# ═════════════════════════════════════════════
#  SEÑALES
# ═════════════════════════════════════════════
signal partida_iniciada(primer_turno: String)
signal partida_terminada(ganador: String)
signal ronda_cambiada(nueva_ronda: int)
signal turno_cambiado(turno: String)
signal vida_cambiada(quien: String, nueva_vida: int)
signal mana_cambiado(quien: String, mana_actual: int, mana_maximo: int)
signal carta_robada(quien: String, carta: Dictionary)
signal carta_desplegada(quien: String, carta: Dictionary, destino: String)
signal carta_enviada_al_cementerio(quien: String, carta: Dictionary)
signal equipamiento_colocado(quien: String, equip: Dictionary)
signal equipamiento_retirado(quien: String, equip: Dictionary)


# ═════════════════════════════════════════════
#  CONSTANTES
# ═════════════════════════════════════════════
const VIDA_MAXIMA:      int = 5
const MANA_INICIAL:     int = 1
const MANA_MAXIMO:      int = 8
const MAX_BARAJA:       int = 20
const MAX_MONSTRUOS:    int = 3
const MAX_HECHIZOS:     int = 3
const CARTAS_INICIALES: int = 5
const CARTAS_POR_RONDA: int = 1

const TIPO_MONSTRUO:     int = 1
const TIPO_HECHIZO:      int = 2
const TIPO_EQUIPAMIENTO: int = 3


# ═════════════════════════════════════════════
#  ESTADO DE PARTIDA
# ═════════════════════════════════════════════
var partida_activa:      bool  = false
## false = singleplayer (bot), true = multijugador online
var es_multijugador:         bool  = false
var tiempo_transcurrido: float = 0.0
var ids_baraja_jugador:  Array = []
var ids_baraja_oponente: Array = []


# ═════════════════════════════════════════════
#  RONDA Y TURNO
# ═════════════════════════════════════════════
var ronda_actual:             int    = 1
var turno_actual:             String = ""
var turno_prioritario:        String = ""
var _turnos_jugados_en_ronda: int    = 0
var solo_despliegue:          bool   = true


# ═════════════════════════════════════════════
#  DATOS DE JUGADORES
# ═════════════════════════════════════════════
var jugador:  Dictionary = {}
var oponente: Dictionary = {}
var game_id_actual: int = 0

func _crear_jugador() -> Dictionary:
	return {
		"nombre":        "",
		"imagen_perfil": "",
		"vida":          VIDA_MAXIMA,
		"mana_actual":   MANA_INICIAL,
		"mana_maximo":   MANA_INICIAL,
		"baraja":        [],   # Array<Dictionary> — cartas pendientes de robar
		"mano":          [],   # Array<Dictionary> — cartas en mano
		"monstruos":     [],   # Array<Dictionary> — máx. MAX_MONSTRUOS
		"hechizos":      [],   # Array<Dictionary> — máx. MAX_HECHIZOS
		"cementerio":    [],   # Array<Dictionary>
		# Slot de equipamiento global: solo 1 carta de tipo EQUIPAMIENTO a la vez.
		# Cuando está ocupado, TODOS los monstruos desplegados y los que se
		# desplieguen después reciben su buff de atk y vida (excepto mana).
		"equipamiento":  {},   # Dictionary vacío = sin equipamiento
	}


# ═════════════════════════════════════════════
#  GODOT CALLBACKS
# ═════════════════════════════════════════════
func _process(delta: float) -> void:
	if partida_activa:
		tiempo_transcurrido += delta


# ═════════════════════════════════════════════
#  INICIO DE PARTIDA
# ═════════════════════════════════════════════
func iniciar_partida(baraja_jugador: Array, baraja_oponente: Array) -> void:
	ronda_actual             = 1
	_turnos_jugados_en_ronda = 0
	tiempo_transcurrido      = 0.0
	solo_despliegue          = true

	jugador  = _crear_jugador()
	oponente = _crear_jugador()

	jugador["baraja"]  = baraja_jugador.slice(0, MAX_BARAJA)
	oponente["baraja"] = baraja_oponente.slice(0, MAX_BARAJA)

	turno_prioritario = "jugador" if randi() % 2 == 0 else "oponente"
	turno_actual      = turno_prioritario
	print("[GameManager] Moneda → prioridad: %s" % turno_prioritario)

	partida_activa = true

	for i in CARTAS_INICIALES:
		_robar_carta_interno("jugador")
		_robar_carta_interno("oponente")

	emit_signal("partida_iniciada", turno_actual)
	emit_signal("turno_cambiado",   turno_actual)
	print("[GameManager] Partida iniciada — Ronda 1 — Turno: %s" % turno_actual)


# ═════════════════════════════════════════════
#  FIN DE PARTIDA
# ═════════════════════════════════════════════
func _terminar_partida(ganador: String) -> void:
	partida_activa = false
	print("[GameManager] ══ Partida terminada — Ganador: %s ══" % ganador)
	emit_signal("partida_terminada", ganador)

	# --- NOTIFICAR AL SERVIDOR ---
	_comunicar_resultado_al_servidor(ganador)

func _comunicar_resultado_al_servidor(ganador: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	# Definimos quién gana y quién pierde para el DTO del servidor
	# Si el ganador es "jugador", el Winner es nuestro ID y el Loser es el Bot (ID 10)
	var winner_id: int
	var loser_id: int
	
	if ganador == "jugador":
		winner_id = ApiServicio.usuario_id
		loser_id = 10 # ID fijo de tu Bot en la DB
	else:
		winner_id = 10
		loser_id = ApiServicio.usuario_id

	var url = ApiServicio.API_BASE + "/game/report-result"
	var headers = ApiServicio.get_headers()
	
	# El JSON debe coincidir con tu record 'ReportResultDto' en C#
	var cuerpo = {
		"GameId": game_id_actual,
		"WinnerUserId": winner_id,
		"LoserUserId": loser_id
	}
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(cuerpo))
	
	if error != OK:
		print("❌ Error al intentar enviar el reporte")
		http.queue_free()
	
	# Limpiamos el nodo al terminar
	http.request_completed.connect(func(_r, code, _h, _b):
		if code == 200:
			print("✅ Servidor actualizado: Monedas y estadísticas guardadas.")
		else:
			print("⚠️ El servidor respondió con error: ", code)
		http.queue_free()
	)


func rendirse(quien: String) -> void:
	if not partida_activa:
		return
	var ganador: String = "oponente" if quien == "jugador" else "jugador"
	print("[GameManager] %s se rinde" % quien)
	_terminar_partida(ganador)


# ═════════════════════════════════════════════
#  TURNOS Y RONDAS
# ═════════════════════════════════════════════

## Botón "Acabar turno" de la UI → llama a acabar_turno("jugador")
func acabar_turno(quien: String) -> void:
	if not partida_activa or quien != turno_actual:
		return

	_turnos_jugados_en_ronda += 1

	if _turnos_jugados_en_ronda >= 2:
		_turnos_jugados_en_ronda = 0
		_avanzar_ronda()
		turno_actual = turno_prioritario
	else:
		turno_actual = "oponente" if turno_actual == "jugador" else "jugador"

	emit_signal("turno_cambiado", turno_actual)
	print("[GameManager] Turno: %s  |  Ronda: %d" % [turno_actual, ronda_actual])


func _avanzar_ronda() -> void:
	ronda_actual   += 1
	solo_despliegue = false

	_robar_carta_interno("jugador")
	_robar_carta_interno("oponente")
	_reponer_y_aumentar_mana("jugador")
	_reponer_y_aumentar_mana("oponente")

	emit_signal("ronda_cambiada", ronda_actual)
	print("[GameManager] ── Nueva ronda: %d ──" % ronda_actual)


# ═════════════════════════════════════════════
#  MANA
# ═════════════════════════════════════════════
func _reponer_y_aumentar_mana(quien: String) -> void:
	var p := _get_jugador(quien)
	if p.is_empty(): return
	p["mana_maximo"] = min(p["mana_maximo"] + 1, MANA_MAXIMO)
	p["mana_actual"] = p["mana_maximo"]
	emit_signal("mana_cambiado", quien, p["mana_actual"], p["mana_maximo"])


func gastar_mana(quien: String, cantidad: int) -> bool:
	var p := _get_jugador(quien)
	if p.is_empty() or p["mana_actual"] < cantidad:
		return false
	p["mana_actual"] -= cantidad
	emit_signal("mana_cambiado", quien, p["mana_actual"], p["mana_maximo"])
	return true


# ═════════════════════════════════════════════
#  VIDA Y DAÑO
# ═════════════════════════════════════════════
func aplicar_danyo(quien: String, cantidad: int) -> void:
	var p := _get_jugador(quien)
	if p.is_empty(): return
	p["vida"] = max(0, p["vida"] - cantidad)
	emit_signal("vida_cambiada", quien, p["vida"])
	print("[GameManager] %s recibe %d daño — vida: %d" % [quien, cantidad, p["vida"]])
	if p["vida"] <= 0:
		_terminar_partida("oponente" if quien == "jugador" else "jugador")


func curar(quien: String, cantidad: int) -> void:
	var p := _get_jugador(quien)
	if p.is_empty(): return
	p["vida"] = min(VIDA_MAXIMA, p["vida"] + cantidad)
	emit_signal("vida_cambiada", quien, p["vida"])
	print("[GameManager] %s curado %d — vida: %d" % [quien, cantidad, p["vida"]])


# ═════════════════════════════════════════════
#  SLOT DE EQUIPAMIENTO GLOBAL
# ═════════════════════════════════════════════

## Coloca una carta de equipamiento en el slot global del jugador.
## · Gasta su mana.
## · Aplica el buff (atk + vida, NO mana) a todos los monstruos ya desplegados
##   y marca la carta como equipamiento activo para bufear los futuros.
## · Solo puede haber 1 equipamiento a la vez; hay que retirar el anterior primero.
## Devuelve true si se colocó con éxito.
func colocar_equipamiento(quien: String, equip_dict: Dictionary) -> bool:
	if not partida_activa or quien != turno_actual:
		return false

	var p := _get_jugador(quien)
	if p.is_empty(): return false

	if not p["equipamiento"].is_empty():
		print("[GameManager] %s ya tiene equipamiento en el slot" % quien)
		return false

	var equip_tipo: int = int(equip_dict.get("type", equip_dict.get("tipo", -1)))
	if equip_tipo != TIPO_EQUIPAMIENTO:
		return false

	var equip_en_mano: Dictionary = _buscar_en_mano_por_id(p["mano"], equip_dict)
	if equip_en_mano.is_empty():
		return false
	equip_dict = equip_en_mano

	var coste: int = int(equip_dict.get("mana", 0))
	if not gastar_mana(quien, coste):
		print("[GameManager] Mana insuficiente para equipamiento (necesita %d)" % coste)
		return false

	p["mano"].erase(equip_dict)
	p["equipamiento"] = equip_dict

	# Aplica buff a todos los monstruos desplegados ahora mismo
	_aplicar_buff_equip_a_monstruos(quien)

	emit_signal("equipamiento_colocado", quien, equip_dict)
	print("[GameManager] '%s' equipado en slot global de %s" % [equip_dict.get("nombre","???"), quien])
	return true


## Retira el equipamiento del slot global, revirtiendo el buff en todos los monstruos.
func retirar_equipamiento(quien: String) -> void:
	var p := _get_jugador(quien)
	if p.is_empty() or p["equipamiento"].is_empty():
		return

	var equip_dict: Dictionary = p["equipamiento"]

	# Revierte el buff en todos los monstruos desplegados
	_revertir_buff_equip_de_monstruos(quien)

	p["equipamiento"] = {}
	p["cementerio"].append(equip_dict)

	emit_signal("equipamiento_retirado", quien, equip_dict)
	print("[GameManager] Equipamiento '%s' retirado de %s" % [equip_dict.get("nombre","???"), quien])


## Llama a esto desde desplegar_carta() cuando se despliega un monstruo
## para aplicarle el buff si hay equipamiento activo.
func _aplicar_buff_a_monstruo_si_procede(quien: String, carta_nodo: Card = null) -> void:
	var p := _get_jugador(quien)
	if p.is_empty() or p["equipamiento"].is_empty():
		return
	var equip_nodo: Card = _buscar_nodo_equip(quien)
	if equip_nodo == null:
		return
	# Si no se pasa el nodo, aplica a todos los monstruos desplegados
	if carta_nodo == null:
		_aplicar_buff_equip_a_monstruos(quien)
		return
	if carta_nodo.tipo != Card.TIPO_MONSTRUO:
		return
	carta_nodo.aplicar_buff_equipamiento(equip_nodo)


func _aplicar_buff_equip_a_monstruos(quien: String) -> void:
	var equip_nodo: Card = _buscar_nodo_equip(quien)
	if equip_nodo == null: return
	for carta_nodo in _get_nodos_monstruos(quien):
		carta_nodo.aplicar_buff_equipamiento(equip_nodo)


func _revertir_buff_equip_de_monstruos(quien: String) -> void:
	var equip_nodo: Card = _buscar_nodo_equip(quien)
	if equip_nodo == null: return
	for carta_nodo in _get_nodos_monstruos(quien):
		carta_nodo.revertir_buff_equipamiento(equip_nodo)


## Devuelve el nodo Card del equipamiento activo, buscándolo en la escena.
func _buscar_nodo_equip(quien: String) -> Card:
	var p := _get_jugador(quien)
	if p.is_empty() or p["equipamiento"].is_empty(): return null
	var equip_id: int = int(p["equipamiento"].get("id", -1))
	var raiz: Node = get_tree().get_root()
	# Busca sin filtro de propietario por si no se asignó correctamente
	return _buscar_card_por_id_sin_propietario(raiz, equip_id)


func _buscar_card_por_id_sin_propietario(nodo: Node, card_id: int) -> Card:
	if nodo is Card and nodo.id == card_id and nodo.tipo == Card.TIPO_EQUIPAMIENTO:
		return nodo
	for hijo in nodo.get_children():
		var resultado: Card = _buscar_card_por_id_sin_propietario(hijo, card_id)
		if resultado: return resultado
	return null


func _buscar_card_por_id_recursivo(nodo: Node, card_id: int, propietario: String) -> Card:
	if nodo is Card and nodo.id == card_id and nodo.propietario == propietario:
		return nodo
	for hijo in nodo.get_children():
		var resultado: Card = _buscar_card_por_id_recursivo(hijo, card_id, propietario)
		if resultado: return resultado
	return null


## Devuelve los nodos Card monstruo desplegados de `quien`.
func _get_nodos_monstruos(quien: String) -> Array:
	# Solo devuelve cartas que estén en el grupo "desplegadas", es decir,
	# colocadas en un slot del tablero. Las cartas en mano NO están en este grupo.
	var resultado: Array = []
	for nodo in get_tree().get_nodes_in_group("desplegadas"):
		if nodo is Card and nodo.propietario == quien and nodo.tipo == Card.TIPO_MONSTRUO:
			resultado.append(nodo)
	return resultado


## Helper para Card.gd: devuelve el bonus de vida del equipamiento activo.
func get_buff_vida_equip(quien: String) -> int:
	var p := _get_jugador(quien)
	if p.is_empty() or p["equipamiento"].is_empty(): return 0
	return p["equipamiento"].get("defense", 0)


# ═════════════════════════════════════════════
#  GESTIÓN DE CARTAS
# ═════════════════════════════════════════════

func _robar_carta_interno(quien: String) -> void:
	var p := _get_jugador(quien)
	if p.is_empty() or p["baraja"].is_empty(): return
	var carta: Dictionary = p["baraja"].pop_front()
	p["mano"].append(carta)
	emit_signal("carta_robada", quien, carta)
	print("[GameManager] %s roba: %s" % [quien, carta.get("nombre","???")])


## Despliega una carta de la mano al tablero.
## Para monstruos, también aplica el buff de equipamiento si hay uno activo.
## `carta_nodo` es el nodo Card correspondiente (necesario para el buff).
func desplegar_carta(quien: String, carta: Dictionary, carta_nodo: Card = null) -> bool:
	if not partida_activa or quien != turno_actual:
		return false

	var p := _get_jugador(quien)
	if p.is_empty(): return false

	# Busca la carta en la mano por ID (los dicts pueden tener claves distintas
	# según vengan del JSON original o de get_datos_actuales())
	var carta_en_mano: Dictionary = _buscar_en_mano_por_id(p["mano"], carta)
	if carta_en_mano.is_empty():
		print("[GameManager] Carta id=%d no está en la mano de %s" % [carta.get("id", carta.get("id",-1)), quien])
		return false

	# tipo puede venir como "type" (JSON, float) o "tipo" (get_datos_actuales, int)
	var tipo: int = int(carta_en_mano.get("type", carta_en_mano.get("tipo", -1)))
	var destino: String = ""
	match tipo:
		TIPO_MONSTRUO:     destino = "monstruos"
		TIPO_HECHIZO:      destino = "hechizos"
		TIPO_EQUIPAMIENTO:
			# El equipamiento va al slot global, no al tablero de cartas
			return colocar_equipamiento(quien, carta)
		_:
			print("[GameManager] Tipo de carta no desplegable: %d" % tipo)
			return false

	var lista_destino: Array = p[destino]
	var max_zona: int = MAX_MONSTRUOS if destino == "monstruos" else MAX_HECHIZOS
	if lista_destino.size() >= max_zona:
		print("[GameManager] Zona '%s' de %s llena" % [destino, quien])
		return false

	var coste: int = int(carta_en_mano.get("mana", 0))
	if not gastar_mana(quien, coste):
		print("[GameManager] %s no tiene mana suficiente (%d)" % [quien, coste])
		return false

	p["mano"].erase(carta_en_mano)
	lista_destino.append(carta_en_mano)

	# Si es monstruo y hay equipamiento activo, aplica el buff
	if tipo == TIPO_MONSTRUO:
		_aplicar_buff_a_monstruo_si_procede(quien, carta_nodo)

	emit_signal("carta_desplegada", quien, carta_en_mano, destino)
	print("[GameManager] %s despliega '%s' en %s (coste %d)" % [
		quien, carta_en_mano.get("name", carta_en_mano.get("nombre","???")), destino, coste
	])
	return true


func enviar_al_cementerio(quien: String, carta: Dictionary, origen: String) -> void:
	var p := _get_jugador(quien)
	if p.is_empty(): return
	if origen not in ["monstruos", "hechizos"]:
		push_error("[GameManager] origen inválido: " + origen)
		return
	if not p[origen].has(carta): return
	p[origen].erase(carta)
	p["cementerio"].append(carta)
	# Quita la carta del grupo "desplegadas" si el nodo sigue en escena
	var card_id: int = carta.get("id", -1)
	for nodo in get_tree().get_nodes_in_group("desplegadas"):
		if nodo is Card and nodo.id == card_id and nodo.propietario == quien:
			nodo.remove_from_group("desplegadas")
			break
	emit_signal("carta_enviada_al_cementerio", quien, carta)
	print("[GameManager] '%s' → cementerio" % carta.get("name", carta.get("nombre","???")))
	_comprobar_derrota_sin_cartas(quien)


func aplicar_danyo_a_carta(quien_defiende: String, carta_objetivo: Dictionary, danyo: int) -> void:
	var p := _get_jugador(quien_defiende)
	if p.is_empty(): return

	var vida_carta: int = carta_objetivo.get("vida_actual", carta_objetivo.get("vida", 0))
	var sobrante:   int = danyo - vida_carta

	if sobrante >= 0:
		var origen: String = "monstruos" if carta_objetivo.get("tipo",-1) == TIPO_MONSTRUO else "hechizos"
		enviar_al_cementerio(quien_defiende, carta_objetivo, origen)
		if sobrante > 0:
			aplicar_danyo(quien_defiende, sobrante)
	else:
		carta_objetivo["vida_actual"] = vida_carta - danyo
		print("[GameManager] '%s' queda con %d vida" % [
			carta_objetivo.get("nombre","???"), carta_objetivo["vida_actual"]
		])


func atacar_jugador_directo(quien_ataca: String, danyo: int) -> void:
	if not partida_activa or solo_despliegue: return
	var quien_defiende: String = "oponente" if quien_ataca == "jugador" else "jugador"
	var p_def := _get_jugador(quien_defiende)
	if not p_def["monstruos"].is_empty() or not p_def["hechizos"].is_empty():
		print("[GameManager] %s tiene cartas, no se puede atacar directo" % quien_defiende)
		return
	aplicar_danyo(quien_defiende, danyo)


# ═════════════════════════════════════════════
#  DERROTA SIN CARTAS
# ═════════════════════════════════════════════
func _comprobar_derrota_sin_cartas(quien: String) -> void:
	var p := _get_jugador(quien)
	if p.is_empty(): return
	if p["baraja"].is_empty() and p["mano"].is_empty() \
	and p["monstruos"].is_empty() and p["hechizos"].is_empty():
		_terminar_partida("oponente" if quien == "jugador" else "jugador")


# ═════════════════════════════════════════════
#  HELPERS PÚBLICOS
# ═════════════════════════════════════════════
func es_mi_turno(quien: String) -> bool:
	return turno_actual == quien

func puede_atacar_o_usar_habilidad() -> bool:
	return not solo_despliegue

func tiene_equipamiento(quien: String) -> bool:
	var p := _get_jugador(quien)
	return not p.is_empty() and not p["equipamiento"].is_empty()


# ═════════════════════════════════════════════
#  INTERNO
# ═════════════════════════════════════════════
## Busca un Dictionary en la lista mano comparando por "id".
## Necesario porque la carta puede venir de get_datos_actuales() (claves ES)
## o directamente del JSON (claves EN), pero el "id" siempre existe en ambos.
func _buscar_en_mano_por_id(mano: Array, carta: Dictionary) -> Dictionary:
	var card_id: int = carta.get("id", -1)
	if card_id == -1:
		return {}
	for c in mano:
		if c.get("id", -2) == card_id:
			return c
	return {}


func _get_jugador(quien: String) -> Dictionary:
	match quien:
		"jugador":  return jugador
		"oponente": return oponente
		_:
			push_error("[GameManager] Jugador desconocido: " + quien)
			return {}
