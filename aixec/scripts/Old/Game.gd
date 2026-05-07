extends Control

# ═══════════════════════════════════════════════════════
#  BASE DE DATOS DE CARTAS
# ═══════════════════════════════════════════════════════
var _cartas_db : Array = []

func _cargar_json():
	var file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if not file:
		push_error("Game: No se pudo abrir cards.json")
		return
	var json  = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("Game: Error parseando cards.json: " + json.get_error_message())
		return
	_cartas_db = json.get_data()
	print("Game: %d cartas cargadas." % _cartas_db.size())

func _get_carta_por_id(id: int) -> Dictionary:
	for carta in _cartas_db:
		if carta["id"] == id:
			return carta.duplicate(true)
	push_warning("Game: Carta id %d no encontrada." % id)
	return {}

func _get_mazo_barajado() -> Array:
	if _cartas_db.is_empty():
		return []
	var pool = _cartas_db.duplicate(true)
	pool.shuffle()
	var mazo : Array = []
	while mazo.size() < 20:
		for carta in pool:
			if mazo.size() >= 20:
				break
			mazo.append(carta.duplicate(true))
	return mazo

# ═══════════════════════════════════════════════════════
#  REFERENCIAS UI — INFO
# ═══════════════════════════════════════════════════════
@onready var duracion_label        : Label  = $Info/InfoPartida/DuracionLabel
@onready var ronda_label           : Label  = $Info/InfoPartida/RondaLabel
@onready var turno_label           : Label  = $Info/InfoPartida/TurnoLabel
@onready var tiempo_restante_label : Label  = $Info/TiempoRestante/DuracionLabel
@onready var btn_reportar          : Button = $Info/Reportar

# ═══════════════════════════════════════════════════════
#  REFERENCIAS UI — JUGADOR
# ═══════════════════════════════════════════════════════
@onready var jugador_nombre_label : Label       = $Jugador/InfoJugador/NombreLabel
@onready var jugador_vida_label   : Label       = $Jugador/InfoJugador/VidaLabel
@onready var jugador_vida_bar     : ProgressBar = $Jugador/InfoJugador/VidaBar
@onready var jugador_mana_label   : Label       = $Jugador/InfoJugador/ManaLabel
@onready var jugador_mana_bar     : ProgressBar = $Jugador/InfoJugador/ManaBar

@onready var jugador_cartas_baraja : HBoxContainer = $Jugador/ManoJugador/CartasBaraja
@onready var jugador_disponibles   : HBoxContainer = $Jugador/ManoJugador/DisponiblesPanel/DisponiblesOrganizador

@onready var jugador_slot_monstruos : Array[Panel] = [
	$Jugador/DespliegueJugador/DespliegueMonstruos/SlotMonstruos1,
	$Jugador/DespliegueJugador/DespliegueMonstruos/SlotMonstruos2,
	$Jugador/DespliegueJugador/DespliegueMonstruos/SlotMonstruos3,
]
@onready var jugador_slot_hechizos : Array[Panel] = [
	$Jugador/DespliegueJugador/DespliegueHechizos/SlotHechizos1,
	$Jugador/DespliegueJugador/DespliegueHechizos/SlotHechizos2,
	$Jugador/DespliegueJugador/DespliegueHechizos/SlotHechizos3,
]

@onready var btn_atacar         : Button = $Jugador/DespliegueJugador/DespliegueMonstruos/BotonAtaque
@onready var btn_hab_propia_m   : Button = $Jugador/DespliegueJugador/DespliegueMonstruos/BotonHabilidadPropia
@onready var btn_hab_equip      : Button = $Jugador/DespliegueJugador/DespliegueMonstruos/BotonHabilidadEquipamiento
@onready var feedback_monstruos : Label  = $Jugador/DespliegueJugador/DespliegueMonstruos/FeedbackLabel
@onready var btn_hab_propia_h   : Button = $Jugador/DespliegueJugador/DespliegueHechizos/BotonHabilidadPropia
@onready var feedback_hechizos  : Label  = $Jugador/DespliegueJugador/DespliegueHechizos/FeedbackLabel

@onready var jugador_cementerio : HBoxContainer = $Jugador/MuertosJugador/CartasCementerio

# ═══════════════════════════════════════════════════════
#  REFERENCIAS UI — OPONENTE
# ═══════════════════════════════════════════════════════
@onready var oponente_nombre_label : Label       = $Oponente/InfoOponente/NombreLabel
@onready var oponente_vida_label   : Label       = $Oponente/InfoOponente/VidaLabel
@onready var oponente_vida_bar     : ProgressBar = $Oponente/InfoOponente/VidaBar
@onready var oponente_mana_label   : Label       = $Oponente/InfoOponente/ManaLabel
@onready var oponente_mana_bar     : ProgressBar = $Oponente/InfoOponente/ManaBar

@onready var oponente_cartas_baraja : HBoxContainer = $Oponente/ManoOponente/CartasBaraja
@onready var oponente_disponibles   : HBoxContainer = $Oponente/ManoOponente/DisponiblesPanel/DisponiblesOrganizador

@onready var oponente_slot_monstruos : Array[Panel] = [
	$Oponente/DespliegueOponente/DespliegueMonstruos/SlotMonstruos1,
	$Oponente/DespliegueOponente/DespliegueMonstruos/SlotMonstruos2,
	$Oponente/DespliegueOponente/DespliegueMonstruos/SlotMonstruos3,
]
@onready var oponente_slot_hechizos : Array[Panel] = [
	$Oponente/DespliegueOponente/DespliegueHechizos/SlotHechizos1,
	$Oponente/DespliegueOponente/DespliegueHechizos/SlotHechizos2,
	$Oponente/DespliegueOponente/DespliegueHechizos/SlotHechizos3,
]

@onready var oponente_cementerio : HBoxContainer = $Oponente/MuertosOponente/CartasCementerio

# ═══════════════════════════════════════════════════════
#  CONSTANTES VISUALES
# ═══════════════════════════════════════════════════════
const SOMBRA_VACIO  := Color(0.15, 0.15, 0.15, 1.0)
const SOMBRA_VERDE  := Color(0.0,  0.8,  0.0,  1.0)
const SOMBRA_ROJA   := Color(0.8,  0.0,  0.0,  1.0)
const SOMBRA_MORADA := Color(0.6,  0.0,  0.8,  1.0)

const CardScene        = preload("res://scenes/Card.tscn")
const CardReverseScene = preload("res://scenes/CardReverse.tscn")

# ═══════════════════════════════════════════════════════
#  ESTADO LOCAL
# ═══════════════════════════════════════════════════════
var id_jugador_local : int = 1

var slot_seleccionado_jugador      : int    = -1
var slot_seleccionado_tipo         : String = ""
var slot_seleccionado_enemigo      : int    = -1
var slot_seleccionado_tipo_enemigo : String = ""

var slots_monstruos_jugador : Array = [null, null, null]
var slots_hechizos_jugador  : Array = [null, null, null]
var slots_monstruos_enemigo : Array = [null, null, null]
var slots_hechizos_enemigo  : Array = [null, null, null]

var mano_jugador : Array = []
var mano_enemigo : Array = []
var mazo_jugador : Array = []
var mazo_enemigo : Array = []

var slots_ligamento       : Dictionary = {}
var ataque_base_paciencia : Dictionary = {}
var efectos_activos       : Dictionary = {}

var segundos_turno    : int  = 0
var segundos_duracion : int  = 0
var afk_visible       : bool = false
var afk_contador      : Dictionary = {1: 0, 2: 0}

var timer_turno    : Timer
var timer_duracion : Timer

