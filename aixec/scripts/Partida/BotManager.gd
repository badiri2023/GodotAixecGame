extends Node
# BotManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# SINGLETON — Project > Project Settings > AutoLoad > nombre: "BotManager"
#
# Gestiona la IA del oponente en modo singleplayer (GameManager.es_multijugador = false).
# Se activa automáticamente cuando el turno cambia a "oponente".
#
# FASE ACTUAL: solo despliega cartas según la lógica de prioridad definida.
# Atacar y usar habilidades se implementará en fases posteriores.
# ─────────────────────────────────────────────────────────────────────────────

# Pequeña pausa entre acciones del bot para que se vea natural (segundos)
const PAUSA_ENTRE_ACCIONES: float = 0.8
const PAUSA_FIN_TURNO:      float = 1.2


func _ready() -> void:
	GameManager.turno_cambiado.connect(_on_turno_cambiado)


# ═════════════════════════════════════════════
#  ENTRADA DE TURNO
# ═════════════════════════════════════════════

func _on_turno_cambiado(turno: String) -> void:
	if turno != "oponente":
		return
	if GameManager.es_multijugador:
		return   # en multijugador el oponente es humano, el bot no actúa
	if not GameManager.partida_activa:
		return

	# Pequeña pausa inicial antes de que el bot empiece a actuar
	await get_tree().create_timer(PAUSA_ENTRE_ACCIONES).timeout
	await _ejecutar_turno_bot()


# ═════════════════════════════════════════════
#  TURNO DEL BOT
# ═════════════════════════════════════════════

func _ejecutar_turno_bot() -> void:
	# Fase de despliegue: coloca cartas mientras tenga mana y cartas disponibles
	var siguio_colocando: bool = true
	while siguio_colocando and GameManager.partida_activa:
		siguio_colocando = await _intentar_colocar_carta()
		if siguio_colocando:
			await get_tree().create_timer(PAUSA_ENTRE_ACCIONES).timeout

	# TODO (fases siguientes): atacar con monstruos, usar habilidades

	# Fin de turno
	await get_tree().create_timer(PAUSA_FIN_TURNO).timeout
	if GameManager.partida_activa:
		GameManager.acabar_turno("oponente")


# ═════════════════════════════════════════════
#  LÓGICA DE DESPLIEGUE
# ═════════════════════════════════════════════

## Intenta colocar la carta de mayor prioridad que el bot pueda permitirse.
## Devuelve true si colocó una carta, false si no pudo colocar ninguna.
func _intentar_colocar_carta() -> bool:
	var p: Dictionary = GameManager._get_jugador("oponente")
	var mana_disponible: int = p["mana_actual"]

	# Filtra cartas que se pueden colocar: coste <= mana disponible
	# y que haya hueco en su zona correspondiente
	var candidatas: Array = []
	for carta in p["mano"]:
		var tipo:  int = int(carta.get("type",  carta.get("tipo",  -1)))
		var coste: int = int(carta.get("mana",  0))

		if coste > mana_disponible:
			continue

		# Comprueba si hay zona disponible para este tipo
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

	var ok: bool = GameManager.desplegar_carta("oponente", elegida)
	if ok:
		_instanciar_visual_si_necesario(elegida)
		print("[BotManager] Bot desplegó: '%s'" % elegida.get("name", elegida.get("nombre","???")))

	return ok


# ═════════════════════════════════════════════
#  ALGORITMO DE SELECCIÓN
# ═════════════════════════════════════════════

