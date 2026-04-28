extends Node

# ─────────────────────────────────────────
#  CARGA DEL JSON
# ─────────────────────────────────────────
var cartas: Array = []

func _ready():
	_cargar_json()

func _cargar_json():
	var file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if not file:
		push_error("CardDatabase: No se pudo abrir cards.json")
		return
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("CardDatabase: Error parseando cards.json: " + json.get_error_message())
		return
	cartas = json.get_data()
	print("CardDatabase: %d cartas cargadas." % cartas.size())

# ─────────────────────────────────────────
#  CONSULTAS
# ─────────────────────────────────────────
func get_carta_por_id(id: int) -> Dictionary:
	for carta in cartas:
		if carta["id"] == id:
			return carta.duplicate(true)
	push_warning("CardDatabase: Carta id %d no encontrada." % id)
	return {}

func get_cartas_por_expansion(expansion: String) -> Array:
	return cartas.filter(func(c): return c["expansion"] == expansion)

func get_cartas_por_tipo(tipo: int) -> Array:
	return cartas.filter(func(c): return c["type"] == tipo)

func get_mazo_barajado(_id_jugador: int) -> Array:
	if cartas.is_empty():
		return []
	var pool = cartas.duplicate(true)
	pool.shuffle()
	var mazo = []
	while mazo.size() < 20:
		for carta in pool:
			if mazo.size() >= 20:
				break
			mazo.append(carta.duplicate(true))
	return mazo

