extends Node
# GameUI.gd
# Adjunta este script al nodo "GameUI" (hijo de Control) en Game.tscn


# ═════════════════════════════════════════════
#  CONSTANTES
# ═════════════════════════════════════════════
const CARD_SCENE := preload("res://scenes/Card.tscn")

## Segundos de turno rival sin acción antes de mostrar el botón Reportar
const TIEMPO_ANTES_REPORTAR: float = 60.0
## Segundos extra que se le dan al jugador reportado como AFK
const TIEMPO_EXTRA_AFK: float = 30.0


# ═════════════════════════════════════════════
#  REFERENCIAS — INFO
# ═════════════════════════════════════════════
@onready var tiempo_restante_panel: Panel  = $"../Info/TiempoRestante"
@onready var tiempo_restante_label: Label  = $"../Info/TiempoRestante/DuracionLabel"
@onready var info_duracion_label:   Label  = $"../Info/InfoPartida/DuracionLabel"
@onready var info_ronda_label:      Label  = $"../Info/InfoPartida/RondaLabel"
@onready var info_turno_label:      Label  = $"../Info/InfoPartida/TurnoLabel"
@onready var boton_reportar:        Button = $"../Info/Reportar"


# ═════════════════════════════════════════════
#  REFERENCIAS — JUGADOR
# ═════════════════════════════════════════════
@onready var jugador_nombre_label: Label       = $"../Jugador/InfoJugador/NombreLabel"
@onready var jugador_vida_label:   Label       = $"../Jugador/InfoJugador/VidaLabel"
@onready var jugador_vida_bar:     ProgressBar = $"../Jugador/InfoJugador/VidaBar"
@onready var jugador_mana_label:   Label       = $"../Jugador/InfoJugador/ManaLabel"
@onready var jugador_mana_bar:     ProgressBar = $"../Jugador/InfoJugador/ManaBar"

@onready var jugador_cartas_baraja:   HBoxContainer = $"../Jugador/ManoJugador/CartasBaraja"
@onready var jugador_disponibles_org: HBoxContainer = $"../Jugador/ManoJugador/DisponiblesPanel/DisponiblesOrganizador"

@onready var boton_atacar:    Button = $"../Jugador/DespliegueJugador/BotonAtaque"
@onready var boton_habilidad: Button = $"../Jugador/DespliegueJugador/BotonHabilidad"
@onready var feedback_label:  Label  = $"../Jugador/DespliegueJugador/FeedbackLabel"

@onready var jugador_cementerio: HBoxContainer = $"../Jugador/MuertosJugador/CartasCementerio"

@onready var boton_acabar_turno: Button = $"../Jugador/AcabarTurno"

# ═════════════════════════════════════════════
#  REFERENCIAS — OPONENTE
# ═════════════════════════════════════════════
@onready var oponente_nombre_label: Label       = $"../Oponente/InfoOponente/NombreLabel"
@onready var oponente_vida_label:   Label       = $"../Oponente/InfoOponente/VidaLabel"
@onready var oponente_vida_bar:     ProgressBar = $"../Oponente/InfoOponente/VidaBar"
@onready var oponente_mana_label:   Label       = $"../Oponente/InfoOponente/ManaLabel"
@onready var oponente_mana_bar:     ProgressBar = $"../Oponente/InfoOponente/ManaBar"

@onready var oponente_cartas_baraja:   HBoxContainer = $"../Oponente/ManoOponente/CartasBaraja"
@onready var oponente_disponibles_org: HBoxContainer = $"../Oponente/ManoOponente/DisponiblesPanel/DisponiblesOrganizador"

@onready var log_label: Label = $"../Oponente/DespliegueOponente/LogLabel"

@onready var oponente_cementerio: HBoxContainer = $"../Oponente/MuertosOponente/CartasCementerio"


# ═════════════════════════════════════════════
#  ESTADO INTERNO
# ═════════════════════════════════════════════
var _tiempo_turno_rival: float = 0.0
var _afk_activo:         bool  = false
var _tiempo_afk:         float = 0.0

