extends Panel

# ─────────────────────────────────────────
#  DATOS (formato cards.json)
# ─────────────────────────────────────────
var card_data = {
	"id":          0,
	"name":        "",
	"type":        1,        # 1=Monstruo 2=Hechizo 3=Equipamiento
	"rarity":      1,        # 1=Común 2=Rara 3=Legendaria
	"expansion":   "",       # backend, sin uso por ahora
	"description": "",
	"imageUrl":    "",
	"attack":      0,
	"defense":     0,
	"mana":        0,
	"isPassive":   false,    # backend
	"ability": {
		"id":          0,    # backend — se resuelve en CardDatabase.gd
		"name":        "",   # se usa en el panel de acciones al seleccionar carta
		"description": ""    # visible en HabilidadLabel
	}
}

# Estado en partida
var defense_actual: int   = 0
var puede_actuar:   bool  = true
var esta_desplegada: bool = false

# Equipamiento vinculado (solo monstruos, 1 máximo)
var equipamiento = null   # referencia a otro nodo Card de tipo equipamiento

# ─────────────────────────────────────────
#  REFERENCIAS UI  (rutas exactas del .tscn)
# ─────────────────────────────────────────
@onready var imagen_carta    : TextureRect = $ImgPanel/ImagenCarta
@onready var nombre_label    : Label       = $ImgPanel/NombrePanel/NombreLabel
@onready var calidad_label   : Label       = $ImgPanel/CalidadPanel/CalidadLabel
@onready var habilidad_label : Label       = $HabilidadPanel/HabilidadLabel
@onready var atk_label       : Label       = $StatsPanel/AtkPanel/AtkLabel
@onready var mana_label      : Label       = $StatsPanel/ManaPanel/ManaLabel
@onready var vida_label      : Label       = $StatsPanel/VidaPanel/VidaLabel
@onready var descripcion_label : Label     = $DescripcionPanel/DescripcionLabel
@onready var boton_carta     : Button      = $Button

signal carta_seleccionada(carta)
signal carta_muerta(carta)


# ─────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────
# Añade este nodo al _ready()
var http_request: HTTPRequest

func _ready():
	boton_carta.pressed.connect(_on_boton_carta_pressed)
	
	# Crear HTTPRequest dinámicamente
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_imagen_descargada)

func inicializar(datos: Dictionary):
	card_data      = datos.duplicate(true)
	defense_actual = card_data["defense"]
	actualizar_ui()

# ─────────────────────────────────────────
#  UI
# ─────────────────────────────────────────
func actualizar_ui():
	# Nombre
	nombre_label.text = card_data["name"]

	# Calidad / rareza
	calidad_label.text = _rareza_texto(card_data["rarity"])

	# Descripción de la habilidad (ability.description)
	habilidad_label.text = card_data["ability"]["description"] \
		if card_data["ability"]["description"] != "" \
		else "Sin habilidad"

	# Descripción de la carta
	descripcion_label.text = card_data["description"]

	# Imagen
	_cargar_imagen(card_data["imageUrl"])

	# Stats y visibilidad según tipo
	_actualizar_stats()

	# Color de fondo según tipo
	_aplicar_color_tipo(card_data["type"])

	# Si tiene equipamiento, reflejar bonus
	if equipamiento != null:
		_actualizar_stats()   # recalcula con bonus ya aplicados

func _actualizar_stats():
	match card_data["type"]:
		1:  # Monstruo — muestra atk, mana y vida
			atk_label.text  = "Atk: %d"  % get_attack_total()
			mana_label.text = "Mana: %d" % card_data["mana"]
			vida_label.text = "Vida: %d" % defense_actual
			$StatsPanel/AtkPanel.visible  = true
			$StatsPanel/VidaPanel.visible = true

		2:  # Hechizo — solo mana, sin atk ni vida
			mana_label.text = "Mana: %d" % card_data["mana"]
			$StatsPanel/AtkPanel.visible  = false
			$StatsPanel/VidaPanel.visible = false

		3:  # Equipamiento — muestra bonus como +atk y +vida
			atk_label.text  = "+Atk: %d"  % card_data["attack"]
			mana_label.text = "Mana: %d"  % card_data["mana"]
			vida_label.text = "+Vida: %d" % card_data["defense"]
			$StatsPanel/AtkPanel.visible  = true
			$StatsPanel/VidaPanel.visible = true

func _cargar_imagen(url: String):
	if url == "" or url == null:
		return
	
	# Si es ruta local
	if url.begins_with("res://"):
		var tex = load(url)
		if tex:
			imagen_carta.texture = tex
		return
	
	# Si es URL HTTP
	if url.begins_with("http"):
		http_request.request(url)
		
