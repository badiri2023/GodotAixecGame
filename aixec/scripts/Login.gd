# login.gd
extends Control

const API_BASE = "http://aixec.eu-north-1.elasticbeanstalk.com/api"

var _cargando: bool = false

@onready var email_input = $VBoxContainer/EmailInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var boton_login = $VBoxContainer/BotonLogin
@onready var label_error = $VBoxContainer/LabelError
@onready var spinner = $VBoxContainer/Spinner

func _ready() -> void:
	label_error.visible = false
	spinner.visible = false
	boton_login.pressed.connect(_on_login_pressed)

func _on_login_pressed() -> void:
	var email = email_input.text.strip_edges()
	var password = password_input.text

	# Validaciones básicas
	if email == "" or not "@" in email:
		_mostrar_error("Introduce un email válido")
		return
	if password.length() < 6:
		_mostrar_error("La contraseña debe tener mínimo 6 caracteres")
		return

	_set_cargando(true)
	_hacer_login(email, password)

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
	# Eliminamos el _set_cargando(false) de aquí porque seguiremos cargando los mazos
	
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_cargando(false)
		_mostrar_error("Error de red. Comprueba tu conexión.")
		return

	if response_code != 200:
		_set_cargando(false)
		_mostrar_error("Credenciales incorrectas")
		return

	var datos = JSON.parse_string(body.get_string_from_utf8())
	print("DEBUG: Respuesta completa del servidor: ", datos) # <--- AÑADE ESTO
	if datos == null or not datos.has("token"):
		_set_cargando(false)
		_mostrar_error("Respuesta del servidor inválida")
		return

	# 1. Guardamos el token en el Autoload
	ApiServicio.token = datos["token"]
	ApiServicio.usuario_id = datos.get("id", 0)
	print("✅ Login correcto. Obteniendo mazos reales del servidor...")
	print("✅ Login exitoso. Usuario ID: ", ApiServicio.usuario_id)
	# 2. En lugar de hardcodear e irnos al juego, llamamos a la API
	_obtener_mazos_y_entrar_al_juego()

# ─────────────────────────────────────────────────────────────────────────────
# NUEVA FUNCIÓN: Conecta con tu GameController.cs
# ─────────────────────────────────────────────────────────────────────────────
func _obtener_mazos_y_entrar_al_juego() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mazos_recibidos.bind(http))

	# Usamos los headers que ya incluyen el Token de ApiServicio
	var headers = ApiServicio.get_headers()
	var url = API_BASE + "/game/start/bot_random"
	
	# Enviamos la petición POST (según tu GameController.cs)
	var error = http.request(url, headers, HTTPClient.METHOD_POST, "")
	if error != OK:
		http.queue_free()
		_set_cargando(false)
		_mostrar_error("Error al solicitar partida")

func _on_mazos_recibidos(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	_set_cargando(false) # Ahora sí dejamos de mostrar el spinner

	if response_code == 200:
		var respuesta = JSON.parse_string(body.get_string_from_utf8())
		
	# 1. Extraemos los IDs crudos (que Godot lee como floats, ej: 26.0)
		var ids_jugador_raw = respuesta.get("playerDeck", [])
		var ids_bot_raw = respuesta.get("botDeck", [])
		
		# 2. LIMPIEZA: Forzamos que todos los IDs sean Enteros (int)
		# Esto es lo que soluciona el problema de que no encuentre las cartas
		var ids_jugador : Array[int] = []
		for id_f in ids_jugador_raw:
			ids_jugador.append(int(id_f))
			
		var ids_bot : Array[int] = []
		for id_f in ids_bot_raw:
			ids_bot.append(int(id_f))

		print("✅ Mazos procesados (Int). Jugador: ", ids_jugador)

		# 3. USAMOS EL CARDLOADER CON LOS IDS YA LIMPIOS
		var baraja_j := CardLoader.construir_baraja(ids_jugador)
		var baraja_o := CardLoader.construir_baraja(ids_bot)

		# 4. Configuramos la partida en el GameManager
		GameManager.es_multijugador = false
		GameManager.iniciar_partida(baraja_j, baraja_o)
		
		# 5. Conectamos SignalR y entramos al juego
		NetworkManager.conectar_al_servidor()
		get_tree().change_scene_to_file("res://scenes/Game.tscn")

	
	else:
		_mostrar_error("No se pudo obtener tu mazo del servidor")
		print("Error Mazos - Código: ", response_code, " Body: ", body.get_string_from_utf8())
		
func _preparar_partida_con_servidor() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_partida_recibida.bind(http))

	# Usamos el token que acabamos de guardar
	var headers = ApiServicio.get_headers()
	
	# Llamamos al endpoint de tu GameController.cs que inicia partidas
	var url = ApiServicio.API_BASE + "/game/start/bot_random"
	
	http.request(url, headers, HTTPClient.METHOD_POST, "")

func _on_partida_recibida(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	_set_cargando(false)

	if response_code == 200:
		var respuesta = JSON.parse_string(body.get_string_from_utf8())
		
		# ¡AQUÍ ESTÁN TUS IDS REALES VIENEN DEL SERVIDOR!
		var ids_jugador = respuesta["playerDeck"] # Viene de tu C# StartGameResponse
		var ids_bot = respuesta["botDeck"]

		print("✅ Mazos recibidos del servidor. Jugador:", ids_jugador.size(), " cartas.")

		GameManager.es_multijugador = false
		
		# Ahora construimos las barajas con los IDs que nos dio la base de datos
		var baraja_j := CardLoader.construir_baraja(ids_jugador)
		var baraja_o := CardLoader.construir_baraja(ids_bot)
		# En el callback de mazos recibidos
		GameManager.game_id_actual = respuesta["gameId"] 
		GameManager.iniciar_partida(baraja_j, baraja_o)
		NetworkManager.conectar_al_servidor()
		
		# Ahora sí, cambiamos de escena
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	else:
		_mostrar_error("Error al obtener tu mazo del servidor")


# ─────────────────────────────────────────
# HELPERS UI
# ─────────────────────────────────────────
func _mostrar_error(mensaje: String) -> void:
	label_error.text = "⚠ " + mensaje
	label_error.visible = true

func _set_cargando(estado: bool) -> void:
	_cargando = estado
	boton_login.disabled = estado
	spinner.visible = estado
	boton_login.text = "Iniciando sesión..." if estado else "ENTRAR"
	if estado:
		label_error.visible = false