# ─────────────────────────────────────────
#  RESOLUCIÓN DE HABILIDADES
#  Firma: resolver_habilidad(id, carta_origen, id_jugador, game)
#  - carta_origen : nodo Card que ejecuta la habilidad
#  - id_jugador   : int (1 o 2), jugador que la activa
#  - game         : referencia al nodo Game.gd para modificar estado
# ─────────────────────────────────────────
func resolver_habilidad(ability_id: int, carta_origen, id_jugador: int, game) -> void:
	var id_enemigo  = GameState.get_enemigo(id_jugador)
	var yo          = GameState.jugadores[id_jugador]
	var enemigo     = GameState.jugadores[id_enemigo]

	match ability_id:

		# ── 1. CUERPO ELEMENTAL (Pasiva) ──────────────────────────────
		# Cuando es atacado, el atacante sufre 1 de daño si no tiene equipamiento.
		# Se llama desde Game.gd al resolver un ataque, pasando la carta atacante.
		1:
			pass  # La lógica se gestiona en Game.gd/_resolver_contraataque_pasivo()
				  # porque necesita saber quién atacó primero.

		# ── 2. FAMILIA (Activa) ───────────────────────────────────────
		# Fusiona un slime del campo o la mano: lo elimina y cura/aumenta daño.
		2:
			# Buscar slimes (expansión "Fantasticas") en campo y mano propios
			var slimes_campo = yo["monstruos"].filter(
				func(c): return c.card_data["expansion"] == "Fantasticas" and c != carta_origen
			)
			var slimes_mano = yo["mano"].filter(
				func(c): return c.card_data["expansion"] == "Fantasticas"
			)
			var candidatos = slimes_campo + slimes_mano
			if candidatos.is_empty():
				game.mostrar_mensaje("No hay slimes para fusionar.")
				return
			# Game.gd abre selector; cuando el jugador elige, llama a:
			# _fusionar_slime(carta_origen, carta_elegida, id_jugador)
			game.iniciar_seleccion_carta(candidatos, "fusionar_slime", carta_origen, id_jugador)

		# ── 3. SUGESTIÓN (Activa) ─────────────────────────────────────
		# Convence a 1 slime del campo ENEMIGO para fusionarse: lo elimina,
		# cura 1 y aumenta 1 el ataque de carta_origen.
		3:
			var slimes_enemigos = enemigo["monstruos"].filter(
				func(c): return c.card_data["expansion"] == "Fantasticas"
			)
			if slimes_enemigos.is_empty():
				game.mostrar_mensaje("No hay slimes enemigos para convencer.")
				return
			game.iniciar_seleccion_carta(slimes_enemigos, "sugerir_slime", carta_origen, id_jugador)

		# ── 4. RESILIENCIA (Pasiva) ───────────────────────────────────
		# Si el daño no es letal, no se le reduce la vida.
		# Se intercepta en Card.gd/recibir_danio() comprobando esta habilidad.
		4:
			pass  # Gestionada en Card.gd

		# ── 5. SUPRESIÓN SACRIFICIAL (Activa) ────────────────────────
		# Toma posesión de un monstruo enemigo; esta carta se descarta.
		5:
			if enemigo["monstruos"].is_empty():
				game.mostrar_mensaje("El enemigo no tiene monstruos.")
				return
			game.iniciar_seleccion_carta(enemigo["monstruos"], "robar_monstruo", carta_origen, id_jugador)

		# ── 6. ESPEJITO REBOTÍN (Pasiva) ─────────────────────────────
		# El daño recibido no letal se reflecta al atacante.
		# Gestionada en Game.gd al calcular daño recibido.
		6:
			pass

		# ── 7. DUALIDAD (Activa) ──────────────────────────────────────
		# Cura 1 de vida a un aliado en lugar de atacar.
		7:
			var aliados = yo["monstruos"].filter(func(c): return c != carta_origen)
			if aliados.is_empty():
				# Si no hay aliados, cura al jugador
				yo["vida"] += 1
				game.mostrar_mensaje("Sin aliados: +1 vida al jugador.")
			else:
				game.iniciar_seleccion_carta(aliados, "curar_aliado_1", carta_origen, id_jugador)

		# ── 8. PENITENCIA RACIAL (Pasiva) ────────────────────────────
		# Cuando otra carta entra al campo, si no es de expansión "Juguetes",
		# su defensa se reduce en 1.
		# Se llama desde Game.gd/_on_carta_entra_al_campo().
		8:
			pass

		# ── 9. FOCO (Pasiva) ─────────────────────────────────────────
		# Cada vez que ataca, su ataque aumenta en 1.
		# Se llama desde Game.gd tras confirmar el ataque.
		9:
			carta_origen.card_data["attack"] += 1
			carta_origen.actualizar_ui()

		# ── 10. NOSTALGIA (Activa) ────────────────────────────────────
		# Sacrifica esta carta para sacar un juguete no legendario de la baraja.
		10:
			var juguetes = cartas.filter(
				func(c): return c["expansion"] == "Juguetes" and c["rarity"] != 3
			)
			if juguetes.is_empty():
				game.mostrar_mensaje("No quedan juguetes en la baraja.")
				return
			juguetes.shuffle()
			var nueva_carta_data = juguetes[0].duplicate(true)
			# Sacrificar carta_origen
			yo["monstruos"].erase(carta_origen)
			carta_origen.queue_free()
			# Invocar la nueva carta directamente al campo si hay hueco
			game.invocar_carta_al_campo(nueva_carta_data, id_jugador)

		# ── 11. ESCUADRÓN (Pasiva) ────────────────────────────────────
		# Si esta carta ha atacado, crea un duplicado si hay espacio.
		# Se llama desde Game.gd tras confirmar el ataque.
		11:
			if yo["monstruos"].size() < GameState.MAX_MONSTRUOS:
				var clon_data = carta_origen.card_data.duplicate(true)
				game.invocar_carta_al_campo(clon_data, id_jugador)
			else:
				game.mostrar_mensaje("No hay espacio para el duplicado.")

		# ── 12. PRECOZ (Activa) ───────────────────────────────────────
		# 4 de daño a una carta enemiga al azar.
		12:
			var objetivos = enemigo["monstruos"]
			if objetivos.is_empty():
				game.mostrar_mensaje("No hay cartas enemigas.")
				return
			var objetivo = objetivos[randi() % objetivos.size()]
			var sobrante = objetivo.recibir_danio(4)
			if sobrante > 0:
				enemigo["vida"] -= sobrante
			game.verificar_fin_partida()

		# ── 13. SACRIFICIO PROMETIDO (Pasiva) ────────────────────────
		# Al morir: roba 1 carta y descarta 1 al azar de la mano.
		# Se llama desde Game.gd/_on_carta_muerta().
		13:
			game.robar_carta(id_jugador)
			if not yo["mano"].is_empty():
				var idx = randi() % yo["mano"].size()
				var descartada = yo["mano"][idx]
				yo["mano"].erase(descartada)
				descartada.queue_free()

		# ── 14. PACIENCIA (Pasiva) ────────────────────────────────────
		# Cada turno sin atacar +1 ataque. Al atacar, vuelve al base.
		# Se gestiona en Game.gd al final de cada turno y al atacar.
		14:
			pass

		# ── 15. MALDICIÓN (Activa) ────────────────────────────────────
		# Reduce a la mitad la vida de una carta enemiga.
		15:
			if enemigo["monstruos"].is_empty():
				game.mostrar_mensaje("No hay cartas enemigas.")
				return
			game.iniciar_seleccion_carta(enemigo["monstruos"], "maldecir_carta", carta_origen, id_jugador)

		# ── 16. SUDO UPDATE (Activa) ──────────────────────────────────
		# Si tienes USB Cifrado (id 26) y Descifrador de datos (id 27)
		# desplegados, evoluciona a Hacker Experto (id 29) y descarta ambas.
		16:
			var tiene_usb = yo["monstruos"].any(func(c): return c.card_data["id"] == 26)
			var tiene_desc = yo["monstruos"].any(func(c): return c.card_data["id"] == 27)
			if not (tiene_usb and tiene_desc):
				game.mostrar_mensaje("Necesitas USB Cifrado y Descifrador de datos desplegados.")
				return
			# Descartar las dos cartas requeridas
			for lista in [yo["monstruos"]]:
				for c in lista.duplicate():
					if c.card_data["id"] == 26 or c.card_data["id"] == 27:
						lista.erase(c)
						c.queue_free()
			# Evolucionar carta_origen a Hacker Experto
			var hacker_data = get_carta_por_id(29)
			carta_origen.inicializar(hacker_data)

		# ── 17. REFORJADO (Activa) ────────────────────────────────────
		# Al desplegar, si tienes un Robot (id 21), evoluciona a Robot Blindado (id 22).
		17:
			var robot = null
			for c in yo["monstruos"]:
				if c.card_data["id"] == 21:
					robot = c
					break
			if robot == null:
				game.mostrar_mensaje("Necesitas un Robot desplegado.")
				return
			var blindado_data = get_carta_por_id(22)
			robot.inicializar(blindado_data)
			game.mostrar_mensaje("¡Robot evoluciona a Robot Blindado!")

		# ── 18. FIREWALL (Activa) ─────────────────────────────────────
		# Quema una carta enemiga: 1 de daño durante 3 turnos.
		18:
			if enemigo["monstruos"].is_empty():
				game.mostrar_mensaje("No hay cartas enemigas.")
				return
			game.iniciar_seleccion_carta(enemigo["monstruos"], "aplicar_quemadura", carta_origen, id_jugador)

		# ── 19. MEGA UPDATE (Activa) ──────────────────────────────────
		# Si tienes Soldador (id 23) y Cañón de plasma (id 17) desplegados,
		# evoluciona a Robot Exterminador (id 30) y descarta ambos.
		19:
			var tiene_soldador = yo["monstruos"].any(func(c): return c.card_data["id"] == 23)
			var tiene_canon    = yo["monstruos"].any(func(c): return c.card_data["id"] == 17)
			if not (tiene_soldador and tiene_canon):
				game.mostrar_mensaje("Necesitas Soldador y Cañón de plasma desplegados.")
				return
			for c in yo["monstruos"].duplicate():
				if c.card_data["id"] == 23 or c.card_data["id"] == 17:
					yo["monstruos"].erase(c)
					c.queue_free()
			var exterminador_data = get_carta_por_id(30)
			carta_origen.inicializar(exterminador_data)
			game.mostrar_mensaje("¡Evoluciona a Robot Exterminador!")

		# ── 20. TROYAN (Activa) ───────────────────────────────────────
		# 2 de daño a un enemigo aleatorio (carta o jugador).
		20:
			if enemigo["monstruos"].is_empty():
				enemigo["vida"] -= 2
				game.mostrar_mensaje("2 de daño directo al jugador enemigo.")
			else:
				var objetivo = enemigo["monstruos"][randi() % enemigo["monstruos"].size()]
				var sobrante = objetivo.recibir_danio(2)
				if sobrante > 0:
					enemigo["vida"] -= sobrante
			game.verificar_fin_partida()

		# ── 21. DATAPACK (Pasiva) ─────────────────────────────────────
		# Al entrar al campo: roba 1 carta.
		# Se llama desde Game.gd/_on_carta_entra_al_campo().
		21:
			game.robar_carta(id_jugador)

		# ── 22. ANTIVIRUS (Activa) ────────────────────────────────────
		# Inhabilita 1 carta enemiga durante 3 turnos (no puede actuar).
		22:
			if enemigo["monstruos"].is_empty():
				game.mostrar_mensaje("No hay cartas enemigas.")
				return
			game.iniciar_seleccion_carta(enemigo["monstruos"], "inhabilitar_carta", carta_origen, id_jugador)

		# ── 23. EXTERMINATOR (Pasiva) ─────────────────────────────────
		# Al entrar al campo: destruye una carta enemiga al azar.
		23:
			if enemigo["monstruos"].is_empty():
				game.mostrar_mensaje("No hay cartas enemigas para exterminar.")
				return
			var objetivo = enemigo["monstruos"][randi() % enemigo["monstruos"].size()]
			enemigo["monstruos"].erase(objetivo)
			objetivo.queue_free()
			game.mostrar_mensaje("¡Exterminado!")
			game.verificar_fin_partida()

		# ── 24. ANTIABDUCTOR (Pasiva) ─────────────────────────────────
		# 1% de probabilidad de anular el daño recibido.
		# Gestionada en Game.gd al calcular daño recibido.
		24:
			pass

		# ── 25. ATAQUE SORPRESA (Activa — Equipamiento) ───────────────
		# Al equipar: mira la mano enemiga y elimina 1 carta a elección.
		25:
			if enemigo["mano"].is_empty():
				game.mostrar_mensaje("El enemigo no tiene cartas en mano.")
				return
			game.iniciar_seleccion_carta(enemigo["mano"], "eliminar_carta_mano", carta_origen, id_jugador)

		# ── 26. HEAL (Activa — Hechizo) ──────────────────────────────
		# Cura 2 de vida al jugador.
		26:
			yo["vida"] += 2
			game.mostrar_mensaje("+2 de vida.")
			game.actualizar_ui_info()

		# ── 27. TERREMOTO (Activa — Hechizo) ─────────────────────────
		# 2 de daño a un monstruo O 1 de daño al jugador enemigo.
		27:
			# Game.gd abrirá selector: ¿monstruo o jugador directo?
			game.iniciar_seleccion_terremoto(carta_origen, id_jugador)

		# ── 28. OTRA VEZ (Activa — Hechizo) ──────────────────────────
		# Activa la habilidad de otra carta una segunda vez.
		28:
			var activas = yo["monstruos"].filter(
				func(c): return not c.card_data["ability"]["isPassive"] and c.card_data["ability"]["id"] != 0
			)
			if activas.is_empty():
				game.mostrar_mensaje("No hay cartas con habilidad activa en el campo.")
				return
			game.iniciar_seleccion_carta(activas, "repetir_habilidad", carta_origen, id_jugador)

		# ── 29. PAGUITAS (Activa — Hechizo) ──────────────────────────
		# Roba 2 cartas de la baraja.
		29:
			game.robar_carta(id_jugador)
			game.robar_carta(id_jugador)
			game.mostrar_mensaje("¡Robas 2 cartas!")

		# ── 30. LIGAMENTO CRUZADO (Activa — Hechizo) ─────────────────
		# Maldice una carta aliada: cuando reciba daño, el enemigo recibe 1.
		30:
			if yo["monstruos"].is_empty():
				game.mostrar_mensaje("No tienes monstruos desplegados.")
				return
			game.iniciar_seleccion_carta(yo["monstruos"], "aplicar_ligamento", carta_origen, id_jugador)

		# ── 32. EXISTENCIA (Pasiva) ───────────────────────────────────
		# No hace nada.
		32:
			pass

		_:
			push_warning("CardDatabase: Habilidad id %d no implementada." % ability_id)


