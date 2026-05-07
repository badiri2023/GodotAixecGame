extends Control

# ─────────────────────────────────────────
#  DATOS
# ─────────────────────────────────────────
var card_data = {
	"id":          0,
	"name":        "",
	"type":        1,
	"rarity":      1,
	"expansion":   "",
	"description": "",
	"imageUrl":    "",
	"attack":      0,
	"defense":     0,
	"mana":        0,
	"ability": {
		"id":          0,
		"name":        "",
		"description": "",
		"isPassive":   false
	}
}

var defense_actual  : int  = 0
var puede_actuar    : bool = true
var esta_desplegada : bool = false
var reverso_visible : bool = false
var equipamiento           = null
var _datos_pendientes : Dictionary = {}

var arrastrando      : bool    = false
var offset_arrastre  : Vector2 = Vector2.ZERO

# ─────────────────────────────────────────
#  REFERENCIAS UI
# ─────────────────────────────────────────
@onready var carta_panel       : Panel       = $Carta
@onready var imagen_carta      : TextureRect = $Carta/ImgPanel/ImagenCarta
@onready var nombre_label      : Label       = $Carta/ImgPanel/NombrePanel/NombreLabel
@onready var calidad_label     : Label       = $Carta/ImgPanel/CalidadPanel/CalidadLabel
@onready var habilidad_label   : Label       = $Carta/HabilidadPanel/HabilidadLabel
@onready var atk_label         : Label       = $Carta/StatsPanel/AtkPanel/AtkLabel
@onready var mana_label        : Label       = $Carta/StatsPanel/ManaPanel/ManaLabel
@onready var vida_label        : Label       = $Carta/StatsPanel/VidaPanel/VidaLabel
@onready var descripcion_label : Label       = $Carta/DescripcionPanel/DescripcionLabel
@onready var atk_panel         : Panel       = $Carta/StatsPanel/AtkPanel
@onready var vida_panel        : Panel       = $Carta/StatsPanel/VidaPanel
@onready var card_reverse      : Control     = $Carta/CardReverse
@onready var boton_carta       : Button      = $Carta/Button

var http_request : HTTPRequest

signal carta_seleccionada(carta)
signal carta_muerta(carta)
signal carta_arrastrada(carta)

# ─────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────
func inicializar(datos: Dictionary):
	_datos_pendientes = datos.duplicate(true)
	if is_node_ready():
		_aplicar_datos(_datos_pendientes)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	carta_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(160, 230)

	boton_carta.pressed.connect(_on_boton_carta_pressed)
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_imagen_descargada)

	if not _datos_pendientes.is_empty():
		_aplicar_datos(_datos_pendientes)

func _aplicar_datos(datos: Dictionary):
	card_data      = datos.duplicate(true)
	defense_actual = card_data["defense"]
	actualizar_ui()
	boton_carta.visible = true

# ─────────────────────────────────────────
#  INPUT Y ARRASTRE
# ─────────────────────────────────────────
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not esta_desplegada:
			arrastrando     = true
			offset_arrastre = global_position - get_global_mouse_position()
			# Salir del HBoxContainer para moverse libremente por la escena
			var pos_global  = global_position
			var escena_raiz = get_tree().current_scene
			get_parent().remove_child(self)
			escena_raiz.add_child(self)
			global_position = pos_global
		elif not event.pressed and arrastrando:
			arrastrando = false
			emit_signal("carta_arrastrada", self)

func _process(_delta):
	if arrastrando:
		global_position = get_global_mouse_position() + offset_arrastre

func _on_boton_carta_pressed():
	emit_signal("carta_seleccionada", self)

# ─────────────────────────────────────────
#  REVERSO
# ─────────────────────────────────────────
func mostrar_reverso():
	card_reverse.visible = true
	reverso_visible      = true
	boton_carta.visible  = false

func ocultar_reverso():
	card_reverse.visible = false
	reverso_visible      = false
	boton_carta.visible  = true

func set_reverso(activo: bool):
	if activo:
		mostrar_reverso()
	else:
		ocultar_reverso()

# ─────────────────────────────────────────
#  UI
# ─────────────────────────────────────────
func actualizar_ui():
	nombre_label.text      = card_data["name"]
	calidad_label.text     = _rareza_texto(card_data["rarity"])
	descripcion_label.text = card_data["description"]
	habilidad_label.text   = card_data["ability"]["description"] \
		if card_data["ability"]["description"] != "" \
		else "Sin habilidad"

	_cargar_imagen(card_data["imageUrl"])
	_actualizar_stats()
	_aplicar_color_tipo(card_data["type"])

