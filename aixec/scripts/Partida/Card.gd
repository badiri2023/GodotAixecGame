extends Control
class_name Card
# Card.gd — adjunta al nodo raíz "CartaControl" de Card.tscn


# ═════════════════════════════════════════════
#  SEÑALES
# ═════════════════════════════════════════════
signal carta_muerta(carta: Card)


# ═════════════════════════════════════════════
#  CONSTANTES
# ═════════════════════════════════════════════
const TIPO_MONSTRUO:     int = 1
const TIPO_HECHIZO:      int = 2
const TIPO_EQUIPAMIENTO: int = 3

const RAREZA_COMUN:      int = 1
const RAREZA_RARO:       int = 2
const RAREZA_LEGENDARIO: int = 3

const COLOR_MONSTRUO:     Color = Color(0.55, 0.05, 0.05, 1.0)
const COLOR_HECHIZO:      Color = Color(0.05, 0.10, 0.55, 1.0)
const COLOR_EQUIPAMIENTO: Color = Color(0.05, 0.40, 0.10, 1.0)
const COLOR_DEFAULT:      Color = Color(0.15, 0.15, 0.15, 1.0)


# ═════════════════════════════════════════════
#  DATOS INMUTABLES (JSON)
# ═════════════════════════════════════════════
var id:          int    = -1
var nombre:      String = ""
var descripcion: String = ""
var expansion:   String = ""
var tipo:        int    = -1
var rareza:      int    = RAREZA_COMUN
var mana_coste:  int    = 0
var image_url:   String = ""

var ataque_base:  int = 0
var defensa_base: int = 0   # vida máxima base

var habilidad_id:          int    = -1
var habilidad_nombre:      String = ""
var habilidad_descripcion: String = ""
var habilidad_es_pasiva:   bool   = false


# ═════════════════════════════════════════════
#  DATOS MUTABLES (runtime)
# ═════════════════════════════════════════════

## Vida actual (solo monstruos)
var vida_actual: int = 0

## Ataque actual (puede variar por buff de equipamiento global)
var ataque_actual: int = 0

## true si ya recibió el buff del equipamiento global del slot
var buffed: bool = false

## true si ya actuó este turno (atacó o usó habilidad activa)
var usada_este_turno: bool = false

## "jugador" | "oponente"
var propietario: String = ""

## true = mostrar reverso (en mano enemiga)
var mostrar_reverso: bool = false:
	set(valor):
		mostrar_reverso = valor
		if is_node_ready():
			_actualizar_visibilidad_reverso()
		else:
			ready.connect(_actualizar_visibilidad_reverso, CONNECT_ONE_SHOT)


# ═════════════════════════════════════════════
#  REFERENCIAS A NODOS
# ═════════════════════════════════════════════
@onready var panel_carta:       Panel       = $Carta
@onready var imagen_carta:      TextureRect = $Carta/ImgPanel/ImagenCarta
@onready var nombre_label:      Label       = $Carta/ImgPanel/NombrePanel/NombreLabel
@onready var calidad_label:     Label       = $Carta/ImgPanel/CalidadPanel/CalidadLabel
@onready var habilidad_label:   Label       = $Carta/HabilidadPanel/HabilidadLabel
@onready var atk_label:         Label       = $Carta/StatsPanel/AtkPanel/AtkLabel
@onready var mana_label:        Label       = $Carta/StatsPanel/ManaPanel/ManaLabel
@onready var vida_label:        Label       = $Carta/StatsPanel/VidaPanel/VidaLabel
@onready var descripcion_label: Label       = $Carta/DescripcionPanel/DescripcionLabel
@onready var card_reverse:      Control     = $Carta/CardReverse
@onready var atk_panel:         Panel       = $Carta/StatsPanel/AtkPanel
@onready var vida_panel:        Panel       = $Carta/StatsPanel/VidaPanel


# ═════════════════════════════════════════════
#  INICIALIZACIÓN
# ═════════════════════════════════════════════
func _ready() -> void:
	_actualizar_visibilidad_reverso()


# ═════════════════════════════════════════════
#  CARGA DESDE JSON
# ═════════════════════════════════════════════
func cargar_desde_json(datos: Dictionary) -> void:
	id          = datos.get("id",          -1)
	nombre      = datos.get("name",        "???")
	descripcion = datos.get("description", "")
	expansion   = datos.get("expansion",   "")
	tipo        = datos.get("type",        -1)
	rareza      = datos.get("rarity",      RAREZA_COMUN)
	mana_coste  = datos.get("mana",        0)
	image_url   = datos.get("imageUrl",    "")

	ataque_base  = datos.get("attack",  0)
	defensa_base = datos.get("defense", 0)
	ataque_actual = ataque_base
	vida_actual   = defensa_base

	var hab: Dictionary = datos.get("ability", {})
	habilidad_id          = hab.get("id",          -1)
	habilidad_nombre      = hab.get("name",        "")
	habilidad_descripcion = hab.get("description", "")
	habilidad_es_pasiva   = hab.get("isPassive",   false)

	buffed = false
	# Si el nodo ya paso por _ready() los @onready existen y podemos actualizar
	# la UI directamente. Si no (instanciacion antes de add_child), lo diferimos
	# al siguiente frame cuando _ready() ya habra corrido.
	if is_node_ready():
		_refrescar_visual()
	else:
		ready.connect(_refrescar_visual, CONNECT_ONE_SHOT)


# ═════════════════════════════════════════════
#  BUFF DE EQUIPAMIENTO GLOBAL
# Aplica / revierte el buff del equipamiento colocado en el slot global.
# Se llama desde GameManager al poner o retirar el equipamiento del slot.
# Afecta SOLO a cartas de TIPO_MONSTRUO; el mana NO se suma.
# ═════════════════════════════════════════════