# ─────────────────────────────────────────
#  EFECTOS CON ESTADO (quemadura, inhabilitación, ligamento)
#  Se llaman cada inicio de turno desde Game.gd
# ─────────────────────────────────────────

# Diccionario de efectos activos:
# { carta_node: { "tipo": str, "turnos_restantes": int, "origen": variant } }
var efectos_activos: Dictionary = {}

func registrar_efecto(carta, tipo: String, turnos: int, origen = null):
	efectos_activos[carta] = { "tipo": tipo, "turnos_restantes": turnos, "origen": origen }

func procesar_efectos_turno(id_jugador: int, game) -> void:
	var a_eliminar = []
	for carta in efectos_activos.keys():
		# Saltar si la carta ya no existe
		if not is_instance_valid(carta):
			a_eliminar.append(carta)
			continue

		var efecto = efectos_activos[carta]

		match efecto["tipo"]:
			"quemadura":
				var sobrante = carta.recibir_danio(1)
				if sobrante > 0:
					var id_duenio = _id_duenio_carta(carta)
					GameState.jugadores[id_duenio]["vida"] -= sobrante
				game.verificar_fin_partida()

			"inhabilitacion":
				carta.puede_actuar = false

			"ligamento":
				pass  # se activa al recibir daño, no por turno

		efecto["turnos_restantes"] -= 1
		if efecto["turnos_restantes"] <= 0:
			a_eliminar.append(carta)
			if efecto["tipo"] == "inhabilitacion":
				carta.puede_actuar = true   # rehabilitar

	for carta in a_eliminar:
		efectos_activos.erase(carta)

func tiene_efecto(carta, tipo: String) -> bool:
	if not efectos_activos.has(carta):
		return false
	return efectos_activos[carta]["tipo"] == tipo

func _id_duenio_carta(carta) -> int:
	for id in GameState.jugadores:
		if carta in GameState.jugadores[id]["monstruos"]:
			return id
	return 1