var _log_lineas: Array = []
const LOG_MAX_LINEAS: int = 12

## Evita instanciar cartas en mano mientras la sincronización inicial no ha terminado
var _sincronizacion_completada: bool = false


# ═════════════════════════════════════════════
#  INICIALIZACIÓN
# ═════════════════════════════════════════════
func _ready() -> void:
	_conectar_senales_gamemanager()
	_conectar_botones()
	_inicializar_ui()
	# Si la partida ya fue iniciada antes de que esta escena cargara
	# (p.ej. desde Login), sincronizamos el estado ahora.
	if GameManager.partida_activa:
		_sincronizar_estado_inicial()



func _sincronizar_estado_inicial() -> void:
	# Info partida
	info_ronda_label.text = "Ronda: %d" % GameManager.ronda_actual
	_actualizar_turno_ui(GameManager.turno_actual)

	# Stats jugadores
	_refrescar_info_jugador("jugador")
	_refrescar_info_jugador("oponente")

	# Baraja: actualiza los indicadores visuales
	_actualizar_baraja_ui("jugador")
	_actualizar_baraja_ui("oponente")

	# Instancia visualmente todas las cartas que ya están en las manos
	var p_j := GameManager._get_jugador("jugador")
	for carta in p_j["mano"]:
		_instanciar_carta_en_mano("jugador", carta)

	var p_o := GameManager._get_jugador("oponente")
	for carta in p_o["mano"]:
		_instanciar_carta_en_mano("oponente", carta)

	_añadir_log("⚔ Partida en curso — Ronda %d — Turno: %s" % [
		GameManager.ronda_actual, GameManager.turno_actual.capitalize()
	])
	_sincronizacion_completada = true
	# Fuerza actualización de botones según el turno actual
	SelectionManager._actualizar_botones()


func _conectar_senales_gamemanager() -> void:
	GameManager.partida_iniciada.connect(_on_partida_iniciada)
	GameManager.partida_terminada.connect(_on_partida_terminada)
	GameManager.ronda_cambiada.connect(_on_ronda_cambiada)
	GameManager.turno_cambiado.connect(_on_turno_cambiado)
	GameManager.vida_cambiada.connect(_on_vida_cambiada)
	GameManager.mana_cambiado.connect(_on_mana_cambiado)
	GameManager.carta_robada.connect(_on_carta_robada)
	GameManager.carta_desplegada.connect(_on_carta_desplegada)
	GameManager.carta_enviada_al_cementerio.connect(_on_carta_al_cementerio)
	GameManager.equipamiento_colocado.connect(_on_equipamiento_colocado)


func _conectar_botones() -> void:
	boton_acabar_turno.pressed.connect(_on_acabar_turno)
	boton_atacar.pressed.connect(_on_boton_atacar)
	boton_habilidad.pressed.connect(_on_boton_habilidad)
	boton_reportar.pressed.connect(_on_boton_reportar)
	AbilityManager.habilidad_fallida.connect(_on_habilidad_fallida)
	AbilityManager.habilidad_activada.connect(_on_habilidad_activada)
	AbilityManager.carta_evolucionada.connect(_on_carta_evolucionada)
	SelectionManager.botones_actualizados.connect(_on_botones_actualizados)
	# Texto por defecto del botón habilidad
	boton_habilidad.text = "Habilidad"


func _inicializar_ui() -> void:
	info_duracion_label.text = "Duración: 00:00"
	info_ronda_label.text    = "Ronda: -"
	info_turno_label.text    = "Turno: -"
	jugador_nombre_label.text  = "Jugador"
	oponente_nombre_label.text = "Oponente"
	_actualizar_vida_ui("jugador",  GameManager.VIDA_MAXIMA, GameManager.VIDA_MAXIMA)
	_actualizar_mana_ui("jugador",  GameManager.MANA_INICIAL, GameManager.MANA_INICIAL)
	_actualizar_vida_ui("oponente", GameManager.VIDA_MAXIMA, GameManager.VIDA_MAXIMA)
	_actualizar_mana_ui("oponente", GameManager.MANA_INICIAL, GameManager.MANA_INICIAL)
	_set_botones_accion(false)
	boton_acabar_turno.disabled = true
	tiempo_restante_panel.visible = false
	boton_reportar.visible        = false
	log_label.text      = ""
	feedback_label.text = ""