# ═══════════════════════════════════════════════════════
#  INICIALIZACIÓN
# ═══════════════════════════════════════════════════════
func _ready():
	_cargar_json()
	_setup_timers()
	_conectar_botones()
	_iniciar_partida()

func _setup_timers():
	timer_turno = Timer.new()
	timer_turno.wait_time = 1.0
	timer_turno.timeout.connect(_on_tick_turno)
	add_child(timer_turno)

	timer_duracion = Timer.new()
	timer_duracion.wait_time = 1.0
	timer_duracion.timeout.connect(_on_tick_duracion)
	add_child(timer_duracion)

func _conectar_botones():
	btn_atacar.pressed.connect(_on_btn_atacar)
	btn_hab_propia_m.pressed.connect(_on_btn_habilidad_propia_monstruo)
	btn_hab_equip.pressed.connect(_on_btn_habilidad_equip)
	btn_hab_propia_h.pressed.connect(_on_btn_habilidad_propia_hechizo)
	btn_reportar.pressed.connect(_on_btn_reportar)
	btn_reportar.visible = false

	# Slots — usan Slot.gd con señal slot_clickado
	for i in range(3):
		jugador_slot_monstruos[i].slot_clickado.connect(_on_slot_clickado)
		jugador_slot_hechizos[i].slot_clickado.connect(_on_slot_clickado)
		oponente_slot_monstruos[i].slot_clickado.connect(_on_slot_clickado)
		oponente_slot_hechizos[i].slot_clickado.connect(_on_slot_clickado)

	_actualizar_visibilidad_botones()

# ═══════════════════════════════════════════════════════
#  INICIO DE PARTIDA
# ═══════════════════════════════════════════════════════
func _iniciar_partida():
	mazo_jugador = _get_mazo_barajado()
	mazo_enemigo = _get_mazo_barajado()

	for i in range(GameState.CARTAS_INICIALES):
		robar_carta(1)
		robar_carta(2)

	var prioridad = GameState.lanzar_moneda()
	_mostrar_feedback("¡%s tiene la prioridad!" % GameState.jugadores[prioridad]["nombre"])
	await get_tree().create_timer(2.0).timeout
	_iniciar_turno(GameState.jugador_prioridad)
	timer_duracion.start()

# ═══════════════════════════════════════════════════════
#  TURNOS Y RONDAS
# ═══════════════════════════════════════════════════════
func _iniciar_turno(id_jugador: int):
	GameState.turno_jugador = id_jugador
	segundos_turno = 0
	afk_visible    = false
	btn_reportar.visible = false
	timer_turno.start()

	_procesar_efectos_turno(id_jugador)

	var slots_m = slots_monstruos_jugador if id_jugador == id_jugador_local else slots_monstruos_enemigo
	for carta in slots_m:
		if carta != null:
			carta.resetear_turno()
			# Paciencia (14): si no atacó el turno anterior, +1 ataque
			if ataque_base_paciencia.has(carta) and carta.puede_actuar:
				carta.card_data["attack"] += 1
				carta.actualizar_ui()

	_actualizar_ui_completa()
	_actualizar_visibilidad_botones()
	_mostrar_feedback("Turno de %s." % GameState.jugadores[id_jugador]["nombre"])

func _terminar_turno():
	timer_turno.stop()
	_deseleccionar_todo()
	var id_actual = GameState.turno_jugador
	if id_actual == GameState.jugador_prioridad:
		_iniciar_turno(GameState.get_enemigo(id_actual))
	else:
		_nueva_ronda()

func _nueva_ronda():
	GameState.nueva_ronda()
	robar_carta(1)
	robar_carta(2)
	_actualizar_ui_completa()
	_iniciar_turno(GameState.jugador_prioridad)

# ═══════════════════════════════════════════════════════
#  ROBAR CARTA
# ═══════════════════════════════════════════════════════
func robar_carta(id_jugador: int):
	var mazo = mazo_jugador if id_jugador == id_jugador_local else mazo_enemigo
	if mazo.is_empty():
		return
	var datos = mazo.pop_front()
	var carta = CardScene.instantiate()
	carta.carta_muerta.connect(_on_carta_muerta.bind(id_jugador))

	if id_jugador == id_jugador_local:
		jugador_disponibles.add_child(carta)
		carta.inicializar(datos)
		carta.ocultar_reverso()
		carta.carta_arrastrada.connect(_on_carta_arrastrada)
		mano_jugador.append(carta)
		GameState.jugadores[id_jugador]["mano"].append(carta)
	else:
		oponente_disponibles.add_child(carta)
		carta.inicializar(datos)
		carta.mostrar_reverso()
		mano_enemigo.append(carta)
		GameState.jugadores[id_jugador]["mano"].append(carta)

	_actualizar_cartas_baraja_visual(id_jugador)

func _actualizar_cartas_baraja_visual(id_jugador: int):
	var contenedor = jugador_cartas_baraja if id_jugador == id_jugador_local else oponente_cartas_baraja
	for hijo in contenedor.get_children():
		if hijo.visible:
			hijo.visible = false
			break

# ═══════════════════════════════════════════════════════
#  ARRASTRE — soltar carta sobre slot
# ═══════════════════════════════════════════════════════
func _on_carta_arrastrada(carta):
	if GameState.turno_jugador != id_jugador_local:
		# No es el turno — devolver a disponibles
		if carta.get_parent() != jugador_disponibles:
			if carta.get_parent() != null:
				carta.get_parent().remove_child(carta)
			jugador_disponibles.add_child(carta)
		_mostrar_feedback("No es tu turno.")
		return

	var pos_raton     = get_global_mouse_position()
	var slot_encontrado = false

	for i in range(3):
		if _punto_dentro_de_nodo(pos_raton, jugador_slot_monstruos[i]):
			_intentar_desplegar(carta, i, "monstruo")
			slot_encontrado = true
			break
		if _punto_dentro_de_nodo(pos_raton, jugador_slot_hechizos[i]):
			_intentar_desplegar(carta, i, "hechizo")
			slot_encontrado = true
			break

	if not slot_encontrado:
		# Soltar fuera de un slot — devolver a disponibles
		if carta.get_parent() != jugador_disponibles:
			if carta.get_parent() != null:
				carta.get_parent().remove_child(carta)
			jugador_disponibles.add_child(carta)
		_mostrar_feedback("Suelta la carta en un slot válido.")

func _punto_dentro_de_nodo(punto: Vector2, nodo: Control) -> bool:
	var rect = Rect2(nodo.global_position, nodo.size)
	return rect.has_point(punto)

# ═══════════════════════════════════════════════════════
#  SLOTS — click
# ═══════════════════════════════════════════════════════
func _on_slot_clickado(slot):
	if slot.es_enemigo:
		_seleccionar_slot_enemigo(slot.indice, slot.tipo)
	else:
		_seleccionar_slot_jugador(slot.indice, slot.tipo)

