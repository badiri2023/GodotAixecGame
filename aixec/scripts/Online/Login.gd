# login.gd
extends Control

const API_BASE = "http://aixec.eu-north-1.elasticbeanstalk.com/api"
const CARDS_SAVE_PATH = "res://data/cards.json"

var _cargando: bool = false

@onready var email_input = $EmailInput
@onready var password_input = $PasswordInput
@onready var boton_login = $BotonLogin
@onready var label_error = $LabelError

func _ready() -> void:
	label_error.visible = false
	boton_login.pressed.connect(_on_login_pressed)

func _on_login_pressed() -> void:
	var email = email_input.text.strip_edges()
	var password = password_input.text

	if email == "" or not "@" in email:
		_mostrar_error("Introduce un email válido")
		return
	if password.length() < 6:
		_mostrar_error("La contraseña debe tener mínimo 6 caracteres")
		return

	_set_cargando(true)
	_hacer_login(email, password)

# ─────────────────────────────────────────────────────────────────────────────
# PASO 1: LOGIN
# ─────────────────────────────────────────────────────────────────────────────
func _hacer_login(email: String, password: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_login_completed.bind(http))

	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"email": email, "password": password})

	var error = http.request(API_BASE + "/auth/login", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		http.queue_free()
		_mostrar_error("Error de conexión con el servidor")
		_set_cargando(false)

func _on_login_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		_set_cargando(false)
		_mostrar_error("Error de red. Comprueba tu conexión.")
		return

	if response_code != 200:
		_set_cargando(false)
		_mostrar_error("Credenciales incorrectas")
		return

	var datos = JSON.parse_string(body.get_string_from_utf8())
	print("DEBUG: Respuesta completa del servidor: ", datos)
	if datos == null or not datos.has("token"):
		_set_cargando(false)
		_mostrar_error("Respuesta del servidor inválida")
		return

	# Guardamos sesión en el Autoload
	ApiServicio.token = datos["token"]
	ApiServicio.usuario_id = datos.get("id", 0)
	ApiServicio.usuario_nombre = datos.get("username", "Jugador")
	print("✅ Bienvenido, ", ApiServicio.usuario_nombre)

	# PASO 2: Descargar cards.json ANTES de continuar
	_set_boton_texto("Descargando cartas...")
	_descargar_cartas()

# ─────────────────────────────────────────────────────────────────────────────
# PASO 2: DESCARGAR Y GUARDAR cards.json
# ─────────────────────────────────────────────────────────────────────────────
func _descargar_cartas() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_cartas_completado.bind(http))

	var error = http.request(
		API_BASE + "/card/",
		ApiServicio.get_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		http.queue_free()
		_set_cargando(false)
		_mostrar_error("Error al descargar el catálogo de cartas")

func _on_cartas_completado(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_cargando(false)
		_mostrar_error("No se pudo obtener el catálogo de cartas (código: %d)" % response_code)
		return

	var json_list = JSON.parse_string(body.get_string_from_utf8())
	if json_list == null:
		_set_cargando(false)
		_mostrar_error("El catálogo de cartas recibido es inválido")
		return

	# Procesamos y guardamos el catálogo exactamente igual que en getCardsJson.gd
	var catalogo: Array = []
	for item in json_list:
		catalogo.append({
			"id":          int(item.get("id", 50)) if item.get("id") != null else 50,
			"name":        item.get("name", "Sin nombre"),
			"description": item.get("description", "Sin descripción"),
			"attack":      int(item.get("attack", 0)) if item.get("attack") != null else 0,
			"defense":     int(item.get("defense", 0)) if item.get("defense") != null else 0,
			"rarity":      int(item.get("rarity", 0)) if item.get("rarity") != null else 0,
			"ability": {
				"id":          int(item["ability"].get("id", 32)) if item.get("ability") and item["ability"].get("id") != null else 32,
				"name":        item["ability"].get("name", "") if item.get("ability") else "",
				"description": item["ability"].get("description", "") if item.get("ability") else "",
				"isPassive":   item["ability"].get("isPassive", false),
			},
			"expansion":   item.get("expansion", "Base"),
			"mana":        int(item.get("mana", 0)) if item.get("mana") != null else 0,
			"type":        int(item.get("type", 0)) if item.get("type") != null else 0,
			"imageUrl":    "http://aixec-card-images.s3.eu-north-1.amazonaws.com/card%s.jpg" % str(int(item.get("id", 50))).pad_zeros(3) if (item.get("imageUrl") != null and item.get("imageUrl", "").strip_edges() != "") else "",
		})

	_guardar_cards_json(catalogo)
	print("✅ cards.json actualizado con ", catalogo.size(), " cartas.")

	# PASO 3: Ahora sí, pedimos los mazos y entramos al juego
	_set_boton_texto("Iniciando partida...")
	_obtener_mazos_y_entrar_al_juego()

func _guardar_cards_json(catalogo: Array) -> void:
	var file = FileAccess.open(CARDS_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("❌ Error al guardar cards.json: ", FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(catalogo, "\t"))
	file.close()
	print("✅ Guardado en: ", CARDS_SAVE_PATH)

# ─────────────────────────────────────────────────────────────────────────────
# PASO 3: OBTENER MAZOS Y ENTRAR AL JUEGO
# ─────────────────────────────────────────────────────────────────────────────
func _obtener_mazos_y_entrar_al_juego() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mazos_recibidos.bind(http))

	var headers = ApiServicio.get_headers()
	var url = API_BASE + "/game/start/bot_random"

	var error = http.request(url, headers, HTTPClient.METHOD_POST, "")
	if error != OK:
		http.queue_free()
		_set_cargando(false)
		_mostrar_error("Error al solicitar partida")

func _on_mazos_recibidos(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if response_code != 200:
		_set_cargando(false)
		_mostrar_error("No se pudo obtener tu mazo del servidor")
		print("Error Mazos - Código: ", response_code, " Body: ", body.get_string_from_utf8())
		return

	var respuesta = JSON.parse_string(body.get_string_from_utf8())

	var ids_jugador_raw = respuesta.get("playerDeck", [])
	var ids_bot_raw     = respuesta.get("botDeck", [])

	var ids_jugador: Array[int] = []
	for id_f in ids_jugador_raw:
		ids_jugador.append(int(id_f))

	var ids_bot: Array[int] = []
	for id_f in ids_bot_raw:
		ids_bot.append(int(id_f))

	print("✅ Mazos procesados. Jugador: ", ids_jugador)
	print("✅ Mazos procesados. Bot: ", ids_bot)

	var baraja_j := CardLoader.construir_baraja(ids_jugador)
	var baraja_o := CardLoader.construir_baraja(ids_bot)

	GameManager.es_multijugador = false
	GameManager.game_id_actual  = respuesta.get("gameId", 0)
	GameManager.iniciar_partida(baraja_j, baraja_o)

	NetworkManager.conectar_al_servidor()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

# ─────────────────────────────────────────
# HELPERS UI
# ─────────────────────────────────────────
func _mostrar_error(mensaje: String) -> void:
	label_error.text = "⚠ " + mensaje
	label_error.visible = true

func _set_cargando(estado: bool) -> void:
	_cargando = estado
	boton_login.disabled = estado
	boton_login.text = "Iniciando sesión..." if estado else "ENTRAR"
	if estado:
		label_error.visible = false

func _set_boton_texto(texto: String) -> void:
	boton_login.text = texto