# ═════════════════════════════════════════════
#  PROCESS — cronómetro + AFK
# ═════════════════════════════════════════════
func _process(delta: float) -> void:
	if not GameManager.partida_activa:
		return

	# Cronómetro de la partida
	info_duracion_label.text = "Duración: %s" % _formato_tiempo(GameManager.tiempo_transcurrido)

	# Lógica AFK: solo cuando es turno del oponente
	if GameManager.turno_actual == "oponente":
		_tiempo_turno_rival += delta

		if _tiempo_turno_rival >= TIEMPO_ANTES_REPORTAR and not boton_reportar.visible:
			boton_reportar.visible = true

		if _afk_activo:
			_tiempo_afk -= delta
			tiempo_restante_label.text = "Tiempo restante:\n%s" % _formato_tiempo(_tiempo_afk)
			if _tiempo_afk <= 0.0:
				_finalizar_afk()
	else:
		_tiempo_turno_rival = 0.0
		if not _afk_activo:
			boton_reportar.visible        = false
			tiempo_restante_panel.visible = false


# ═════════════════════════════════════════════
#  SEÑALES DE GAMEMANAGER
# ═════════════════════════════════════════════
func _on_partida_iniciada(primer_turno: String) -> void:
	info_ronda_label.text = "Ronda: 1"
	_actualizar_turno_ui(primer_turno)
	_actualizar_baraja_ui("jugador")
	_actualizar_baraja_ui("oponente")
	_añadir_log("⚔ Partida iniciada — primer turno: %s" % primer_turno.capitalize())
	_sincronizacion_completada = true


func _on_partida_terminada(ganador: String) -> void:
	var txt: String = "🏆 %s ha ganado!" % ganador.capitalize()
	_añadir_log(txt)
	_set_feedback(txt)
	_set_botones_accion(false)
	boton_acabar_turno.disabled = true


func _on_ronda_cambiada(nueva_ronda: int) -> void:
	info_ronda_label.text = "Ronda: %d" % nueva_ronda
	_añadir_log("── Ronda %d ──" % nueva_ronda)
	_refrescar_info_jugador("jugador")
	_refrescar_info_jugador("oponente")


func _on_turno_cambiado(turno: String) -> void:
	_actualizar_turno_ui(turno)
	_tiempo_turno_rival = 0.0
	_afk_activo         = false
	tiempo_restante_panel.visible = false
	boton_reportar.visible        = false
	SelectionManager.deseleccionar_todo()




func _on_vida_cambiada(quien: String, nueva_vida: int) -> void:
	_actualizar_vida_ui(quien, nueva_vida, GameManager.VIDA_MAXIMA)


func _on_mana_cambiado(quien: String, mana_actual: int, mana_maximo: int) -> void:
	_actualizar_mana_ui(quien, mana_actual, mana_maximo)


func _on_carta_robada(quien: String, carta: Dictionary) -> void:
	_actualizar_baraja_ui(quien)
	# Durante la sincronización inicial (_sincronizar_estado_inicial) ya se
	# instancian todas las cartas de la mano en bloque, evitamos duplicados.
	if not _sincronizacion_completada:
		return
	_instanciar_carta_en_mano(quien, carta)


func _on_carta_desplegada(quien: String, carta: Dictionary, destino: String) -> void:
	_actualizar_baraja_ui(quien)
	_añadir_log("%s desplegó '%s' en %s" % [
		quien.capitalize(), carta.get("nombre","???"), destino
	])