func _actualizar_stats():
	match card_data["type"]:
		1:  # Monstruo
			atk_label.text     = "Atk: %d"  % card_data["attack"]
			mana_label.text    = "Mana: %d" % card_data["mana"]
			vida_label.text    = "Vida: %d" % defense_actual
			atk_panel.visible  = true
			vida_panel.visible = true
		2:  # Hechizo
			mana_label.text    = "Mana: %d" % card_data["mana"]
			atk_panel.visible  = false
			vida_panel.visible = false
		3:  # Equipamiento
			atk_label.text     = "+Atk: %d"  % card_data["attack"]
			mana_label.text    = "Mana: %d"  % card_data["mana"]
			vida_label.text    = "+Vida: %d" % card_data["defense"]
			atk_panel.visible  = true
			vida_panel.visible = true

func _aplicar_color_tipo(tipo: int):
	var color_fondo: Color
	match tipo:
		1: color_fondo = Color(0.85, 0.20, 0.20)
		2: color_fondo = Color(0.20, 0.35, 0.85)
		3: color_fondo = Color(0.20, 0.70, 0.30)
		_: color_fondo = Color(0.80, 0.80, 0.80)

	var style = StyleBoxFlat.new()
	style.bg_color                   = color_fondo
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.corner_detail              = 5
	carta_panel.add_theme_stylebox_override("panel", style)

func _rareza_texto(rarity: int) -> String:
	match rarity:
		1: return "Común"
		2: return "Rara"
		3: return "Legendaria"
		_: return "Común"

# ─────────────────────────────────────────
#  IMAGEN REMOTA
# ─────────────────────────────────────────
func _cargar_imagen(url: String):
	if url == "" or url == null:
		return
	if url.begins_with("res://"):
		var tex = load(url)
		if tex:
			imagen_carta.texture = tex
		return
	if url.begins_with("http"):
		http_request.request(url)

func _on_imagen_descargada(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("Card: Error al cargar imagen result=%d code=%d" % [result, response_code])
		return
	var image = Image.new()
	var error : int
	if body[0] == 0xFF and body[1] == 0xD8:
		error = image.load_jpg_from_buffer(body)
	else:
		error = image.load_png_from_buffer(body)
	if error != OK:
		push_warning("Card: Error al procesar imagen: %d" % error)
		return
	imagen_carta.texture = ImageTexture.create_from_image(image)

# ─────────────────────────────────────────
#  EQUIPAMIENTO
# ─────────────────────────────────────────
func equipar(carta_equip) -> bool:
	if card_data["type"] != 1:
		return false
	if equipamiento != null:
		return false
	equipamiento        = carta_equip
	defense_actual      += carta_equip.card_data["defense"]
	card_data["attack"] += carta_equip.card_data["attack"]
	actualizar_ui()
	return true

# ─────────────────────────────────────────
#  COMBATE
# ─────────────────────────────────────────
func recibir_danio(cantidad: int) -> int:
	if card_data["ability"]["id"] == 4:
		if cantidad < defense_actual:
			return 0
	if card_data["ability"]["id"] == 24:
		if randf() <= 0.01:
			return 0

	defense_actual -= cantidad
	actualizar_ui()

	if defense_actual <= 0:
		var sobrante = abs(defense_actual)
		emit_signal("carta_muerta", self)
		queue_free()
		return sobrante

	if card_data["ability"]["id"] == 6:
		return -cantidad

	return 0

func resetear_turno():
	puede_actuar = true

# ─────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────
func get_mana_cost() -> int:
	return card_data["mana"]

func get_ability_id() -> int:
	return card_data["ability"]["id"]

func get_ability_name() -> String:
	return card_data["ability"]["name"]

func get_equip_ability_id() -> int:
	if equipamiento != null:
		return equipamiento.card_data["ability"]["id"]
	return 0

func get_equip_ability_name() -> String:
	if equipamiento != null:
		return equipamiento.card_data["ability"]["name"]
	return ""

func is_passive() -> bool:
	return card_data["ability"]["isPassive"]

func tiene_habilidad() -> bool:
	return card_data["ability"]["id"] != 0

func tiene_habilidad_activa_propia() -> bool:
	return not card_data["ability"]["isPassive"] and card_data["ability"]["id"] != 0

func tiene_habilidad_activa_equip() -> bool:
	if equipamiento == null:
		return false
	return not equipamiento.card_data["ability"]["isPassive"] \
		and equipamiento.card_data["ability"]["id"] != 0

func tiene_alguna_habilidad_activa() -> bool:
	return tiene_habilidad_activa_propia() or tiene_habilidad_activa_equip()
