extends Node
# BotManager.gd
# SINGLETON — AutoLoad > nombre: "BotManager"


const PAUSA_ENTRE_ACCIONES: float = 0.8
const PAUSA_FIN_TURNO:      float = 1.2


func _ready() -> void:
	GameManager.turno_cambiado.connect(_on_turno_cambiado)


# ═════════════════════════════════════════════
#  ENTRADA DE TURNO
# ═════════════════════════════════════════════

func _on_turno_cambiado(turno: String) -> void:
	if turno != "oponente" or GameManager.es_multijugador or not GameManager.partida_activa:
		return
	await get_tree().create_timer(PAUSA_ENTRE_ACCIONES).timeout
	await _ejecutar_turno_bot()


# ═════════════════════════════════════════════
#  TURNO DEL BOT
# ═════════════════════════════════════════════

func _ejecutar_turno_bot() -> void:
	# 1. Despliegue
	var siguio_colocando: bool = true
	while siguio_colocando and GameManager.partida_activa and GameManager.turno_actual == "oponente":
		siguio_colocando = await _intentar_colocar_carta()
		if siguio_colocando:
			await get_tree().create_timer(PAUSA_ENTRE_ACCIONES).timeout

	# 2. Habilidades activas (solo desde ronda 2)
	if not GameManager.solo_despliegue:
		await _ejecutar_habilidades()

	# 3. Ataques (solo desde ronda 2)
	if not GameManager.solo_despliegue:
		await _ejecutar_ataques()

	# Fin de turno
	await get_tree().create_timer(PAUSA_FIN_TURNO).timeout
	if GameManager.partida_activa and GameManager.turno_actual == "oponente":
		GameManager.acabar_turno("oponente")


# ═════════════════════════════════════════════
#  FASE DE HABILIDADES ACTIVAS
# ═════════════════════════════════════════════

func _ejecutar_habilidades() -> void:
	# Recorre todas las cartas del oponente desplegadas con habilidad activa
	var cartas: Array = _get_monstruos_oponente() + _get_hechizos_oponente()
	for carta in cartas:
		if not GameManager.partida_activa or GameManager.turno_actual != "oponente":
			return
		if carta.usada_este_turno:
			continue
		if carta.habilidad_id < 0 or carta.habilidad_es_pasiva:
			continue

		# Comprueba si la habilidad puede usarse (misma validación que el jugador)
		var error: String = AbilityManager._validar_habilidad(
			carta.habilidad_id, "oponente",
			_elegir_objetivo_enemigo()
		)
		if error != "":
			continue

		# Elige objetivo enemigo si la habilidad lo requiere
		var objetivo: Card = null
		if carta.habilidad_id in [5, 15, 28]:
			objetivo = _elegir_objetivo_enemigo()
			if objetivo == null:
				continue

		AbilityManager.activar_habilidad_activa(carta, "oponente", objetivo)
		print("[BotManager] Bot usó habilidad '%s' con carta '%s'" % [
			carta.habilidad_nombre, carta.nombre
		])
		await get_tree().create_timer(PAUSA_ENTRE_ACCIONES).timeout


# ═════════════════════════════════════════════
#  FASE DE ATAQUES
# ═════════════════════════════════════════════

func _ejecutar_ataques() -> void:
	var monstruos: Array = _get_monstruos_oponente()
	for atacante in monstruos:
		if not GameManager.partida_activa or GameManager.turno_actual != "oponente":
			return
		if atacante.usada_este_turno:
			continue

		var p_jugador: Dictionary = GameManager._get_jugador("jugador")
		var tiene_monstruos: bool = not p_jugador["monstruos"].is_empty()

		if tiene_monstruos:
			# Ataca al monstruo del jugador con menos vida
			var defensor: Card = _elegir_objetivo_enemigo()
			if defensor == null:
				continue

			# Pre-ataque: comprueba pasivas
			var pre: Dictionary = AbilityManager.pre_ataque(atacante, defensor, atacante.ataque_actual)
			if pre["cancelar"]:
				atacante.usada_este_turno = true
				continue

			var danyo: int = atacante.ataque_actual + pre["danyo_extra"]
			var vida_antes: int = defensor.vida_actual
			var defensor_murio: bool = false

			if not pre["anular_danyo_defensor"]:
				# Comprueba Nostalgia
				var nostalgia: bool = AbilityManager.notificar_muerte(defensor, "jugador") if danyo >= defensor.vida_actual else false
				if not nostalgia:
					defensor.recibir_danyo(danyo)
					if defensor.vida_actual <= 0:
						defensor_murio = true
						var sobrante: int = max(0, danyo - vida_antes)
						if sobrante > 0:
							GameManager.aplicar_danyo("jugador", sobrante)

			# Daño al atacante por pasivas del defensor
			if pre["danyo_atacante"] > 0:
				atacante.recibir_danyo(pre["danyo_atacante"])

			# Post-ataque
			AbilityManager.post_ataque(
				atacante, defensor,
				min(danyo, vida_antes), defensor_murio, "oponente"
			)

			print("[BotManager] Bot atacó '%s' con '%s' (%d daño)" % [
				defensor.nombre, atacante.nombre, danyo
			])
		else:
			# Ataque directo al jugador
			GameManager.atacar_jugador_directo("oponente", atacante.ataque_actual)
			AbilityManager.post_ataque(atacante, atacante, atacante.ataque_actual, false, "oponente")
			print("[BotManager] Bot atacó directamente al jugador (%d daño)" % atacante.ataque_actual)

		atacante.usada_este_turno = true
		await get_tree().create_timer(PAUSA_ENTRE_ACCIONES).timeout