func _on_carta_al_cementerio(quien: String, carta: Dictionary) -> void:
	_actualizar_baraja_ui(quien)
	_añadir_log("%s → cementerio: '%s'" % [quien.capitalize(), carta.get("name", carta.get("nombre","???"))])
	var card_id: int = int(carta.get("id", -1))
	var cementerio: HBoxContainer = jugador_cementerio if quien == "jugador" else oponente_cementerio

	# Comprueba si el nodo ya está en el cementerio (lo movió _on_carta_nodo_muerta)
	for nodo in cementerio.get_children():
		if nodo is Card and nodo.id == card_id:
			return   # ya está, nada que hacer

	# Busca el nodo en los slots desplegados por ID (con int() para floats del JSON)
	var nodo_en_slot: Card = null
	for nodo in get_tree().get_nodes_in_group("desplegadas"):
		if nodo is Card and int(nodo.id) == card_id and nodo.propietario == quien:
			nodo_en_slot = nodo
			break
	# Si no lo encontró en el grupo, busca en todos los slots directamente
	if nodo_en_slot == null:
		var todos_slots: Array = _get_todos_los_slots(quien)
		for slot in todos_slots:
			for hijo in slot.get_children():
				if hijo is Card and int(hijo.id) == card_id:
					nodo_en_slot = hijo
					break
			if nodo_en_slot != null:
				break

	if nodo_en_slot != null:
		_mover_nodo_a_cementerio(nodo_en_slot, cementerio)
	else:
		# El nodo no existe en escena: instancia uno nuevo en el cementerio
		_instanciar_carta_en_cementerio(quien, carta)


func _on_equipamiento_colocado(quien: String, equip: Dictionary) -> void:
	_añadir_log("%s equipó '%s'" % [quien.capitalize(), equip.get("nombre","???")])


# ═════════════════════════════════════════════
#  BOTONES
# ═════════════════════════════════════════════
func _on_acabar_turno() -> void:
	if not GameManager.es_mi_turno("jugador"):
		_set_feedback("No es tu turno")
		return
	SelectionManager.deseleccionar_todo()
	_set_feedback("")
	GameManager.acabar_turno("jugador")


func _on_boton_atacar() -> void:
	if not GameManager.es_mi_turno("jugador"):
		_set_feedback("No es tu turno")
		return
	if GameManager.solo_despliegue:
		_set_feedback("Ronda 1: solo se pueden desplegar cartas")
		return
	var resultado: String = SelectionManager.ejecutar_ataque()
	_añadir_log(resultado) if not resultado.begins_with("Selecciona") and not resultado.begins_with("Solo") and not resultado.begins_with("El") and not resultado.begins_with("Esta") else _set_feedback(resultado)


func _on_boton_habilidad() -> void:
	if not GameManager.es_mi_turno("jugador"):
		_set_feedback("No es tu turno")
		return
	if GameManager.solo_despliegue:
		_set_feedback("Ronda 1: solo se pueden desplegar cartas")
		return
	if SelectionManager.carta_seleccionada == null:
		_set_feedback("Selecciona una carta para usar su habilidad")
		return
	if SelectionManager.carta_seleccionada.habilidad_es_pasiva:
		_set_feedback("Habilidad pasiva: se activa automáticamente")
		return
	if SelectionManager.carta_seleccionada.usada_este_turno:
		_set_feedback("Esta carta ya actuó este turno")
		return
	var carta_a_usar:   Card = SelectionManager.carta_seleccionada
	var carta_objetivo: Card = SelectionManager.carta_enemiga_seleccionada
	# Deseleccionar ANTES de activar para limpiar resaltados
	SelectionManager.deseleccionar_todo()
	AbilityManager.activar_habilidad_activa(carta_a_usar, "jugador", carta_objetivo)


func _on_boton_reportar() -> void:
	if _afk_activo:
		return
	_afk_activo           = true
	_tiempo_afk           = TIEMPO_EXTRA_AFK
	tiempo_restante_panel.visible = true
	boton_reportar.visible        = false
	_añadir_log("⏱ AFK reportado — %d segundos extra para el oponente" % int(TIEMPO_EXTRA_AFK))