# ═══════════════════════════════════════════════════════
#  DESPLIEGUE
# ═══════════════════════════════════════════════════════
func _intentar_desplegar(carta, idx: int, tipo_slot: String):
	var tipo_carta = carta.card_data["type"]

	# Validar compatibilidad tipo carta — tipo slot
	if tipo_carta == GameState.TIPO_MONSTRUO and tipo_slot != "monstruo":
		_devolver_carta_a_mano(carta)
		_mostrar_feedback("Los monstruos van en la zona de monstruos.")
		return
	if tipo_carta == GameState.TIPO_HECHIZO and tipo_slot != "hechizo":
		_devolver_carta_a_mano(carta)
		_mostrar_feedback("Los hechizos van en la zona de hechizos.")
		return
	if tipo_carta == GameState.TIPO_EQUIPAMIENTO:
		if tipo_slot != "monstruo":
			_devolver_carta_a_mano(carta)
			_mostrar_feedback("Arrastra el equipamiento sobre un monstruo aliado.")
			return
		var objetivo = slots_monstruos_jugador[idx]
		if objetivo == null:
			_devolver_carta_a_mano(carta)
			_mostrar_feedback("No hay monstruo en ese slot.")
			return
		_desplegar_equipamiento(carta, objetivo)
		return

	var slots = slots_monstruos_jugador if tipo_slot == "monstruo" else slots_hechizos_jugador
	if slots[idx] != null:
		_devolver_carta_a_mano(carta)
		_mostrar_feedback("Ese slot ya está ocupado.")
		return
	if not GameState.gastar_mana(id_jugador_local, carta.get_mana_cost()):
		_devolver_carta_a_mano(carta)
		_mostrar_feedback("No tienes suficiente mana.")
		return

	# Quitar de la lista de mano
	mano_jugador.erase(carta)
	GameState.jugadores[id_jugador_local]["mano"].erase(carta)

	# La carta viene de la escena raíz (fue sacada por el arrastre)
	# Reasignarla al slot
	if carta.get_parent() != null:
		carta.get_parent().remove_child(carta)
	var slot_panel = jugador_slot_monstruos[idx] if tipo_slot == "monstruo" else jugador_slot_hechizos[idx]
	slot_panel.add_child(carta)
	_ajustar_carta_al_slot(carta, slot_panel)
	carta.esta_desplegada = true
	carta.arrastrando     = false

	if tipo_slot == "monstruo":
		slots_monstruos_jugador[idx] = carta
		GameState.jugadores[id_jugador_local]["monstruos"].append(carta)
		if carta.get_ability_id() == 14:
			ataque_base_paciencia[carta] = carta.card_data["attack"]
	else:
		slots_hechizos_jugador[idx] = carta
		GameState.jugadores[id_jugador_local]["hechizos"].append(carta)

	_aplicar_sombra_slot(slot_panel, SOMBRA_VACIO)
	_on_carta_entra_al_campo(carta, id_jugador_local)
	_actualizar_ui_completa()
	_mostrar_feedback("%s desplegado." % carta.card_data["name"])

func _devolver_carta_a_mano(carta):
	if carta.get_parent() != null:
		carta.get_parent().remove_child(carta)
	jugador_disponibles.add_child(carta)
	carta.arrastrando = false

func _desplegar_equipamiento(carta_equip, carta_monstruo):
	if not GameState.gastar_mana(id_jugador_local, carta_equip.get_mana_cost()):
		_devolver_carta_a_mano(carta_equip)
		_mostrar_feedback("No tienes suficiente mana.")
		return
	if not carta_monstruo.equipar(carta_equip):
		_devolver_carta_a_mano(carta_equip)
		_mostrar_feedback("Ese monstruo ya tiene equipamiento.")
		GameState.devolver_mana(id_jugador_local, carta_equip.get_mana_cost())
		return

	mano_jugador.erase(carta_equip)
	GameState.jugadores[id_jugador_local]["mano"].erase(carta_equip)
	# El equipamiento desaparece visualmente (sus stats se suman al monstruo)
	if carta_equip.get_parent() != null:
		carta_equip.get_parent().remove_child(carta_equip)

	if carta_equip.card_data["ability"]["id"] == 25:
		_habilidad_25(carta_monstruo)

	_actualizar_ui_completa()
	_actualizar_visibilidad_botones()
	_mostrar_feedback("%s equipado a %s." % [carta_equip.card_data["name"], carta_monstruo.card_data["name"]])

func _ajustar_carta_al_slot(carta, slot: Panel):
	carta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ═══════════════════════════════════════════════════════
#  SELECCIÓN DE SLOTS
# ═══════════════════════════════════════════════════════
func _seleccionar_slot_jugador(idx: int, tipo: String):
	var slots = slots_monstruos_jugador if tipo == "monstruo" else slots_hechizos_jugador
	if slots[idx] == null:
		return
	_deseleccionar_todo()
	slot_seleccionado_jugador = idx
	slot_seleccionado_tipo    = tipo
	var sp = jugador_slot_monstruos[idx] if tipo == "monstruo" else jugador_slot_hechizos[idx]
	_aplicar_sombra_slot(sp, SOMBRA_VERDE)
	_actualizar_visibilidad_botones()

func _seleccionar_slot_enemigo(idx: int, tipo: String):
	var slots = slots_monstruos_enemigo if tipo == "monstruo" else slots_hechizos_enemigo
	if slots[idx] == null:
		return
	_limpiar_sombras_enemigas()
	slot_seleccionado_enemigo      = idx
	slot_seleccionado_tipo_enemigo = tipo
	var sp = oponente_slot_monstruos[idx] if tipo == "monstruo" else oponente_slot_hechizos[idx]
	_aplicar_sombra_slot(sp, SOMBRA_ROJA)

func _deseleccionar_todo():
	if slot_seleccionado_jugador != -1:
		var sp = jugador_slot_monstruos[slot_seleccionado_jugador] if slot_seleccionado_tipo == "monstruo" \
				 else jugador_slot_hechizos[slot_seleccionado_jugador]
		if not slots_ligamento.has(sp):
			_aplicar_sombra_slot(sp, SOMBRA_VACIO)
	slot_seleccionado_jugador = -1
	slot_seleccionado_tipo    = ""
	_limpiar_sombras_enemigas()
	_actualizar_visibilidad_botones()

func _limpiar_sombras_enemigas():
	if slot_seleccionado_enemigo != -1:
		var sp = oponente_slot_monstruos[slot_seleccionado_enemigo] if slot_seleccionado_tipo_enemigo == "monstruo" \
				 else oponente_slot_hechizos[slot_seleccionado_enemigo]
		_aplicar_sombra_slot(sp, SOMBRA_VACIO)
	slot_seleccionado_enemigo      = -1
	slot_seleccionado_tipo_enemigo = ""

# ═══════════════════════════════════════════════════════
#  SOMBRAS
# ═══════════════════════════════════════════════════════
func _aplicar_sombra_slot(slot: Panel, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color               = Color(0.1, 0.1, 0.1, 1.0)
	style.shadow_color           = color
	style.shadow_size            = 6 if color != SOMBRA_VACIO else 0
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)

# ═══════════════════════════════════════════════════════
#  BOTONES DE ACCIÓN
# ═══════════════════════════════════════════════════════
func _actualizar_visibilidad_botones():
	var es_mi_turno = GameState.turno_jugador == id_jugador_local
	var no_primera  = not GameState.es_primera_ronda()
	var carta_m     = _get_carta_monstruo_seleccionada()
	var carta_h     = _get_carta_hechizo_seleccionada()

	btn_atacar.visible       = es_mi_turno and no_primera and carta_m != null and carta_m.puede_actuar
	btn_hab_propia_m.visible = es_mi_turno and no_primera and carta_m != null \
							   and carta_m.tiene_habilidad_activa_propia() and carta_m.puede_actuar
	btn_hab_equip.visible    = es_mi_turno and no_primera and carta_m != null \
							   and carta_m.tiene_habilidad_activa_equip() and carta_m.puede_actuar
	btn_hab_propia_h.visible = es_mi_turno and no_primera and carta_h != null \
							   and carta_h.tiene_habilidad_activa_propia() and carta_h.puede_actuar

	if carta_m != null:
		btn_hab_propia_m.text = carta_m.get_ability_name() if carta_m.tiene_habilidad_activa_propia() else "Hab. Propia"
		btn_hab_equip.text    = carta_m.get_equip_ability_name() if carta_m.tiene_habilidad_activa_equip() else "Hab. Equip"
	if carta_h != null:
		btn_hab_propia_h.text = carta_h.get_ability_name() if carta_h.tiene_habilidad_activa_propia() else "Hab. Propia"

