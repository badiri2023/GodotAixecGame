extends Node
# SelectionManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# Adjunta este script a un nodo hijo "SelectionManager" dentro de la escena
# Game.tscn (hijo de Control, hermano de GameUI).
#
# Gestiona la selección de cartas propias y enemigas, el resaltado visual
# y la lógica de ataque al pulsar el botón.
#
# API pública usada desde CardDragDrop y BotManager:
#   SelectionManager.seleccionar_carta_propia(carta)
#   SelectionManager.seleccionar_carta_enemiga(carta)
#   SelectionManager.deseleccionar_todo()
# ─────────────────────────────────────────────────────────────────────────────


# ═════════════════════════════════════════════
#  SEÑALES
# ═════════════════════════════════════════════
## GameUI conecta esta señal para actualizar el estado de los botones
signal botones_actualizados(atacar_disabled: bool, habilidad_disabled: bool, nombre_habilidad: String)


# ═════════════════════════════════════════════
#  ESTADO
# ═════════════════════════════════════════════
var carta_seleccionada:        Card = null   # carta propia desplegada
var carta_enemiga_seleccionada: Card = null  # monstruo enemigo objetivo

var _estilo_seleccionada: StyleBoxFlat = null   # borde amarillo
var _estilo_enemiga:      StyleBoxFlat = null   # borde rojo



