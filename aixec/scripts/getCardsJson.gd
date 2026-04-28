# boton_cartas.gd
extends Button

const SAVE_PATH = "res://data/cards.json"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	disabled = true
	text = "Actualizando..."
	_obtener_cartas()

func _obtener_cartas() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_cartas_completed.bind(http))

	var error = http.request(
		ApiServicio.API_BASE + "/card/",
		ApiServicio.get_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		print("❌ Error al iniciar petición: ", error)
		http.queue_free()
		_reset_boton()

func _on_cartas_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("❌ Error al obtener cartas. Código: ", response_code)
		text = "❌ Error"
		await get_tree().create_timer(2.0).timeout
		_reset_boton()
		return

	var json_list = JSON.parse_string(body.get_string_from_utf8())
	if json_list == null:
		print("❌ JSON inválido")
		text = "❌ JSON inválido"
		await get_tree().create_timer(2.0).timeout
		_reset_boton()
		return

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
				"description": item["ability"].get("description", "") if item.get("ability") else ""
			},
			"expansion":   item.get("expansion", "Base"),
			"mana":        int(item.get("mana", 0)) if item.get("mana") != null else 0,
			"type":        int(item.get("type", 0)) if item.get("type") != null else 0,
			"isPassive":   item.get("isPassive", false),
			"imageUrl":    "http://aixec-card-images.s3.eu-north-1.amazonaws.com/card%s.jpg" % str(int(item.get("id", 50))).pad_zeros(3) if (item.get("imageUrl") != null and item.get("imageUrl", "").strip_edges() != "") else "",
		})

	_guardar_json(catalogo)
	text = "✅ Actualizado!"
	await get_tree().create_timer(2.0).timeout
	_reset_boton()

func _guardar_json(catalogo: Array) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("❌ Error al abrir archivo: ", FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(catalogo, "\t"))
	file.close()
	print("✅ Guardado con ", catalogo.size(), " cartas en: ", SAVE_PATH)

func _reset_boton() -> void:
	disabled = false
	text = "Actualizar Cartas"
