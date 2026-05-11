# NetworkManager.gd
# SINGLETON (Autoload) -> Proyecto > Ajustes del Proyecto > Autoload
extends Node

# --- SEÑALES ---
# Emitimos estas señales para que la interfaz (GameUI, Login, etc.) reaccione
signal conectado
signal error_conexion(razon)
signal estado_partida_recibido(datos)
signal mensaje_error_servidor(mensaje)

# --- VARIABLES ---
var socket := WebSocketPeer.new()
var url_servidor = "ws://aixec.eu-north-1.elasticbeanstalk.com/gamehub"

# Control de estado interno de SignalR
var conectado_y_listo := false
var handshake_enviado := false

# El caracter especial que usa SignalR para separar mensajes JSON
const TERMINADOR = "\u001e"

# --- BUCLE PRINCIPAL DE CONEXIÓN ---
func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		# ¡CLAVE! En SignalR, el cliente DEBE hablar primero enviando el protocolo.
		if not handshake_enviado:
			enviar_mensaje_raw({"protocol": "json", "version": 1})
			handshake_enviado = true
			
		# Leer todos los mensajes entrantes
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			_manejar_mensaje(packet.get_string_from_utf8())
			
	elif state == WebSocketPeer.STATE_CLOSED:
		if conectado_y_listo or handshake_enviado:
			conectado_y_listo = false
			handshake_enviado = false
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("Desconectado. Código: ", code, " Razón: ", reason)
			error_conexion.emit("Conexión perdida con el servidor.")

# --- MÉTODOS DE CONEXIÓN ---
func conectar_al_servidor():
	if ApiServicio.token == "":
		error_conexion.emit("No hay token de sesión.")
		return

	# Añadimos el token JWT a la URL para que SignalR nos autentique
	var url_con_token = url_servidor + "?access_token=" + ApiServicio.token
	
	# Reiniciamos el estado antes de un nuevo intento
	conectado_y_listo = false
	handshake_enviado = false
	
	var err = socket.connect_to_url(url_con_token)
	if err != OK:
		error_conexion.emit("No se pudo iniciar la conexión WebSocket.")
	else:
		print("🔌 Conectando al GameHub...")

# --- PROCESAMIENTO DE MENSAJES ---
func _manejar_mensaje(mensaje_raw: String):
	# SignalR puede enviar varios mensajes juntos pegados y separados por el TERMINADOR
	var mensajes = mensaje_raw.split(TERMINADOR)
	
	for m in mensajes:
		if m == "": 
			continue
		
		# 1. Confirmación del Handshake
		# El servidor de SignalR responde con un JSON vacío "{}" si acepta nuestro protocolo
		if not conectado_y_listo and m == "{}":
			conectado_y_listo = true
			conectado.emit()
			print("✅ Conexión SignalR establecida y autenticada")
			continue
			
		# 2. Parsear el JSON normal
		var json = JSON.parse_string(m)
		if json == null: 
			continue

		# 3. Manejar invocaciones del servidor (Hub -> Cliente)
		# "type": 1 significa que el servidor está llamando a un método del cliente
		if json.has("type") and json["type"] == 1: 
			var metodo = json.get("target", "")
			var argumentos = json.get("arguments", [])
			_procesar_llamada_servidor(metodo, argumentos)

func _procesar_llamada_servidor(metodo: String, argumentos: Array):
	# Aquí enrutamos los mensajes del servidor a las señales de Godot
	match metodo:
		"GameStateUpdated":
			# El argumento 0 es el objeto GameState de C#
			estado_partida_recibido.emit(argumentos[0])
		"Error":
			mensaje_error_servidor.emit(argumentos[0])
			print("❌ Error del Hub: ", argumentos[0])
		"PlayerDisconnected":
			print("⚠️ El jugador ", argumentos[0].get("userId", "?"), " se ha desconectado.")
		_:
			print("Método del servidor no reconocido: ", metodo)

# --- MÉTODOS PARA ENVIAR ACCIONES (Cliente -> Hub) ---

func enviar_accion(nombre_metodo: String, argumentos: Array):
	if not conectado_y_listo: 
		print("⚠️ Intento de enviar acción '", nombre_metodo, "' pero no estamos conectados.")
		return
	
	# Estructura obligatoria de SignalR para llamar a métodos del Hub de C#
	var payload = {
		"type": 1,
		"target": nombre_metodo,
		"arguments": argumentos
	}
	enviar_mensaje_raw(payload)

func enviar_mensaje_raw(diccionario: Dictionary):
	var string_json = JSON.stringify(diccionario) + TERMINADOR
	socket.send_text(string_json)

# --- ATAJOS PARA EL JUEGO ---

func unirse_a_partida(game_id: int):
	# Llama al método "JoinGame" en GameHub.cs
	enviar_accion("JoinGame", [game_id])

func jugar_carta(card_id: int, slot: int):
	# Llama al método "PlayCard" en GameHub.cs (cuando lo programemos)
	enviar_accion("PlayCard", [card_id, slot])