# ═════════════════════════════════════════════
#  INICIALIZACIÓN
# ═════════════════════════════════════════════
func _ready() -> void:
	_inicializar_estilos()
	GameManager.turno_cambiado.connect(_on_turno_cambiado)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not (event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if not GameManager.partida_activa or not GameManager.es_mi_turno("jugador"):
		return

	var mouse_pos: Vector2 = event.global_position

	# Busca si hay una carta bajo el cursor en el grupo "desplegadas"
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if not carta is Card:
			continue
		# Usa la Hitbox si existe, si no usa el rect de la carta
		var hitbox: Control = carta.get_node_or_null("Hitbox")
		var rect: Rect2
		if hitbox:
			rect = Rect2(hitbox.global_position, hitbox.size)
		else:
			rect = Rect2(carta.global_position, carta.size)
		if not rect.has_point(mouse_pos):
			continue
		# Carta encontrada bajo el cursor
		if carta.propietario == "jugador":
			if not GameManager.solo_despliegue:
				seleccionar_carta_propia(carta)
		else:
			if not GameManager.solo_despliegue:
				seleccionar_carta_enemiga(carta)
		get_viewport().set_input_as_handled()
		return


func _inicializar_estilos() -> void:
	_estilo_seleccionada = StyleBoxFlat.new()
	_estilo_seleccionada.border_color        = Color(1.0, 0.85, 0.0, 1.0)   # amarillo
	_estilo_seleccionada.border_width_left   = 4
	_estilo_seleccionada.border_width_right  = 4
	_estilo_seleccionada.border_width_top    = 4
	_estilo_seleccionada.border_width_bottom = 4
	_estilo_seleccionada.bg_color            = Color(0, 0, 0, 0)
	_estilo_seleccionada.draw_center         = false

	_estilo_enemiga = StyleBoxFlat.new()
	_estilo_enemiga.border_color             = Color(1.0, 0.85, 0.0, 1.0)  # amarillo (igual que propia)
	_estilo_enemiga.border_width_left        = 4
	_estilo_enemiga.border_width_right       = 4
	_estilo_enemiga.border_width_top         = 4
	_estilo_enemiga.border_width_bottom      = 4
	_estilo_enemiga.bg_color                 = Color(0, 0, 0, 0)
	_estilo_enemiga.draw_center              = false


# ═════════════════════════════════════════════
#  SELECCIÓN
# ═════════════════════════════════════════════

## Selecciona una carta propia desplegada (borde amarillo).
## Toggle: si se pulsa la misma carta dos veces, se deselecciona.
func seleccionar_carta_propia(carta: Card) -> void:
	if not GameManager.es_mi_turno("jugador") or GameManager.solo_despliegue:
		return
	if carta_seleccionada == carta:
		_deseleccionar_propia()
		return
	_deseleccionar_propia()
	carta_seleccionada = carta
	_aplicar_resaltado(carta, _estilo_seleccionada)
	_actualizar_botones()


## Selecciona una carta enemiga monstruo como objetivo (borde rojo).
## Toggle: si se pulsa la misma carta dos veces, se deselecciona.
func seleccionar_carta_enemiga(carta: Card) -> void:
	if not GameManager.es_mi_turno("jugador") or GameManager.solo_despliegue:
		return
	if carta.tipo != Card.TIPO_MONSTRUO:
		return
	if carta_enemiga_seleccionada == carta:
		_deseleccionar_enemiga()
		return
	_deseleccionar_enemiga()
	carta_enemiga_seleccionada = carta
	_aplicar_resaltado(carta, _estilo_enemiga)


func _deseleccionar_propia() -> void:
	if carta_seleccionada:
		_quitar_resaltado(carta_seleccionada)
		carta_seleccionada = null
		_actualizar_botones()


func _deseleccionar_enemiga() -> void:
	if carta_enemiga_seleccionada:
		_quitar_resaltado(carta_enemiga_seleccionada)
		carta_enemiga_seleccionada = null


func deseleccionar_todo() -> void:
	_deseleccionar_propia()
	_deseleccionar_enemiga()


# ═════════════════════════════════════════════
#  RESALTADO VISUAL
# ═════════════════════════════════════════════
func _aplicar_resaltado(carta: Card, estilo: StyleBoxFlat) -> void:
	var panel: Panel = carta.get_node_or_null("Carta")
	if panel:
		panel.add_theme_stylebox_override("panel", estilo)


func _quitar_resaltado(carta: Card) -> void:
	var panel: Panel = carta.get_node_or_null("Carta")
	if panel:
		panel.remove_theme_stylebox_override("panel")
		# Restaura el color de tipo de la carta (rojo/azul/verde)
		if carta.has_method("restaurar_color_fondo"):
			carta.restaurar_color_fondo()


# ═════════════════════════════════════════════
#  ATAQUE
# ═════════════════════════════════════════════

## Ejecuta el ataque de la carta propia seleccionada.
## Llamado desde GameUI al pulsar el botón Atacar.
func ejecutar_ataque() -> String:
	if carta_seleccionada == null:
		return "Selecciona una de tus cartas monstruo para atacar"
	if carta_seleccionada.tipo != Card.TIPO_MONSTRUO:
		return "Solo los monstruos pueden atacar"
	if carta_seleccionada.usada_este_turno:
		return "Esta carta ya actuó este turno"

	var p_enemigo: Dictionary = GameManager._get_jugador("oponente")
	var tiene_monstruos: bool = not p_enemigo["monstruos"].is_empty()

	if tiene_monstruos and carta_enemiga_seleccionada == null:
		return "El enemigo tiene monstruos. Selecciona uno como objetivo"

	var danyo: int = carta_seleccionada.ataque_actual
	var msg: String = ""

	if tiene_monstruos:
		# Aplica el daño directamente al nodo Card enemigo
		var vida_antes: int = carta_enemiga_seleccionada.vida_actual
		carta_enemiga_seleccionada.recibir_danyo(danyo)
		var danyo_real: int = min(danyo, vida_antes)
		var sobrante:   int = danyo - danyo_real

		msg = "Jugador atacó '%s' con '%s' (%d daño)" % [
			carta_enemiga_seleccionada.nombre,
			carta_seleccionada.nombre,
			danyo
		]

		# Si la carta murió (vida <= 0), enviarla al cementerio y aplicar sobrante
		if carta_enemiga_seleccionada.vida_actual <= 0:
			_gestionar_muerte_carta(carta_enemiga_seleccionada, "oponente", sobrante)
	else:
		# Ataque directo al jugador enemigo
		GameManager.aplicar_danyo("oponente", danyo)
		msg = "Jugador atacó directamente al Oponente (%d daño)" % danyo

	carta_seleccionada.marcar_como_usada()
	deseleccionar_todo()
	return msg


## Gestiona la muerte de una carta: la envía al cementerio y aplica el daño sobrante.
func _gestionar_muerte_carta(carta: Card, propietario: String, danyo_sobrante: int) -> void:
	var origen: String = "monstruos" if carta.tipo == Card.TIPO_MONSTRUO else "hechizos"
	var datos: Dictionary = carta.get_datos_actuales()

	# Sincroniza vida_actual en el dict antes de enviarlo
	datos["vida_actual"] = carta.vida_actual

	# Actualiza el dict en GameManager para que enviar_al_cementerio encuentre la carta
	var p: Dictionary = GameManager._get_jugador(propietario)
	var carta_en_gm: Dictionary = GameManager._buscar_en_mano_por_id(p[origen], datos)
	if not carta_en_gm.is_empty():
		GameManager.enviar_al_cementerio(propietario, carta_en_gm, origen)

	# Quita el nodo de la escena visualmente (GameUI lo pondrá en el cementerio via señal)
	carta.remove_from_group("desplegadas")

	# Daño sobrante al jugador dueño de la carta muerta
	if danyo_sobrante > 0:
		GameManager.aplicar_danyo(propietario, danyo_sobrante)


# ═════════════════════════════════════════════
#  BOTONES (actualiza los de GameUI)
# ═════════════════════════════════════════════
func _actualizar_botones() -> void:
	var puede_combatir: bool   = GameManager.es_mi_turno("jugador") and not GameManager.solo_despliegue
	var hay_carta: bool        = carta_seleccionada != null
	var es_monstruo: bool      = hay_carta and carta_seleccionada.tipo == Card.TIPO_MONSTRUO
	var no_usada: bool         = hay_carta and not carta_seleccionada.usada_este_turno
	var tiene_hab_activa: bool = hay_carta \
		and not carta_seleccionada.habilidad_es_pasiva \
		and carta_seleccionada.habilidad_id >= 0

	var atacar_dis: bool    = not (puede_combatir and es_monstruo and no_usada)
	var habilidad_dis: bool = not (puede_combatir and hay_carta and no_usada and tiene_hab_activa)
	var nombre_hab: String  = ""
	if hay_carta and tiene_hab_activa:
		nombre_hab = carta_seleccionada.habilidad_nombre
	emit_signal("botones_actualizados", atacar_dis, habilidad_dis, nombre_hab)


# ═════════════════════════════════════════════
#  SEÑALES
# ═════════════════════════════════════════════
func _on_turno_cambiado(turno: String) -> void:
	deseleccionar_todo()
	# Resetea usada_este_turno en las cartas del jugador activo
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == turno:
			carta.resetear_turno()
	_actualizar_botones()
