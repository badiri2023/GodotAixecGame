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

## Carta seleccionada para atacar o usar habilidad (lógica pendiente próxima fase)
var _carta_seleccionada: Card = null

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
	# (p.ej. desde el Login), sincronizamos el estado completo ahora.
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
	# Ticks de AbilityManager al cambiar de turno
	AbilityManager.tick_efectos_turno()
	if turno == "jugador":
		AbilityManager.tick_paciencia("jugador")


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
	_añadir_log("%s → cementerio: '%s'" % [quien.capitalize(), carta.get("nombre","???")])
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
	_carta_seleccionada = null
	_set_feedback("")
	GameManager.acabar_turno("jugador")


func _on_boton_atacar() -> void:
	if not GameManager.es_mi_turno("jugador"):
		_set_feedback("No es tu turno")
		return
	if GameManager.solo_despliegue:
		_set_feedback("Ronda 1: solo se pueden desplegar cartas")
		return
	if _carta_seleccionada == null:
		_set_feedback("Selecciona una carta para atacar")
		return
	# TODO: lógica de ataque — próxima fase


func _on_boton_habilidad() -> void:
	if not GameManager.es_mi_turno("jugador"):
		_set_feedback("No es tu turno")
		return
	if GameManager.solo_despliegue:
		_set_feedback("Ronda 1: solo se pueden desplegar cartas")
		return
	if _carta_seleccionada == null:
		_set_feedback("Selecciona una carta para usar su habilidad")
		return
	AbilityManager.activar_habilidad_activa(_carta_seleccionada, "jugador")


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
	org.add_child(carta_nodo)
	carta_nodo.propietario = quien
	carta_nodo.cargar_desde_json(datos)

	# Cartas del oponente en mano: boca abajo
	if quien == "oponente":
		carta_nodo.mostrar_reverso = true

	# Conecta señal de muerte
	carta_nodo.carta_muerta.connect(_on_carta_nodo_muerta)

	# Conecta drag & drop para cartas del jugador robadas en runtime
	if quien == "jugador":
		var panel: Panel = carta_nodo.get_node_or_null("Carta")
		if panel:
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
			if not panel.gui_input.is_connected(_on_carta_mano_gui_input.bind(carta_nodo)):
				panel.gui_input.connect(_on_carta_mano_gui_input.bind(carta_nodo))


## Redirige el gui_input de una carta recién robada al CardDragDrop del nodo padre.
func _on_carta_mano_gui_input(event: InputEvent, carta: Card) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Llama directamente al método de drag del nodo Control padre
		var drag_script = get_parent()
		if drag_script.has_method("_start_drag"):
			drag_script._start_drag(carta)


func _on_carta_nodo_muerta(carta: Card) -> void:
	AbilityManager.notificar_evento(AbilityManager.EVENTO_CARTA_MUERTA, {
		"carta":       carta,
		"propietario": carta.propietario
	})
	_añadir_log("%s murió: '%s'" % [carta.propietario.capitalize(), carta.nombre])


func _instanciar_carta_en_cementerio(quien: String, datos: Dictionary) -> void:
	var carta_nodo: Card = CARD_SCENE.instantiate()
	var cementerio: HBoxContainer = jugador_cementerio if quien == "jugador" \
								   else oponente_cementerio
	cementerio.add_child(carta_nodo)
	carta_nodo.propietario = quien
	carta_nodo.cargar_desde_json(datos)
	carta_nodo.mostrar_reverso = false
	carta_nodo.mouse_filter    = Control.MOUSE_FILTER_IGNORE


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
func _set_botones_accion(activos: bool) -> void:
	# Atacar y Habilidad solo disponibles desde ronda 2
	var puede_combatir: bool = activos and not GameManager.solo_despliegue
	boton_atacar.disabled    = not puede_combatir
	boton_habilidad.disabled = not puede_combatir


func _formato_tiempo(segundos: float) -> String:
	var s: int = int(segundos)
	return "%02d:%02d" % [s / 60, s % 60]