func aplicar_buff_equipamiento(equip: Card) -> void:
	if tipo != TIPO_MONSTRUO or buffed:
		return
	ataque_actual += equip.ataque_base
	vida_actual   += equip.defensa_base
	buffed = true
	_actualizar_textos()
	print("[Card] '%s' bufeada: +%d atk, +%d vida (equip: '%s')" % [
		nombre, equip.ataque_base, equip.defensa_base, equip.nombre
	])


func revertir_buff_equipamiento(equip: Card) -> void:
	if tipo != TIPO_MONSTRUO or not buffed:
		return
	ataque_actual = max(0, ataque_actual - equip.ataque_base)
	vida_actual   = max(1, vida_actual   - equip.defensa_base)
	buffed = false
	_actualizar_textos()
	print("[Card] Buff revertido en '%s' (equip: '%s')" % [nombre, equip.nombre])


# ═════════════════════════════════════════════
#  VISUAL
# ═════════════════════════════════════════════
func _refrescar_visual() -> void:
	_actualizar_textos()
	_actualizar_color_fondo()
	_actualizar_stats_visibilidad()
	_actualizar_visibilidad_reverso()
	_cargar_imagen()


func _actualizar_textos() -> void:
	nombre_label.text      = nombre
	descripcion_label.text = descripcion
	calidad_label.text     = _texto_rareza(rareza)
	mana_label.text        = "Mana: %d" % mana_coste
	habilidad_label.text   = habilidad_nombre if habilidad_nombre != "" else habilidad_descripcion
	atk_label.text         = "Atk: %d"  % ataque_actual
	vida_label.text        = "Vida: %d" % vida_actual


func _actualizar_color_fondo() -> void:
	var color: Color = COLOR_DEFAULT
	match tipo:
		TIPO_MONSTRUO:     color = COLOR_MONSTRUO
		TIPO_HECHIZO:      color = COLOR_HECHIZO
		TIPO_EQUIPAMIENTO: color = COLOR_EQUIPAMIENTO
	panel_carta.modulate = color


func _actualizar_stats_visibilidad() -> void:
	# Equipamiento muestra su atk/def como bonus, pero no tiene vida propia en juego
	atk_panel.visible  = (tipo == TIPO_MONSTRUO or tipo == TIPO_EQUIPAMIENTO)
	vida_panel.visible = (tipo == TIPO_MONSTRUO or tipo == TIPO_EQUIPAMIENTO)


func _actualizar_visibilidad_reverso() -> void:
	if not is_node_ready():
		return
	card_reverse.visible = mostrar_reverso
	imagen_carta.visible = not mostrar_reverso
	panel_carta.visible  = not mostrar_reverso


func _cargar_imagen() -> void:
	if image_url == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_imagen_cargada.bind(http))
	if http.request(image_url) != OK:
		push_warning("[Card] Error al pedir imagen: %s" % image_url)
		http.queue_free()


func _on_imagen_cargada(result: int, _code: int, _headers: PackedStringArray,
						body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(body) != OK:
		if img.load_png_from_buffer(body) != OK:
			return
	imagen_carta.texture = ImageTexture.create_from_image(img)


func _texto_rareza(r: int) -> String:
	match r:
		RAREZA_COMUN:      return "Común"
		RAREZA_RARO:       return "Raro"
		RAREZA_LEGENDARIO: return "Legendario"
		_:                 return "?"


# ═════════════════════════════════════════════
#  VIDA Y DAÑO
# ═════════════════════════════════════════════
func recibir_danyo(cantidad: int) -> void:
	if tipo != TIPO_MONSTRUO:
		return
	vida_actual -= cantidad
	vida_label.text = "Vida: %d" % vida_actual
	print("[Card] '%s' recibe %d daño — vida: %d" % [nombre, cantidad, vida_actual])
	if vida_actual <= 0:
		emit_signal("carta_muerta", self)


func recibir_curacion(cantidad: int) -> void:
	if tipo != TIPO_MONSTRUO:
		return
	# El tope de vida incluye el bonus del equipamiento global si está bufeada
	var bonus_vida: int = GameManager.get_buff_vida_equip(propietario) if buffed else 0
	var vida_max: int = defensa_base + bonus_vida
	vida_actual = min(vida_actual + cantidad, vida_max)
	vida_label.text = "Vida: %d" % vida_actual


# ═════════════════════════════════════════════
#  TURNO
# ═════════════════════════════════════════════
func resetear_turno() -> void:
	usada_este_turno = false


func marcar_como_usada() -> bool:
	if usada_este_turno:
		print("[Card] '%s' ya fue usada este turno" % nombre)
		return false
	usada_este_turno = true
	return true


# ═════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════
func tiene_habilidad_activa() -> bool:
	return habilidad_id >= 0 and not habilidad_es_pasiva


func get_datos_actuales() -> Dictionary:
	return {
		"id":                  id,
		"nombre":              nombre,
		"tipo":                tipo,
		"rareza":              rareza,
		"mana":                mana_coste,
		"expansion":           expansion,
		"ataque_base":         ataque_base,
		"ataque_actual":       ataque_actual,
		"defensa_base":        defensa_base,
		"vida_actual":         vida_actual,
		"buffed":              buffed,
		"habilidad_id":        habilidad_id,
		"habilidad_nombre":    habilidad_nombre,
		"habilidad_es_pasiva": habilidad_es_pasiva,
		"usada_este_turno":    usada_este_turno,
		"propietario":         propietario,
	}