# ═════════════════════════════════════════════
#  SELECCIÓN DE OBJETIVO ENEMIGO
# ═════════════════════════════════════════════

## Elige el monstruo del jugador con menos vida como objetivo
func _elegir_objetivo_enemigo() -> Card:
	var monstruos_jugador: Array = []
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == "jugador" and carta.tipo == Card.TIPO_MONSTRUO:
			monstruos_jugador.append(carta)
	if monstruos_jugador.is_empty():
		return null
	# Prioriza el monstruo con menos vida (más fácil de matar)
	var objetivo: Card = monstruos_jugador[0]
	for c in monstruos_jugador:
		if c.vida_actual < objetivo.vida_actual:
			objetivo = c
	return objetivo


# ═════════════════════════════════════════════
#  HELPERS DE CARTAS DEL OPONENTE
# ═════════════════════════════════════════════

func _get_monstruos_oponente() -> Array:
	var resultado: Array = []
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == "oponente" and carta.tipo == Card.TIPO_MONSTRUO:
			resultado.append(carta)
	return resultado


func _get_hechizos_oponente() -> Array:
	var resultado: Array = []
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == "oponente" and carta.tipo == Card.TIPO_HECHIZO:
			resultado.append(carta)
	return resultado


# ═════════════════════════════════════════════
#  LÓGICA DE DESPLIEGUE (sin cambios)
# ═════════════════════════════════════════════

func _intentar_colocar_carta() -> bool:
	var p: Dictionary = GameManager._get_jugador("oponente")
	var mana_disponible: int = p["mana_actual"]
	var candidatas: Array = []
	for carta in p["mano"]:
		var tipo:  int = int(carta.get("type",  carta.get("tipo",  -1)))
		var coste: int = int(carta.get("mana",  0))
		if coste > mana_disponible:
			continue
		match tipo:
			GameManager.TIPO_MONSTRUO:
				if p["monstruos"].size() >= GameManager.MAX_MONSTRUOS:
					continue
			GameManager.TIPO_EQUIPAMIENTO:
				if not p["equipamiento"].is_empty():
					continue
			GameManager.TIPO_HECHIZO:
				if p["hechizos"].size() >= GameManager.MAX_HECHIZOS:
					continue
			_:
				continue
		candidatas.append(carta)

	if candidatas.is_empty():
		return false

	var elegida: Dictionary = _seleccionar_mejor_carta(candidatas)
	if elegida.is_empty():
		return false

	var tipo: int = int(elegida.get("type", elegida.get("tipo", -1)))
	if tipo == GameManager.TIPO_MONSTRUO:
		var ok: bool = GameManager.desplegar_carta("oponente", elegida)
		if ok:
			_instanciar_visual_si_necesario(elegida)
			if GameManager.tiene_equipamiento("oponente"):
				GameManager._aplicar_buff_equip_a_monstruos("oponente")
			print("[BotManager] Bot desplegó: '%s'" % elegida.get("name", elegida.get("nombre","???")))
		return ok
	else:
		var ok: bool = GameManager.desplegar_carta("oponente", elegida)
		if ok:
			_instanciar_visual_si_necesario(elegida)
			print("[BotManager] Bot desplegó: '%s'" % elegida.get("name", elegida.get("nombre","???")))
		return ok