func _finalizar_afk() -> void:
	_afk_activo           = false
	tiempo_restante_panel.visible = false
	_añadir_log("⏱ Tiempo AFK agotado — turno forzado al siguiente")
	GameManager.acabar_turno("oponente")


# ═════════════════════════════════════════════
#  FEEDBACK DE HABILIDADES (AbilityManager)
# ═════════════════════════════════════════════
func _on_habilidad_fallida(_carta: Card, razon: String) -> void:
	_set_feedback(razon)


func _on_habilidad_activada(carta: Card, habilidad_id: int) -> void:
	var nombre_hab: String = carta.habilidad_nombre
	if nombre_hab == "":
		nombre_hab = "Habilidad %d" % habilidad_id
	_añadir_log("%s usó: %s" % [carta.propietario.capitalize(), nombre_hab])
	_set_feedback("")


# ═════════════════════════════════════════════
#  ACTUALIZACIÓN DE LA UI
# ═════════════════════════════════════════════
func _actualizar_turno_ui(turno: String) -> void:
	info_turno_label.text = "Turno: %s" % turno.capitalize()
	var es_mi_turno: bool = (turno == "jugador")
	_set_botones_accion(es_mi_turno)
	boton_acabar_turno.disabled = not es_mi_turno


func _actualizar_vida_ui(quien: String, vida: int, vida_max: int) -> void:
	var label: Label       = jugador_vida_label if quien == "jugador" else oponente_vida_label
	var bar:   ProgressBar = jugador_vida_bar   if quien == "jugador" else oponente_vida_bar
	label.text    = "Vida: %d/%d" % [vida, vida_max]
	bar.max_value = vida_max
	bar.value     = vida


func _actualizar_mana_ui(quien: String, mana: int, mana_max: int) -> void:
	var label: Label       = jugador_mana_label if quien == "jugador" else oponente_mana_label
	var bar:   ProgressBar = jugador_mana_bar   if quien == "jugador" else oponente_mana_bar
	label.text    = "Mana: %d/%d" % [mana, mana_max]
	bar.max_value = mana_max
	bar.value     = mana


func _actualizar_baraja_ui(quien: String) -> void:
	var p: Dictionary = GameManager._get_jugador(quien)
	var container: HBoxContainer = jugador_cartas_baraja if quien == "jugador" \
								   else oponente_cartas_baraja
	var total: int = p["baraja"].size()
	var n_hijos: int = container.get_child_count()
	# Muestra los primeros `total` hijos, oculta el resto
	for i in n_hijos:
		container.get_child(i).visible = (i < total)


func _refrescar_info_jugador(quien: String) -> void:
	var p: Dictionary = GameManager._get_jugador(quien)
	if p.is_empty(): return
	_actualizar_vida_ui(quien, p["vida"],        GameManager.VIDA_MAXIMA)
	_actualizar_mana_ui(quien, p["mana_actual"], p["mana_maximo"])


# ═════════════════════════════════════════════
#  INSTANCIACIÓN VISUAL DE CARTAS
# ═════════════════════════════════════════════

func _instanciar_carta_en_mano(quien: String, datos: Dictionary) -> void:
	var carta_nodo: Card = CARD_SCENE.instantiate()
	var org: HBoxContainer = jugador_disponibles_org if quien == "jugador" \
							 else oponente_disponibles_org

	# add_child PRIMERO para que _ready() inicialice los @onready antes de cargar datos
	org.add_child(carta_nodo)
	carta_nodo.propietario = quien

	# Carga los datos (usa claves del JSON: "name", "type", "attack"...)
	carta_nodo.cargar_desde_json(datos)

	# Cartas del oponente: mostrar_reverso DESPUÉS de add_child (nodos ya inicializados)
	if quien == "oponente":
		carta_nodo.mostrar_reverso = true

	# Conecta señal de muerte
	if not carta_nodo.carta_muerta.is_connected(_on_carta_nodo_muerta):
		carta_nodo.carta_muerta.connect(_on_carta_nodo_muerta)

	# Conecta drag & drop solo para cartas del jugador
	if quien == "jugador":
		var drag = get_parent()
		if drag and drag.has_method("connect_card"):
			drag.connect_card(carta_nodo)