func _on_imagen_descargada(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("Error al cargar imagen: result=%d code=%d" % [result, response_code])
		return
	
	# Detectar formato por los primeros bytes del archivo
	var image = Image.new()
	var error: int
	
	# JPG empieza con bytes FF D8
	# PNG empieza con bytes 89 50 4E 47
	if body[0] == 0xFF and body[1] == 0xD8:
		error = image.load_jpg_from_buffer(body)
	elif body[0] == 0x89 and body[1] == 0x50:
		error = image.load_png_from_buffer(body)
	else:
		# Intentar JPG por defecto (tus URLs son .jpg)
		error = image.load_jpg_from_buffer(body)
	
	if error != OK:
		push_warning("Error al procesar la imagen descargada: %d" % error)
		return
	
	imagen_carta.texture = ImageTexture.create_from_image(image)


func _aplicar_color_tipo(tipo: int):
	# El color de fondo de la carta cambia según el tipo
	# Se modifica el StyleBox heredado de CardColor.tres
	var color_fondo: Color
	match tipo:
		1: color_fondo = Color(0.85, 0.20, 0.20)   # Rojo    — Monstruo
		2: color_fondo = Color(0.20, 0.35, 0.85)   # Azul    — Hechizo
		3: color_fondo = Color(0.20, 0.70, 0.30)   # Verde   — Equipamiento
		_: color_fondo = Color(0.80, 0.80, 0.80)   # Gris    — fallback

	var style = StyleBoxFlat.new()
	style.bg_color                   = color_fondo
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.corner_detail              = 5
	add_theme_stylebox_override("panel", style)

func _rareza_texto(rarity: int) -> String:
	match rarity:
		1: return "Común"
		2: return "Rara"
		3: return "Legendaria"
		_: return "Común"

# ─────────────────────────────────────────
#  EQUIPAMIENTO
# ─────────────────────────────────────────
func equipar(carta_equip) -> bool:
	if card_data["type"] != 1:
		return false   # solo monstruos
	if equipamiento != null:
		return false   # ya tiene uno equipado
	equipamiento    = carta_equip
	defense_actual += carta_equip.card_data["defense"]
	actualizar_ui()
	return true

func desequipar():
	if equipamiento == null:
		return
	defense_actual = max(1, defense_actual - equipamiento.card_data["defense"])
	equipamiento   = null
	actualizar_ui()

# ─────────────────────────────────────────
#  COMBATE
# ─────────────────────────────────────────
func recibir_danio(cantidad: int) -> int:
	defense_actual -= cantidad
	actualizar_ui()
	if defense_actual <= 0:
		var sobrante = abs(defense_actual)
		emit_signal("carta_muerta", self)
		queue_free()
		return sobrante   # daño sobrante → va al jugador enemigo
	return 0

func resetear_turno():
	puede_actuar = true

# ─────────────────────────────────────────
#  HELPERS — usados desde Game.gd
# ─────────────────────────────────────────

# Ataque total (base + bonus de equipamiento si lo hay)
func get_attack_total() -> int:
	var total = card_data["attack"]
	if equipamiento != null:
		total += equipamiento.card_data["attack"]
	return total

func get_mana_cost() -> int:
	return card_data["mana"]

# ID de habilidad propia (para resolverla en CardDatabase)
func get_ability_id() -> int:
	return card_data["ability"]["id"]

# Nombre de habilidad propia (para mostrarlo en el panel de acciones)
func get_ability_name() -> String:
	return card_data["ability"]["name"]

# ID de habilidad del equipamiento (si lo tiene)
func get_equip_ability_id() -> int:
	if equipamiento != null:
		return equipamiento.card_data["ability"]["id"]
	return 0

# Nombre de habilidad del equipamiento (para el panel de acciones)
func get_equip_ability_name() -> String:
	if equipamiento != null:
		return equipamiento.card_data["ability"]["name"]
	return ""

# ¿Tiene habilidad activa propia?
func tiene_habilidad_activa_propia() -> bool:
	return not card_data["isPassive"] and card_data["ability"]["id"] != 0

# ¿Tiene habilidad activa del equipamiento?
func tiene_habilidad_activa_equip() -> bool:
	if equipamiento == null:
		return false
	return not equipamiento.card_data["isPassive"] and equipamiento.card_data["ability"]["id"] != 0

# ¿Tiene alguna habilidad activa disponible este turno?
func tiene_alguna_habilidad_activa() -> bool:
	return tiene_habilidad_activa_propia() or tiene_habilidad_activa_equip()

# ─────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────
func _on_boton_carta_pressed():
	emit_signal("carta_seleccionada", self)