func _seleccionar_mejor_carta(candidatas: Array) -> Dictionary:
	var orden_tipo: Dictionary = {
		GameManager.TIPO_MONSTRUO:     0,
		GameManager.TIPO_EQUIPAMIENTO: 1,
		GameManager.TIPO_HECHIZO:      2,
	}
	var puntuadas: Array = []
	for carta in candidatas:
		var tipo:   int   = int(carta.get("type",    carta.get("tipo",   -1)))
		var coste:  int   = max(1, int(carta.get("mana", 0)))
		var atk:    int   = int(carta.get("attack",  carta.get("ataque_base",  0)))
		var vida:   int   = int(carta.get("defense", carta.get("defensa_base", 0)))
		var rareza: int   = int(carta.get("rarity",  carta.get("rareza", 1)))
		var puntuacion: float = float(atk + vida + 1) / float(coste)
		puntuadas.append({
			"carta": carta, "puntuacion": puntuacion,
			"rareza": rareza, "tipo_orden": orden_tipo.get(tipo, 99),
		})
	puntuadas.sort_custom(func(a, b):
		if a["puntuacion"] != b["puntuacion"]: return a["puntuacion"] > b["puntuacion"]
		if a["rareza"]     != b["rareza"]:     return a["rareza"]     > b["rareza"]
		if a["tipo_orden"] != b["tipo_orden"]: return a["tipo_orden"] < b["tipo_orden"]
		return false
	)
	var mejor: Dictionary = puntuadas[0]
	var empatadas: Array = []
	for entrada in puntuadas:
		if entrada["puntuacion"] == mejor["puntuacion"] \
		and entrada["rareza"]     == mejor["rareza"] \
		and entrada["tipo_orden"] == mejor["tipo_orden"]:
			empatadas.append(entrada)
	return empatadas[randi() % empatadas.size()]["carta"]


# ═════════════════════════════════════════════
#  INSTANCIACIÓN VISUAL
# ═════════════════════════════════════════════

func _instanciar_visual_si_necesario(carta_dict: Dictionary) -> void:
	var org: Node = _get_disponibles_oponente()
	if org == null:
		return
	var card_id: int = int(carta_dict.get("id", -1))
	for hijo in org.get_children():
		if hijo is Card and hijo.id == card_id:
			var tipo: int = int(carta_dict.get("type", carta_dict.get("tipo", -1)))
			var slot: Panel = _get_slot_libre_oponente(tipo)
			if slot == null:
				return
			org.remove_child(hijo)
			slot.add_child(hijo)
			hijo.layout_mode = 1
			hijo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hijo.mostrar_reverso = false
			hijo.add_to_group("desplegadas")
			# Conecta señal de muerte
			var game_ui: Node = _buscar_en_subarbol(get_tree().get_root(), "GameUI")
			if game_ui and game_ui.has_method("conectar_carta_muerta"):
				game_ui.conectar_carta_muerta(hijo)
			return


func _get_disponibles_oponente() -> Node:
	return _buscar_nodo_por_nombre(get_tree().get_root(), "DisponiblesOrganizador", "oponente")


func _buscar_nodo_por_nombre(nodo: Node, nombre: String, contexto: String) -> Node:
	for hijo in nodo.get_children():
		if hijo.name == "Oponente":
			return _buscar_en_subarbol(hijo, nombre)
		var resultado: Node = _buscar_nodo_por_nombre(hijo, nombre, contexto)
		if resultado:
			return resultado
	return null


func _buscar_en_subarbol(nodo: Node, nombre: String) -> Node:
	if nodo.name == nombre:
		return nodo
	for hijo in nodo.get_children():
		var r: Node = _buscar_en_subarbol(hijo, nombre)
		if r:
			return r
	return null


func _get_slot_libre_oponente(tipo: int) -> Panel:
	var oponente: Node = _buscar_hijo_directo(get_tree().get_root(), "Oponente")
	if oponente == null:
		return null
	var zona_nombre: String = ""
	match tipo:
		GameManager.TIPO_MONSTRUO:     zona_nombre = "DespliegueMonstruos"
		GameManager.TIPO_HECHIZO:      zona_nombre = "DespliegueHechizos"
		GameManager.TIPO_EQUIPAMIENTO: zona_nombre = "DespliegueEquipamiento"
		_: return null
	var zona: Node = _buscar_en_subarbol(oponente, zona_nombre)
	if zona == null:
		return null
	for hijo in zona.get_children():
		if hijo is Panel and _slot_vacio(hijo):
			return hijo
	return null


func _slot_vacio(slot: Panel) -> bool:
	for hijo in slot.get_children():
		if hijo is Control:
			return false
	return true


func _buscar_hijo_directo(nodo: Node, nombre: String) -> Node:
	for hijo in nodo.get_children():
		if hijo.name == nombre:
			return hijo
		var r: Node = _buscar_hijo_directo(hijo, nombre)
		if r:
			return r
	return null