func _on_carta_nodo_muerta(carta: Card) -> void:
	_añadir_log("%s murió: '%s'" % [carta.propietario.capitalize(), carta.nombre])
	var cementerio: HBoxContainer = jugador_cementerio if carta.propietario == "jugador" \
										else oponente_cementerio
	_mover_nodo_a_cementerio(carta, cementerio)


## Conecta la señal carta_muerta a un nodo Card (usado por BotManager y CardDragDrop)
func conectar_carta_muerta(carta: Card) -> void:
	if not carta.carta_muerta.is_connected(_on_carta_nodo_muerta):
		carta.carta_muerta.connect(_on_carta_nodo_muerta)


func _get_todos_los_slots(propietario: String) -> Array:
	var raiz: Node = get_parent()
	var zona: String = "Jugador" if propietario == "jugador" else "Oponente"
	var despliegue_base: String = "DespliegueJugador" if propietario == "jugador" else "DespliegueOponente"
	var slots: Array = []
	var base: Node = raiz.get_node_or_null("%s/%s" % [zona, despliegue_base])
	if base == null:
		return slots
	for hijo in base.get_children():
		if "Slot" in hijo.name:
			slots.append(hijo)
		else:
			for nieto in hijo.get_children():
				if "Slot" in nieto.name:
					slots.append(nieto)
	return slots


func _mover_nodo_a_cementerio(nodo: Card, cementerio: HBoxContainer) -> void:
	# Quita resaltados
	var panel_carta: Panel = nodo.get_node_or_null("Carta")
	if panel_carta:
		panel_carta.remove_theme_stylebox_override("panel")
	if nodo.has_method("restaurar_color_fondo"):
		nodo.restaurar_color_fondo()
	# Saca del grupo desplegadas
	if nodo.is_in_group("desplegadas"):
		nodo.remove_from_group("desplegadas")
	# Mueve visualmente
	var padre: Node = nodo.get_parent()
	if padre:
		padre.remove_child(nodo)
	cementerio.add_child(nodo)
	nodo.layout_mode         = 0
	nodo.anchor_left         = 0.0
	nodo.anchor_top          = 0.0
	nodo.anchor_right        = 0.0
	nodo.anchor_bottom       = 0.0
	nodo.custom_minimum_size = Vector2(80, 110)
	nodo.size                = Vector2(80, 110)
	nodo.mostrar_reverso     = false
	nodo.mouse_filter        = Control.MOUSE_FILTER_IGNORE


func _instanciar_carta_en_cementerio(quien: String, datos: Dictionary) -> void:
	var carta_nodo: Card = CARD_SCENE.instantiate()
	var cementerio: HBoxContainer = jugador_cementerio if quien == "jugador" \
								   else oponente_cementerio
	cementerio.add_child(carta_nodo)
	carta_nodo.propietario        = quien
	carta_nodo.layout_mode         = 0
	carta_nodo.custom_minimum_size = Vector2(80, 110)
	carta_nodo.size                = Vector2(80, 110)
	carta_nodo.cargar_desde_json(datos)
	carta_nodo.mostrar_reverso     = false
	carta_nodo.mouse_filter        = Control.MOUSE_FILTER_IGNORE


# ═════════════════════════════════════════════
#  LOG DE PARTIDA
# ═════════════════════════════════════════════
func _añadir_log(texto: String) -> void:
	_log_lineas.append(texto)
	if _log_lineas.size() > LOG_MAX_LINEAS:
		_log_lineas.pop_front()
	log_label.text = "\n".join(_log_lineas)