func _get_carta_monstruo_seleccionada():
	if slot_seleccionado_jugador == -1 or slot_seleccionado_tipo != "monstruo":
		return null
	return slots_monstruos_jugador[slot_seleccionado_jugador]

func _get_carta_hechizo_seleccionada():
	if slot_seleccionado_jugador == -1 or slot_seleccionado_tipo != "hechizo":
		return null
	return slots_hechizos_jugador[slot_seleccionado_jugador]

# ═══════════════════════════════════════════════════════
#  ATACAR
# ═══════════════════════════════════════════════════════
func _on_btn_atacar():
	if GameState.es_primera_ronda():
		_mostrar_feedback("No puedes atacar en la primera ronda.")
		return
	var carta = _get_carta_monstruo_seleccionada()
	if carta == null:
		_mostrar_feedback("Selecciona uno de tus monstruos primero.")
		return
	if not carta.puede_actuar:
		_mostrar_feedback("Esta carta ya actuó este turno.")
		return

	var id_enemigo    = GameState.get_enemigo(id_jugador_local)
	var hay_monstruos = slots_monstruos_enemigo.any(func(c): return c != null)

	if hay_monstruos:
		if slot_seleccionado_enemigo == -1 or slot_seleccionado_tipo_enemigo != "monstruo":
			_mostrar_feedback("Debes seleccionar una carta enemiga para atacar.")
			return
		var objetivo = slots_monstruos_enemigo[slot_seleccionado_enemigo]
		if objetivo == null:
			_mostrar_feedback("Ese slot enemigo está vacío.")
			return
		_resolver_ataque(carta, objetivo, slot_seleccionado_enemigo, id_jugador_local)
	else:
		carta.puede_actuar = false
		var ataque = carta.card_data["attack"]
		_aplicar_danio_jugador(id_enemigo, ataque)
		_mostrar_feedback("Ataque directo: %d de daño al jugador enemigo." % ataque)
		_post_ataque(carta, id_jugador_local)

