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
	_set_cargando(false)

	if result != HTTPRequest.RESULT_SUCCESS:
		_mostrar_error("Error de red. Comprueba tu conexión.")
		return

	if response_code != 200:
		_mostrar_error("Credenciales incorrectas")
		print("Login fallido - Código: ", response_code, " Body: ", body.get_string_from_utf8())
		return

	var datos = JSON.parse_string(body.get_string_from_utf8())
	if datos == null or not datos.has("token"):
		_mostrar_error("Respuesta del servidor inválida")
		return

	# Guardamos el token en Autoload para usarlo en game.tscn
	ApiServicio.token = datos["token"]
	print("✅ Login correcto, cambiando de escena...")

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
	spinner.visible = estado
	boton_login.text = "Iniciando sesión..." if estado else "ENTRAR"
	if estado:
		label_error.visible = false
