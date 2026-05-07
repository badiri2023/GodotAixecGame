extends Control
# CardDragDrop.gd — adjunta al nodo raíz Control de Game.tscn
#
# Flujos de drag & drop:
#  [A] Monstruo / Hechizo  → slot vacío del tablero correspondiente
#  [B] Equipamiento        → SlotEquipamiento (único slot global)
#
# El equipamiento YA NO se arrastra sobre un monstruo concreto.
# Va al SlotEquipamiento y GameManager se encarga de bufear a todos
# los monstruos desplegados (y futuros) de ese jugador.


# ─────────────────────────────────────────────
#  ESTADO DEL DRAG
# ─────────────────────────────────────────────
var _dragging:           bool    = false
var _drag_card:          Control = null
var _drag_origin_parent: Node    = null
var _drag_origin_index:  int     = -1
var _drag_offset:        Vector2 = Vector2.ZERO
var _ghost:              Control = null


# ─────────────────────────────────────────────
#  REFERENCIAS A NODOS
# ─────────────────────────────────────────────
@onready var disponibles_organizador: HBoxContainer = \
	$Jugador/ManoJugador/DisponiblesPanel/DisponiblesOrganizador

@onready var slot_monstruos: Array = [
	$Jugador/DespliegueJugador/DespliegueMonstruos/SlotMonstruos1,
	$Jugador/DespliegueJugador/DespliegueMonstruos/SlotMonstruos2,
	$Jugador/DespliegueJugador/DespliegueMonstruos/SlotMonstruos3,
]

@onready var slot_hechizos: Array = [
	$Jugador/DespliegueJugador/DespliegueHechizos/SlotHechizos1,
	$Jugador/DespliegueJugador/DespliegueHechizos/SlotHechizos2,
	$Jugador/DespliegueJugador/DespliegueHechizos/SlotHechizos3,
]

# Slot único para el equipamiento global del jugador
@onready var slot_equipamiento: Panel = \
	$Jugador/DespliegueJugador/DespliegueEquipamiento/SlotEquipamiento


# ─────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────
func _ready() -> void:
	_connect_hand_cards()


func _connect_hand_cards() -> void:
	for carta in disponibles_organizador.get_children():
		_connect_card(carta)


func _connect_card(carta: Control) -> void:
	var panel: Panel = carta.get_node_or_null("Carta")
	if panel == null:
		push_warning("[CardDragDrop] Carta sin nodo 'Carta': %s" % carta.name)
		return
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not panel.gui_input.is_connected(_on_card_gui_input.bind(carta)):
		panel.gui_input.connect(_on_card_gui_input.bind(carta))