## Devuelve la carta con mayor puntuación siguiendo estas reglas:
##
## 1. Prioridad de tipo:  Monstruo(1) > Equipamiento(3) > Hechizo(2)
## 2. Puntuación:         (ataque + vida + 1) / mana    [+1 para hechizos sin stats]
## 3. Empate en puntuación: Legendario(3) > Raro(2) > Común(1)
## 4. Empate en rareza:   aleatorio
func _seleccionar_mejor_carta(candidatas: Array) -> Dictionary:
	# Criterios en orden:
	# 1. Puntuación más alta: (ataque + vida + 1) / mana
	# 2. Empate → mayor rareza (Legendario > Raro > Común)
	# 3. Empate → prioridad de tipo (Monstruo > Equipamiento > Hechizo)
	# 4. Empate total → aleatorio
	var orden_tipo: Dictionary = {
		GameManager.TIPO_MONSTRUO:     0,
		GameManager.TIPO_EQUIPAMIENTO: 1,
		GameManager.TIPO_HECHIZO:      2,
	}

	var puntuadas: Array = []
	for carta in candidatas:
		# int() necesario: el JSON devuelve floats (1.0, 2.0...)
		var tipo:   int   = int(carta.get("type",    carta.get("tipo",   -1)))
		var coste:  int   = max(1, int(carta.get("mana",    0)))
		var atk:    int   = int(carta.get("attack",  carta.get("ataque_base",  0)))
		var vida:   int   = int(carta.get("defense", carta.get("defensa_base", 0)))
		var rareza: int   = int(carta.get("rarity",  carta.get("rareza", 1)))
		var puntuacion: float = float(atk + vida + 1) / float(coste)

		puntuadas.append({
			"carta":      carta,
			"puntuacion": puntuacion,
			"rareza":     rareza,
			"tipo_orden": orden_tipo.get(tipo, 99),
		})

	# Orden: puntuación desc → rareza desc → tipo asc
	puntuadas.sort_custom(func(a, b):
		if a["puntuacion"] != b["puntuacion"]:
			return a["puntuacion"] > b["puntuacion"]
		if a["rareza"] != b["rareza"]:
			return a["rareza"] > b["rareza"]
		if a["tipo_orden"] != b["tipo_orden"]:
			return a["tipo_orden"] < b["tipo_orden"]
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
#  INSTANCIACIÓN VISUAL DEL SLOT DEL BOT
# ═════════════════════════════════════════════

## Cuando el bot despliega una carta, hay que moverla visualmente desde la
## mano del oponente al slot correspondiente.
## GameUI escucha carta_desplegada y debería encargarse, pero como el bot
## no hace drag & drop, notificamos a GameUI directamente.
func _instanciar_visual_si_necesario(carta_dict: Dictionary) -> void:
	# Busca el nodo Card de esta carta en el DisponiblesOrganizador del oponente
	var org: Node = _get_disponibles_oponente()
	if org == null:
		print("[BotManager] ERROR: DisponiblesOrganizador del oponente no encontrado")
		return

	var card_id: int = int(carta_dict.get("id", -1))
	for hijo in org.get_children():
		if hijo is Card and hijo.id == card_id:
			# Mueve el nodo al slot libre correspondiente
			var tipo: int = carta_dict.get("type", carta_dict.get("tipo", -1))
			var slot: Panel = _get_slot_libre_oponente(tipo)
			if slot == null:
				return
			org.remove_child(hijo)
			slot.add_child(hijo)
			hijo.layout_mode = 1
			hijo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hijo.mostrar_reverso = false   # en el campo se ve la carta
			hijo.add_to_group("desplegadas")
			return

	# Si el nodo no existe en la mano visual (puede pasar si el reverso
	# no se instanció), no hace nada — GameUI ya actualizará el log.


func _on_carta_enemiga_click(event: InputEvent, carta: Card) -> void:
	print("[BotManager] gui_input recibido en carta enemiga '%s' — evento: %s" % [carta.nombre, event.get_class()])
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	print("[BotManager] Click izquierdo en carta enemiga '%s' → seleccionando" % carta.nombre)
	SelectionManager.seleccionar_carta_enemiga(carta)


func _get_disponibles_oponente() -> Node:
	var raiz: Node = get_tree().get_root()
	# Busca por nombre de nodo — ajusta la ruta si tu escena difiere
	return _buscar_nodo_por_nombre(raiz, "DisponiblesOrganizador", "oponente")


func _buscar_nodo_por_nombre(nodo: Node, nombre: String, contexto: String) -> Node:
	# Sube hasta el nodo "Oponente" para no confundir con el del jugador
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
	var raiz:     Node  = get_tree().get_root()
	var oponente: Node  = _buscar_hijo_directo(raiz, "Oponente")
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

	# Devuelve el primer slot vacío
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


func _set_mouse_filter_recursivo(nodo: Node, filtro: int) -> void:
	for hijo in nodo.get_children():
		if hijo is Control:
			hijo.mouse_filter = filtro
		_set_mouse_filter_recursivo(hijo, filtro)