# ═════════════════════════════════════════════
#  FEEDBACK
# ═════════════════════════════════════════════
func _set_feedback(texto: String) -> void:
	feedback_label.text = texto
	if texto != "":
		get_tree().create_timer(3.0).timeout.connect(
			func(): if is_instance_valid(feedback_label): feedback_label.text = ""
		)


# ═════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════
func _on_botones_actualizados(atacar_disabled: bool, habilidad_disabled: bool, nombre_habilidad: String) -> void:
	boton_atacar.disabled    = atacar_disabled
	boton_habilidad.disabled = habilidad_disabled
	# Muestra el nombre de la habilidad activa en el botón, o el texto por defecto
	boton_habilidad.text = nombre_habilidad if nombre_habilidad != "" else "Habilidad"


func _on_carta_evolucionada(carta_vieja: Card, id_nueva: int, propietario: String) -> void:
	# 1. Mueve al cementerio las cartas de la mano que ya no están en p["mano"]
	var p: Dictionary = GameManager._get_jugador(propietario)
	var org: HBoxContainer = jugador_disponibles_org if propietario == "jugador" else oponente_disponibles_org
	var cementerio_evo: HBoxContainer = jugador_cementerio if propietario == "jugador" else oponente_cementerio
	# Construye un contador de IDs en mano (para manejar duplicados correctamente)
	var contador_mano: Dictionary = {}
	for dato in p["mano"]:
		var mid: int = int(dato.get("id", -1))
		if mid != -1:
			contador_mano[mid] = contador_mano.get(mid, 0) + 1

	# Recorre nodos visuales: descarta los que superan la cantidad en mano
	var contador_vistos: Dictionary = {}
	var a_descartar: Array = []
	for hijo in org.get_children():
		if not (hijo is Card) or hijo.id == -1:
			continue
		var hid: int = hijo.id
		contador_vistos[hid] = contador_vistos.get(hid, 0) + 1
		var en_mano: int    = contador_mano.get(hid, 0)
		var vistos: int     = contador_vistos[hid]
		if vistos > en_mano:
			a_descartar.append(hijo)

	for nodo in a_descartar:
		_mover_nodo_a_cementerio(nodo, cementerio_evo)

	# 2. Sustituye la carta en el slot: instancia la nueva y elimina la vieja
	var slot_padre: Node = carta_vieja.get_parent()
	if slot_padre == null:
		return

	# Instancia la nueva carta desde CardLoader
	var datos_nuevos: Dictionary = CardLoader.get_carta(id_nueva)
	if datos_nuevos.is_empty():
		return

	var carta_nueva: Card = CARD_SCENE.instantiate()
	slot_padre.add_child(carta_nueva)
	carta_nueva.propietario = propietario
	carta_nueva.cargar_desde_json(datos_nuevos)
	carta_nueva.layout_mode = 1
	carta_nueva.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	carta_nueva.add_to_group("desplegadas")
	conectar_carta_muerta(carta_nueva)
	carta_nueva.usada_este_turno = true   # ya actuó este turno (evolucionó)

	# Actualiza el dict interno de monstruos con la nueva id
	for i in p["monstruos"].size():
		if int(p["monstruos"][i].get("id", -1)) == carta_vieja.id:
			p["monstruos"][i] = datos_nuevos
			break

	# Elimina la carta vieja del slot (sin cementerio)
	carta_vieja.remove_from_group("desplegadas")
	carta_vieja.queue_free()

	_añadir_log("%s evolucionó a '%s'" % [propietario.capitalize(), datos_nuevos.get("name","???")])


func _set_botones_accion(activos: bool) -> void:
	# Los botones de combate los gestiona SelectionManager._actualizar_botones()
	# Este método se mantiene para el estado inicial (desactivar al arrancar)
	if not activos:
		boton_atacar.disabled    = true
		boton_habilidad.disabled = true


func _formato_tiempo(segundos: float) -> String:
	var s: int = int(segundos)
	return "%02d:%02d" % [s / 60, s % 60]