func _resolver_ataque(atacante, objetivo, idx_objetivo: int, id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var ataque     = atacante.card_data["attack"]
	atacante.puede_actuar = false

	# Paciencia (14): resetear al atacar
	if ataque_base_paciencia.has(atacante):
		atacante.card_data["attack"] = ataque_base_paciencia[atacante]
		atacante.actualizar_ui()

	var resultado = objetivo.recibir_danio(ataque)

	if resultado > 0:
		_aplicar_danio_jugador(id_enemigo, resultado)
		_mostrar_feedback("¡Carta destruida! Sobrante: %d de daño al jugador." % resultado)
	elif resultado < 0:
		# Espejito Rebotín (6)
		var reflejo  = abs(resultado)
		var sobrante = atacante.recibir_danio(reflejo)
		if sobrante > 0:
			_aplicar_danio_jugador(id_jugador, sobrante)
		_mostrar_feedback("¡Espejito Rebotín! Recibes %d de daño." % reflejo)
	else:
		_mostrar_feedback("Has hecho %d de daño a %s." % [ataque, objetivo.card_data["name"]])

	# Cuerpo Elemental (1)
	if is_instance_valid(objetivo) and objetivo.get_ability_id() == 1 and atacante.equipamiento == null:
		var s = atacante.recibir_danio(1)
		if s > 0:
			_aplicar_danio_jugador(id_jugador, s)

	# Ligamento Cruzado (30)
	var sp_obj = oponente_slot_monstruos[idx_objetivo]
	if slots_ligamento.has(sp_obj):
		_aplicar_danio_jugador(id_enemigo, 1)
		_mostrar_feedback("¡Ligamento Cruzado! El enemigo recibe 1 de daño extra.")

	_post_ataque(atacante, id_jugador)

func _post_ataque(carta, id_jugador: int):
	if carta.get_ability_id() == 9:    # Foco
		_habilidad_9(carta)
	if carta.get_ability_id() == 11:   # Escuadrón
		_habilidad_11(carta, id_jugador)
	_deseleccionar_todo()
	_actualizar_ui_completa()
	verificar_fin_partida()

# ═══════════════════════════════════════════════════════
#  HABILIDADES — BOTONES
# ═══════════════════════════════════════════════════════
func _on_btn_habilidad_propia_monstruo():
	var carta = _get_carta_monstruo_seleccionada()
	if carta == null or not carta.puede_actuar:
		return
	carta.puede_actuar = false
	_resolver_habilidad(carta.get_ability_id(), carta, id_jugador_local)
	_deseleccionar_todo()
	_actualizar_ui_completa()
	verificar_fin_partida()

func _on_btn_habilidad_equip():
	var carta = _get_carta_monstruo_seleccionada()
	if carta == null or not carta.puede_actuar:
		return
	carta.puede_actuar = false
	_resolver_habilidad(carta.get_equip_ability_id(), carta, id_jugador_local)
	_deseleccionar_todo()
	_actualizar_ui_completa()
	verificar_fin_partida()

func _on_btn_habilidad_propia_hechizo():
	var carta = _get_carta_hechizo_seleccionada()
	if carta == null or not carta.puede_actuar:
		return
	carta.puede_actuar = false
	_resolver_habilidad(carta.get_ability_id(), carta, id_jugador_local)
	# Hechizo se destruye tras usarse
	var idx = slots_hechizos_jugador.find(carta)
	if idx != -1:
		_destruir_carta_en_slot(idx, "hechizo", id_jugador_local)
	_deseleccionar_todo()
	_actualizar_ui_completa()
	verificar_fin_partida()

# ═══════════════════════════════════════════════════════
#  RESOLVER HABILIDAD — DISPATCH
# ═══════════════════════════════════════════════════════
func _resolver_habilidad(ability_id: int, carta_origen, id_jugador: int):
	if GameState.es_primera_ronda():
		_mostrar_feedback("No puedes usar habilidades en la primera ronda.")
		return

	match ability_id:
		1:  pass  # Cuerpo Elemental  — pasiva, resuelta en _resolver_ataque
		2:  _habilidad_2(carta_origen, id_jugador)
		3:  _habilidad_3(carta_origen, id_jugador)
		4:  pass  # Resiliencia       — pasiva, resuelta en Card.gd
		5:  _habilidad_5(carta_origen, id_jugador)
		6:  pass  # Espejito Rebotín  — pasiva, resuelta en Card.gd
		7:  _habilidad_7(carta_origen, id_jugador)
		8:  pass  # Penitencia Racial — pasiva, resuelta en _on_carta_entra_al_campo
		9:  _habilidad_9(carta_origen)
		10: _habilidad_10(carta_origen, id_jugador)
		11: _habilidad_11(carta_origen, id_jugador)
		12: _habilidad_12(id_jugador)
		13: _habilidad_13(id_jugador)
		14: pass  # Paciencia         — pasiva, resuelta en _iniciar_turno y _resolver_ataque
		15: _habilidad_15(id_jugador)
		16: _habilidad_16(carta_origen, id_jugador)
		17: _habilidad_17(id_jugador)
		18: _habilidad_18(id_jugador)
		19: _habilidad_19(carta_origen, id_jugador)
		20: _habilidad_20(id_jugador)
		21: _habilidad_21(id_jugador)
		22: _habilidad_22(id_jugador)
		23: _habilidad_23(id_jugador)
		24: pass  # Antiabductor      — pasiva, resuelta en Card.gd
		25: _habilidad_25(carta_origen)
		26: _habilidad_26(id_jugador)
		27: _habilidad_27(carta_origen, id_jugador)
		28: _habilidad_28(id_jugador)
		29: _habilidad_29(id_jugador)
		30: _habilidad_30(id_jugador)
		32: pass  # Existencia        — no hace nada
		_:  _mostrar_feedback("Habilidad %d no implementada." % ability_id)

# ═══════════════════════════════════════════════════════
#  HABILIDADES — IMPLEMENTACIÓN
# ═══════════════════════════════════════════════════════

# 2 — Familia
func _habilidad_2(carta_origen, id_jugador: int):
	var yo = GameState.jugadores[id_jugador]
	var candidatos : Array = []
	for c in yo["monstruos"]:
		if c != carta_origen and c.card_data["expansion"] == "Fantasticas":
			candidatos.append(c)
	for c in yo["mano"]:
		if c.card_data["expansion"] == "Fantasticas":
			candidatos.append(c)
	if candidatos.is_empty():
		_mostrar_feedback("No tienes slimes disponibles para fusionar.")
		carta_origen.puede_actuar = true
		return
	_abrir_panel_seleccion(candidatos, "fusionar_slime", carta_origen, id_jugador)

# 3 — Sugestión
func _habilidad_3(carta_origen, id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var candidatos = GameState.jugadores[id_enemigo]["monstruos"].filter(
		func(c): return c.card_data["expansion"] == "Fantasticas"
	)
	if candidatos.is_empty():
		_mostrar_feedback("No hay slimes enemigos para convencer.")
		carta_origen.puede_actuar = true
		return
	_abrir_panel_seleccion(candidatos, "sugerir_slime", carta_origen, id_jugador)

# 5 — Supresión Sacrificial
func _habilidad_5(carta_origen, id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var idx_libre  = slots_monstruos_jugador.find(null)
	if idx_libre == -1:
		_mostrar_feedback("Necesitas un slot de monstruo libre para usar esta habilidad.")
		carta_origen.puede_actuar = true
		return
	var candidatos = GameState.jugadores[id_enemigo]["monstruos"].duplicate()
	if candidatos.is_empty():
		_mostrar_feedback("El enemigo no tiene monstruos.")
		carta_origen.puede_actuar = true
		return
	_abrir_panel_seleccion(candidatos, "robar_monstruo", carta_origen, id_jugador)

# 7 — Dualidad
func _habilidad_7(carta_origen, id_jugador: int):
	var yo      = GameState.jugadores[id_jugador]
	var aliados = yo["monstruos"].filter(func(c): return c != carta_origen)
	if aliados.is_empty():
		yo["vida"] += 1
		_mostrar_feedback("Sin aliados: +1 vida al jugador.")
		_actualizar_ui_completa()
		return
	_abrir_panel_seleccion(aliados, "curar_aliado_1", carta_origen, id_jugador)

# 9 — Foco
func _habilidad_9(carta_origen):
	carta_origen.card_data["attack"] += 1
	carta_origen.actualizar_ui()
	_mostrar_feedback("¡Foco! +1 de ataque a %s." % carta_origen.card_data["name"])

# 10 — Nostalgia
func _habilidad_10(carta_origen, id_jugador: int):
	var juguetes = _cartas_db.filter(
		func(c): return c["expansion"] == "Juguetes" and c["rarity"] != 3
	)
	if juguetes.is_empty():
		_mostrar_feedback("No hay juguetes disponibles.")
		return
	juguetes.shuffle()
	var nueva_data = juguetes[0].duplicate(true)
	var idx_origen = slots_monstruos_jugador.find(carta_origen)
	_destruir_carta_en_slot(idx_origen, "monstruo", id_jugador)
	_invocar_carta_al_campo(nueva_data, id_jugador)
	_mostrar_feedback("¡Nostalgia! Se invoca %s." % nueva_data["name"])

# 11 — Escuadrón
func _habilidad_11(carta_origen, id_jugador: int):
	var slots_m = slots_monstruos_jugador if id_jugador == id_jugador_local else slots_monstruos_enemigo
	if slots_m.find(null) == -1:
		_mostrar_feedback("No hay espacio para el duplicado.")
		return
	var clon_data = carta_origen.card_data.duplicate(true)
	_invocar_carta_al_campo(clon_data, id_jugador)
	_mostrar_feedback("¡Escuadrón! Se crea un duplicado de %s." % carta_origen.card_data["name"])

# 12 — Precoz
func _habilidad_12(id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var objetivos  = GameState.jugadores[id_enemigo]["monstruos"]
	if objetivos.is_empty():
		_mostrar_feedback("No hay cartas enemigas.")
		return
	var objetivo = objetivos[randi() % objetivos.size()]
	var sobrante = objetivo.recibir_danio(4)
	if sobrante > 0:
		_aplicar_danio_jugador(id_enemigo, sobrante)
	_mostrar_feedback("¡Precoz! 4 de daño a %s." % objetivo.card_data["name"])

# 13 — Sacrificio Prometido (pasiva, al morir)
func _habilidad_13(id_jugador: int):
	robar_carta(id_jugador)
	var yo = GameState.jugadores[id_jugador]
	if not yo["mano"].is_empty():
		var idx        = randi() % yo["mano"].size()
		var descartada = yo["mano"][idx]
		yo["mano"].erase(descartada)
		var contenedor = jugador_disponibles if id_jugador == id_jugador_local else oponente_disponibles
		if descartada.get_parent() == contenedor:
			contenedor.remove_child(descartada)
		descartada.queue_free()
	_mostrar_feedback("Sacrificio Prometido: robas 1 carta y descartas 1.")

# 15 — Maldición
func _habilidad_15(id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var candidatos = GameState.jugadores[id_enemigo]["monstruos"].duplicate()
	if candidatos.is_empty():
		_mostrar_feedback("No hay cartas enemigas para maldecir.")
		return
	_abrir_panel_seleccion(candidatos, "maldecir_carta", null, id_jugador)

# 16 — Sudo Update
func _habilidad_16(carta_origen, id_jugador: int):
	var yo         = GameState.jugadores[id_jugador]
	var tiene_usb  = yo["monstruos"].any(func(c): return c.card_data["id"] == 26)
	var tiene_desc = yo["monstruos"].any(func(c): return c.card_data["id"] == 27)
	if not (tiene_usb and tiene_desc):
		_mostrar_feedback("Necesitas USB Cifrado y Descifrador de datos desplegados.")
		carta_origen.puede_actuar = true
		return
	for c in yo["monstruos"].duplicate():
		if c.card_data["id"] == 26 or c.card_data["id"] == 27:
			var idx = slots_monstruos_jugador.find(c)
			_destruir_carta_en_slot(idx, "monstruo", id_jugador)
	var hacker_data = _get_carta_por_id(29)
	carta_origen.inicializar(hacker_data)
	_mostrar_feedback("¡Sudo Update! Evoluciona a Hacker Experto.")

# 17 — Reforjado (pasiva al entrar)
func _habilidad_17(id_jugador: int):
	var yo    = GameState.jugadores[id_jugador]
	var robot = null
	for c in yo["monstruos"]:
		if c.card_data["id"] == 21:
			robot = c
			break
	if robot == null:
		return
	var blindado_data = _get_carta_por_id(22)
	if blindado_data.is_empty():
		return
	robot.inicializar(blindado_data)
	_mostrar_feedback("¡Reforjado! El Robot evoluciona a Robot Blindado.")

# 18 — Firewall
func _habilidad_18(id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var candidatos = GameState.jugadores[id_enemigo]["monstruos"].duplicate()
	if candidatos.is_empty():
		_mostrar_feedback("No hay cartas enemigas para quemar.")
		return
	_abrir_panel_seleccion(candidatos, "aplicar_quemadura", null, id_jugador)

# 19 — Mega Update
func _habilidad_19(carta_origen, id_jugador: int):
	var yo             = GameState.jugadores[id_jugador]
	var tiene_soldador = yo["monstruos"].any(func(c): return c.card_data["id"] == 23)
	var tiene_canon    = yo["monstruos"].any(func(c): return c.card_data["id"] == 17)
	if not (tiene_soldador and tiene_canon):
		_mostrar_feedback("Necesitas Soldador y Cañón de plasma desplegados.")
		carta_origen.puede_actuar = true
		return
	for c in yo["monstruos"].duplicate():
		if c.card_data["id"] == 23 or c.card_data["id"] == 17:
			var idx = slots_monstruos_jugador.find(c)
			_destruir_carta_en_slot(idx, "monstruo", id_jugador)
	var exter_data = _get_carta_por_id(30)
	carta_origen.inicializar(exter_data)
	_mostrar_feedback("¡Mega Update! Evoluciona a Robot Exterminador.")

# 20 — Troyan
func _habilidad_20(id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var enemigo    = GameState.jugadores[id_enemigo]
	if enemigo["monstruos"].is_empty():
		_aplicar_danio_jugador(id_enemigo, 2)
		_mostrar_feedback("¡Troyan! 2 de daño directo al jugador.")
	else:
		var objetivo = enemigo["monstruos"][randi() % enemigo["monstruos"].size()]
		var sobrante = objetivo.recibir_danio(2)
		if sobrante > 0:
			_aplicar_danio_jugador(id_enemigo, sobrante)
		_mostrar_feedback("¡Troyan! 2 de daño a %s." % objetivo.card_data["name"])

# 21 — Datapack (pasiva al entrar)
func _habilidad_21(id_jugador: int):
	robar_carta(id_jugador)
	_mostrar_feedback("¡Datapack! Robas 1 carta.")

# 22 — Antivirus
func _habilidad_22(id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var candidatos = GameState.jugadores[id_enemigo]["monstruos"].duplicate()
	if candidatos.is_empty():
		_mostrar_feedback("No hay cartas enemigas para inhabilitar.")
		return
	_abrir_panel_seleccion(candidatos, "inhabilitar_carta", null, id_jugador)

# 23 — Exterminator (pasiva al entrar)
func _habilidad_23(id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var enemigo    = GameState.jugadores[id_enemigo]
	if enemigo["monstruos"].is_empty():
		_mostrar_feedback("No hay cartas enemigas para exterminar.")
		return
	var objetivo = enemigo["monstruos"][randi() % enemigo["monstruos"].size()]
	var idx      = slots_monstruos_enemigo.find(objetivo)
	_destruir_carta_en_slot(idx, "monstruo", id_enemigo)
	_mostrar_feedback("¡Exterminator! Destruye a %s." % objetivo.card_data["name"])

# 25 — Ataque Sorpresa (equipamiento al equipar)
func _habilidad_25(_carta_origen):
	if mano_enemigo.is_empty():
		_mostrar_feedback("El enemigo no tiene cartas en la mano.")
		return
	for c in mano_enemigo:
		if is_instance_valid(c):
			c.ocultar_reverso()
	_abrir_panel_seleccion(mano_enemigo.duplicate(), "eliminar_carta_mano", null, id_jugador_local)

# 26 — Heal
func _habilidad_26(id_jugador: int):
	GameState.jugadores[id_jugador]["vida"] += 2
	_mostrar_feedback("+2 de vida.")
	_actualizar_ui_completa()

# 27 — Terremoto
func _habilidad_27(_carta_origen, id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var panel      = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(350, 200)
	add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)
	var titulo = Label.new()
	titulo.text = "Terremoto: elige objetivo"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)
	var btn_directo = Button.new()
	btn_directo.text = "Jugador enemigo (-1 vida)"
	btn_directo.pressed.connect(func():
		panel.queue_free()
		_aplicar_danio_jugador(id_enemigo, 1)
		_mostrar_feedback("Terremoto: 1 de daño al jugador enemigo.")
		verificar_fin_partida()
	)
	vbox.add_child(btn_directo)
	for i in range(3):
		var monstruo = slots_monstruos_enemigo[i]
		if monstruo != null:
			var btn  = Button.new()
			btn.text = "%s (-2 vida)" % monstruo.card_data["name"]
			var i_cap = i
			btn.pressed.connect(func():
				panel.queue_free()
				var objetivo_capturado = slots_monstruos_enemigo[i_cap]
				if is_instance_valid(objetivo_capturado):
					var sob = objetivo_capturado.recibir_danio(2)
					if sob > 0:
						_aplicar_danio_jugador(id_enemigo, sob)
				_actualizar_ui_completa()
				verificar_fin_partida()
			)
			vbox.add_child(btn)

# 28 — Otra Vez
func _habilidad_28(id_jugador: int):
	var yo      = GameState.jugadores[id_jugador]
	var activas = yo["monstruos"].filter(
		func(c): return not c.card_data["ability"]["isPassive"] and c.card_data["ability"]["id"] != 0
	)
	if activas.is_empty():
		_mostrar_feedback("No hay cartas con habilidad activa en el campo.")
		return
	_abrir_panel_seleccion(activas, "repetir_habilidad", null, id_jugador)

# 29 — Paguitas
func _habilidad_29(id_jugador: int):
	robar_carta(id_jugador)
	robar_carta(id_jugador)
	_mostrar_feedback("¡Paguitas! Robas 2 cartas.")

# 30 — Ligamento Cruzado
func _habilidad_30(id_jugador: int):
	var yo = GameState.jugadores[id_jugador]
	if yo["monstruos"].is_empty():
		_mostrar_feedback("No tienes monstruos desplegados.")
		return
	_abrir_panel_seleccion(yo["monstruos"].duplicate(), "aplicar_ligamento", null, id_jugador)

# ═══════════════════════════════════════════════════════
#  PANEL DE SELECCIÓN GENÉRICO
# ═══════════════════════════════════════════════════════
func _abrir_panel_seleccion(lista: Array, accion: String, origen, id_jugador: int):
	var panel = Panel.new()
	panel.name = "PanelSeleccion"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 300)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var titulo = Label.new()
	titulo.text = _texto_accion(accion)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)

	for carta in lista:
		var btn      = Button.new()
		btn.text     = carta.card_data["name"]
		var carta_cap = carta
		btn.pressed.connect(func():
			panel.queue_free()
			_resolver_seleccion(carta_cap, accion, origen, id_jugador)
		)
		vbox.add_child(btn)

	var btn_cancelar  = Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.pressed.connect(func():
		panel.queue_free()
		if origen != null:
			origen.puede_actuar = true
		_mostrar_feedback("Acción cancelada.")
	)
	vbox.add_child(btn_cancelar)

func _texto_accion(accion: String) -> String:
	match accion:
		"fusionar_slime":       return "Elige un slime para fusionar"
		"sugerir_slime":        return "Elige un slime enemigo"
		"robar_monstruo":       return "Elige un monstruo para robar"
		"curar_aliado_1":       return "Elige un aliado para curar"
		"maldecir_carta":       return "Elige una carta para maldecir"
		"aplicar_quemadura":    return "Elige una carta para quemar"
		"inhabilitar_carta":    return "Elige una carta para inhabilitar"
		"eliminar_carta_mano":  return "Elige una carta de la mano enemiga"
		"repetir_habilidad":    return "Elige una carta para repetir su habilidad"
		"aplicar_ligamento":    return "Elige un aliado para el ligamento cruzado"
		_:                      return "Elige una carta"

func _resolver_seleccion(carta_elegida, accion: String, origen, id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	var yo         = GameState.jugadores[id_jugador]
	var enemigo    = GameState.jugadores[id_enemigo]

	match accion:
		"fusionar_slime":
			var en_campo = yo["monstruos"].has(carta_elegida)
			if en_campo:
				var idx = slots_monstruos_jugador.find(carta_elegida)
				_destruir_carta_en_slot(idx, "monstruo", id_jugador)
			else:
				yo["mano"].erase(carta_elegida)
				mano_jugador.erase(carta_elegida)
				if carta_elegida.get_parent() != null:
					carta_elegida.get_parent().remove_child(carta_elegida)
				carta_elegida.queue_free()
			origen.card_data["attack"] += 1
			yo["vida"] += 1
			origen.actualizar_ui()
			_mostrar_feedback("Fusión: +1 ataque y +1 vida.")

		"sugerir_slime":
			var idx = slots_monstruos_enemigo.find(carta_elegida)
			_destruir_carta_en_slot(idx, "monstruo", id_enemigo)
			origen.card_data["attack"] += 1
			yo["vida"] += 1
			origen.actualizar_ui()
			_mostrar_feedback("Sugestión: slime convencido. +1 ataque y +1 vida.")

		"robar_monstruo":
			var idx_enemigo = slots_monstruos_enemigo.find(carta_elegida)
			var idx_libre   = slots_monstruos_jugador.find(null)
			# Quitar del campo enemigo
			slots_monstruos_enemigo[idx_enemigo] = null
			enemigo["monstruos"].erase(carta_elegida)
			if carta_elegida.get_parent() != null:
				carta_elegida.get_parent().remove_child(carta_elegida)
			_aplicar_sombra_slot(oponente_slot_monstruos[idx_enemigo], SOMBRA_VACIO)
			# Añadir al campo propio
			slots_monstruos_jugador[idx_libre] = carta_elegida
			yo["monstruos"].append(carta_elegida)
			jugador_slot_monstruos[idx_libre].add_child(carta_elegida)
			_ajustar_carta_al_slot(carta_elegida, jugador_slot_monstruos[idx_libre])
			# Destruir origen
			var idx_origen = slots_monstruos_jugador.find(origen)
			_destruir_carta_en_slot(idx_origen, "monstruo", id_jugador)
			_mostrar_feedback("¡Monstruo robado!")

		"curar_aliado_1":
			carta_elegida.defense_actual += 1
			carta_elegida.actualizar_ui()
			_mostrar_feedback("+1 vida a %s." % carta_elegida.card_data["name"])

		"maldecir_carta":
			var danio    = carta_elegida.defense_actual - int(carta_elegida.defense_actual / 2.0)
			var sobrante = carta_elegida.recibir_danio(danio)
			if sobrante > 0:
				_aplicar_danio_jugador(id_enemigo, sobrante)
			_mostrar_feedback("Vida de %s reducida a la mitad." % carta_elegida.card_data["name"])

		"aplicar_quemadura":
			_registrar_efecto(carta_elegida, "quemadura", 3)
			_mostrar_feedback("%s en llamas durante 3 turnos." % carta_elegida.card_data["name"])

		"inhabilitar_carta":
			_registrar_efecto(carta_elegida, "inhabilitacion", 3)
			carta_elegida.puede_actuar = false
			_mostrar_feedback("%s inhabilitada 3 turnos." % carta_elegida.card_data["name"])

		"eliminar_carta_mano":
			enemigo["mano"].erase(carta_elegida)
			mano_enemigo.erase(carta_elegida)
			if carta_elegida.get_parent() != null:
				carta_elegida.get_parent().remove_child(carta_elegida)
			carta_elegida.queue_free()
			# Volver a tapar las cartas enemigas
			for c in mano_enemigo:
				if is_instance_valid(c):
					c.mostrar_reverso()
			_mostrar_feedback("Carta enemiga eliminada de la mano.")

		"repetir_habilidad":
			_resolver_habilidad(carta_elegida.get_ability_id(), carta_elegida, id_jugador)
			_mostrar_feedback("Habilidad de %s repetida." % carta_elegida.card_data["name"])

		"aplicar_ligamento":
			var slot_idx = slots_monstruos_jugador.find(carta_elegida)
			if slot_idx != -1:
				var sp = jugador_slot_monstruos[slot_idx]
				slots_ligamento[sp] = true
				_aplicar_sombra_slot(sp, SOMBRA_MORADA)
				_mostrar_feedback("Ligamento Cruzado en %s." % carta_elegida.card_data["name"])

	_actualizar_ui_completa()
	verificar_fin_partida()

# ═══════════════════════════════════════════════════════
#  INVOCAR CARTA AL CAMPO (habilidades 10, 11)
# ═══════════════════════════════════════════════════════
func _invocar_carta_al_campo(datos: Dictionary, id_jugador: int):
	var slots_m     = slots_monstruos_jugador if id_jugador == id_jugador_local else slots_monstruos_enemigo
	var slot_panels = jugador_slot_monstruos  if id_jugador == id_jugador_local else oponente_slot_monstruos
	var idx_libre   = slots_m.find(null)
	if idx_libre == -1:
		_mostrar_feedback("No hay slots libres.")
		return
	var carta = CardScene.instantiate()
	carta.carta_muerta.connect(_on_carta_muerta.bind(id_jugador))
	slot_panels[idx_libre].add_child(carta)
	carta.inicializar(datos)
	_ajustar_carta_al_slot(carta, slot_panels[idx_libre])
	carta.esta_desplegada = true
	slots_m[idx_libre] = carta
	GameState.jugadores[id_jugador]["monstruos"].append(carta)
	_on_carta_entra_al_campo(carta, id_jugador)
	_actualizar_ui_completa()
	_mostrar_feedback("%s invocado al campo." % datos["name"])

# ═══════════════════════════════════════════════════════
#  EVENTOS AL ENTRAR AL CAMPO
# ═══════════════════════════════════════════════════════
func _on_carta_entra_al_campo(carta, id_jugador: int):
	var id_enemigo = GameState.get_enemigo(id_jugador)
	if carta.is_passive():
		match carta.get_ability_id():
			21: _habilidad_21(id_jugador)   # Datapack
			23: _habilidad_23(id_jugador)   # Exterminator
			17: _habilidad_17(id_jugador)   # Reforjado
	# Penitencia Racial (8)
	for c in GameState.jugadores[id_enemigo]["monstruos"]:
		if c.get_ability_id() == 8 and carta.card_data["expansion"] != "Juguetes":
			carta.recibir_danio(1)
			break

# ═══════════════════════════════════════════════════════
#  MUERTE DE CARTA
# ═══════════════════════════════════════════════════════
func _on_carta_muerta(carta, id_jugador: int):
	var ability_id = carta.get_ability_id()

	var idx_m = (slots_monstruos_jugador if id_jugador == id_jugador_local else slots_monstruos_enemigo).find(carta)
	var idx_h = (slots_hechizos_jugador  if id_jugador == id_jugador_local else slots_hechizos_enemigo).find(carta)

	if idx_m != -1:
		var slots_m  = slots_monstruos_jugador if id_jugador == id_jugador_local else slots_monstruos_enemigo
		var panels_m = jugador_slot_monstruos  if id_jugador == id_jugador_local else oponente_slot_monstruos
		slots_m[idx_m] = null
		_aplicar_sombra_slot(panels_m[idx_m], SOMBRA_VACIO)
		slots_ligamento.erase(panels_m[idx_m])
		GameState.jugadores[id_jugador]["monstruos"].erase(carta)

	if idx_h != -1:
		var slots_h  = slots_hechizos_jugador if id_jugador == id_jugador_local else slots_hechizos_enemigo
		var panels_h = jugador_slot_hechizos  if id_jugador == id_jugador_local else oponente_slot_hechizos
		slots_h[idx_h] = null
		_aplicar_sombra_slot(panels_h[idx_h], SOMBRA_VACIO)
		GameState.jugadores[id_jugador]["hechizos"].erase(carta)

	ataque_base_paciencia.erase(carta)
	efectos_activos.erase(carta)

	var cementerio = jugador_cementerio if id_jugador == id_jugador_local else oponente_cementerio
	cementerio.add_child(CardReverseScene.instantiate())

	if ability_id == 13:
		_habilidad_13(id_jugador)

	_actualizar_ui_completa()
	verificar_fin_partida()

func _destruir_carta_en_slot(idx: int, tipo: String, id_jugador: int):
	if idx == -1:
		return
	var slots_arr  = (slots_monstruos_jugador if tipo == "monstruo" else slots_hechizos_jugador) if id_jugador == id_jugador_local \
					 else (slots_monstruos_enemigo if tipo == "monstruo" else slots_hechizos_enemigo)
	var panels_arr = (jugador_slot_monstruos if tipo == "monstruo" else jugador_slot_hechizos) if id_jugador == id_jugador_local \
					 else (oponente_slot_monstruos if tipo == "monstruo" else oponente_slot_hechizos)
	if slots_arr[idx] == null:
		return
	var carta = slots_arr[idx]
	slots_arr[idx] = null
	GameState.jugadores[id_jugador]["monstruos"].erase(carta)
	GameState.jugadores[id_jugador]["hechizos"].erase(carta)
	if carta.get_parent() != null:
		carta.get_parent().remove_child(carta)
	carta.queue_free()
	_aplicar_sombra_slot(panels_arr[idx], SOMBRA_VACIO)
	slots_ligamento.erase(panels_arr[idx])
	var cementerio = jugador_cementerio if id_jugador == id_jugador_local else oponente_cementerio
	cementerio.add_child(CardReverseScene.instantiate())

# ═══════════════════════════════════════════════════════
#  EFECTOS POR TURNO
# ═══════════════════════════════════════════════════════
func _registrar_efecto(carta, tipo: String, turnos: int):
	efectos_activos[carta] = {"tipo": tipo, "turnos_restantes": turnos}

func _procesar_efectos_turno(_id_jugador: int):
	var a_eliminar : Array = []
	for carta in efectos_activos.keys():
		if not is_instance_valid(carta):
			a_eliminar.append(carta)
			continue
		var efecto = efectos_activos[carta]
		match efecto["tipo"]:
			"quemadura":
				var id_duenio = _get_id_duenio(carta)
				var sobrante  = carta.recibir_danio(1)
				if sobrante > 0:
					_aplicar_danio_jugador(id_duenio, sobrante)
			"inhabilitacion":
				carta.puede_actuar = false
		efecto["turnos_restantes"] -= 1
		if efecto["turnos_restantes"] <= 0:
			a_eliminar.append(carta)
			if efecto["tipo"] == "inhabilitacion":
				carta.puede_actuar = true
	for carta in a_eliminar:
		efectos_activos.erase(carta)

func _get_id_duenio(carta) -> int:
	for id in GameState.jugadores:
		if carta in GameState.jugadores[id]["monstruos"]:
			return id
	return 1

# ═══════════════════════════════════════════════════════
#  DAÑO AL JUGADOR
# ═══════════════════════════════════════════════════════
func _aplicar_danio_jugador(id_jugador: int, cantidad: int):
	GameState.jugadores[id_jugador]["vida"] -= cantidad
	_actualizar_ui_completa()

# ═══════════════════════════════════════════════════════
#  FIN DE PARTIDA
# ═══════════════════════════════════════════════════════
func verificar_fin_partida():
	for id in GameState.jugadores:
		if GameState.jugador_ha_perdido(id):
			_fin_partida(GameState.get_enemigo(id))
			return

func _fin_partida(id_ganador: int):
	timer_turno.stop()
	timer_duracion.stop()
	_mostrar_feedback("¡%s gana la partida!" % GameState.jugadores[id_ganador]["nombre"])

# ═══════════════════════════════════════════════════════
#  REPORTAR AFK
# ═══════════════════════════════════════════════════════
func _on_btn_reportar():
	var id_enemigo = GameState.get_enemigo(id_jugador_local)
	btn_reportar.visible = false
	afk_visible          = true
	_mostrar_feedback("AFK reportado. El enemigo tiene 1 minuto extra.")
	await get_tree().create_timer(60.0).timeout
	if GameState.turno_jugador == id_enemigo:
		afk_contador[id_enemigo] += 1
		_mostrar_feedback("Turno saltado por AFK (%d/3)." % afk_contador[id_enemigo])
		if afk_contador[id_enemigo] >= 3:
			_fin_partida(id_jugador_local)
		else:
			_terminar_turno()

# ═══════════════════════════════════════════════════════
#  TIMERS
# ═══════════════════════════════════════════════════════
func _on_tick_turno():
	segundos_turno += 1
	var restante    = max(0, 60 - segundos_turno)
	tiempo_restante_label.text = "Tiempo restante:\n%02d:%02d" % [restante / 60, restante % 60]
	if GameState.turno_jugador != id_jugador_local and segundos_turno >= 30 and not afk_visible:
		btn_reportar.visible = true
	if restante <= 0:
		_terminar_turno()

func _on_tick_duracion():
	segundos_duracion += 1
	duracion_label.text = "Duracion: %02d:%02d" % [segundos_duracion / 60, segundos_duracion % 60]

# ═══════════════════════════════════════════════════════
#  UI
# ═══════════════════════════════════════════════════════
func _actualizar_ui_completa():
	var jl = GameState.jugadores[id_jugador_local]
	var je = GameState.jugadores[GameState.get_enemigo(id_jugador_local)]

	jugador_nombre_label.text  = jl["nombre"]
	jugador_vida_label.text    = "Vida: %d/%d" % [jl["vida"], GameState.VIDA_INICIAL]
	jugador_vida_bar.max_value = GameState.VIDA_INICIAL
	jugador_vida_bar.value     = max(0, jl["vida"])
	jugador_mana_label.text    = "Mana: %d/%d" % [jl["mana_actual"], jl["mana_max"]]
	jugador_mana_bar.max_value = jl["mana_max"]
	jugador_mana_bar.value     = jl["mana_actual"]

	oponente_nombre_label.text  = je["nombre"]
	oponente_vida_label.text    = "Vida: %d/%d" % [je["vida"], GameState.VIDA_INICIAL]
	oponente_vida_bar.max_value = GameState.VIDA_INICIAL
	oponente_vida_bar.value     = max(0, je["vida"])
	oponente_mana_label.text    = "Mana: %d/%d" % [je["mana_actual"], je["mana_max"]]
	oponente_mana_bar.max_value = je["mana_max"]
	oponente_mana_bar.value     = je["mana_actual"]

	ronda_label.text = "Ronda: %d" % GameState.ronda
	turno_label.text = "Turno: %s" % GameState.jugadores[GameState.turno_jugador]["nombre"]

	_actualizar_visibilidad_botones()

func _mostrar_feedback(texto: String):
	feedback_monstruos.text = texto
	feedback_hechizos.text  = texto