# ─────────────────────────────────────────────
#  EVENTOS DE ENTRADA
# ─────────────────────────────────────────────
func _on_card_gui_input(event: InputEvent, carta: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_drag(carta)


func _input(event: InputEvent) -> void:
	if not _dragging: return
	if event is InputEventMouseMotion:
		_update_ghost_position(event.global_position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(event.global_position)


# ─────────────────────────────────────────────
#  LÓGICA DE DRAG
# ─────────────────────────────────────────────
func _start_drag(carta: Control) -> void:
	if _dragging: return
	if not GameManager.es_mi_turno("jugador"):
		print("[CardDragDrop] No es tu turno")
		return

	_dragging           = true
	_drag_card          = carta
	_drag_origin_parent = carta.get_parent()
	_drag_origin_index  = carta.get_index()
	_drag_offset        = carta.global_position - get_viewport().get_mouse_position()
	_create_ghost(carta)


func _create_ghost(carta: Control) -> void:
	_ghost = carta.duplicate()
	_ghost.modulate.a   = 0.75
	_ghost.z_index      = 100
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_children_mouse_filter(_ghost, Control.MOUSE_FILTER_IGNORE)
	add_child(_ghost)
	_update_ghost_position(get_viewport().get_mouse_position())


func _set_children_mouse_filter(node: Node, filter: int) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = filter
		_set_children_mouse_filter(child, filter)


func _update_ghost_position(mouse_pos: Vector2) -> void:
	if _ghost:
		_ghost.global_position = mouse_pos + _drag_offset


func _end_drag(mouse_pos: Vector2) -> void:
	_dragging = false
	if _ghost:
		_ghost.queue_free()
		_ghost = null

	match _drag_card.tipo:
		Card.TIPO_MONSTRUO, Card.TIPO_HECHIZO:
			_intentar_despliegue(mouse_pos)
		Card.TIPO_EQUIPAMIENTO:
			_intentar_colocar_equipamiento(mouse_pos)
		_:
			_return_card_to_hand()

	_drag_card          = null
	_drag_origin_parent = null
	_drag_origin_index  = -1


# ─────────────────────────────────────────────
#  FLUJO A — DESPLIEGUE (monstruo / hechizo)
# ─────────────────────────────────────────────
func _intentar_despliegue(mouse_pos: Vector2) -> void:
	var slot_objetivo: Panel = _get_slot_vacio_bajo_mouse(mouse_pos, _drag_card.tipo)
	if slot_objetivo == null:
		print("[CardDragDrop] No hay slot válido y vacío bajo el cursor")
		_return_card_to_hand()
		return

	var datos_carta: Dictionary = _drag_card.get_datos_actuales()
	# Pasamos también el nodo para que GameManager aplique el buff de equipamiento
	var ok: bool = GameManager.desplegar_carta("jugador", datos_carta, _drag_card)
	if not ok:
		_return_card_to_hand()
		return

	_place_card_in_slot(_drag_card, slot_objetivo)

	# Notifica a AbilityManager del despliegue para habilidades pasivas
	AbilityManager.notificar_evento(AbilityManager.EVENTO_CARTA_DESPLEGADA, {
		"carta":       _drag_card,
		"propietario": "jugador"
	})


func _get_slot_vacio_bajo_mouse(mouse_pos: Vector2, tipo: int) -> Panel:
	var lista_slots: Array = []
	match tipo:
		Card.TIPO_MONSTRUO: lista_slots = slot_monstruos
		Card.TIPO_HECHIZO:  lista_slots = slot_hechizos

	for slot in lista_slots:
		if Rect2(slot.global_position, slot.size).has_point(mouse_pos) and _is_slot_empty(slot):
			return slot
	return null


func _is_slot_empty(slot: Panel) -> bool:
	for child in slot.get_children():
		if child is Control:
			return false
	return true


func _place_card_in_slot(carta: Control, slot: Panel) -> void:
	_drag_origin_parent.remove_child(carta)
	slot.add_child(carta)
	carta.layout_mode = 1
	carta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	print("[CardDragDrop] '%s' colocada en '%s'" % [carta.name, slot.name])


# ─────────────────────────────────────────────
#  FLUJO B — EQUIPAMIENTO → SlotEquipamiento
# ─────────────────────────────────────────────
func _intentar_colocar_equipamiento(mouse_pos: Vector2) -> void:
	# Comprueba que el cursor esté sobre el SlotEquipamiento
	var rect_slot := Rect2(slot_equipamiento.global_position, slot_equipamiento.size)
	if not rect_slot.has_point(mouse_pos):
		print("[CardDragDrop] Suelta el equipamiento en el SlotEquipamiento")
		_return_card_to_hand()
		return

	# Comprueba que el slot esté vacío
	if not _is_slot_empty(slot_equipamiento):
		print("[CardDragDrop] El SlotEquipamiento ya está ocupado")
		_return_card_to_hand()
		return

	var datos_carta: Dictionary = _drag_card.get_datos_actuales()

	# GameManager valida mana, slot libre y aplica el buff a todos los monstruos
	var ok: bool = GameManager.colocar_equipamiento("jugador", datos_carta)
	if not ok:
		_return_card_to_hand()
		return

	# Mueve el nodo visualmente al slot
	_place_card_in_slot(_drag_card, slot_equipamiento)

	# Notifica a AbilityManager por si el equipamiento tiene habilidad al equipar (hab 25)
	AbilityManager.notificar_equipamiento(_drag_card, _drag_card, "jugador")

	print("[CardDragDrop] Equipamiento '%s' colocado en slot global" % _drag_card.nombre)


# ─────────────────────────────────────────────
#  RETORNO A LA MANO
# ─────────────────────────────────────────────
func _return_card_to_hand() -> void:
	if _drag_card == null: return
	if _drag_card.get_parent() != _drag_origin_parent:
		_drag_origin_parent.add_child(_drag_card)
	_drag_origin_parent.move_child(_drag_card, _drag_origin_index)
	print("[CardDragDrop] '%s' devuelta a la mano" % _drag_card.name)
