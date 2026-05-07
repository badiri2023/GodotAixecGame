extends Node
# AbilityManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# SINGLETON — Project > Project Settings > AutoLoad > nombre: "AbilityManager"
# SIN class_name para evitar colisión con el nombre del AutoLoad.
#
# Datos reales extraídos de cards.json:
#
# Cartas con requisitos de nombre específico:
#   hab 16 (Sudo Update)  → requiere "USB Cifrado" (id 28) + "Descifrador de datos" (id 27)
#                           evoluciona "Hacker" (id 22) → "Hacker Experto" (id 29)
#   hab 17 (Reforjado)    → requiere "Robot" (id 21) en campo
#                           evoluciona "Robot" → "Robot Blindado" (id 25)
#   hab 19 (Mega Update)  → requiere "Soldador" (id 24) + "Cañón de plasma" (id 26)
#                           evoluciona "Robot Blindado" (id 25) → "Robot Exterminador" (id 30)
#   hab  2 (Familia)      → fusiona cartas de expansion "Fantasticas" con nombre que
#                           contenga "Slime" (ids 1,2,3,4,5,6,7,8,9,10)
#   hab  3 (Sugestión)    → igual que Familia pero también del campo enemigo
#
# Hechizos (type 2): PotiPoti(36), Factura(37), Disco rayado(38),
#                    Día de pago(39), Contrato maldito(40)
# Equipamientos (type 3): Sombrero de aluminio(31), Cordón de zapato(32),
#                          Pechera(33), Cinturón de Puchi(34), Zapato del medio(35)
# ─────────────────────────────────────────────────────────────────────────────


# ═════════════════════════════════════════════
#  SEÑALES
# ═════════════════════════════════════════════
signal habilidad_activada(carta, habilidad_id: int)
signal habilidad_fallida(carta, razon: String)


# ═════════════════════════════════════════════
#  CONSTANTES DE EVENTOS (para pasivas)
# ═════════════════════════════════════════════
const EVENTO_CARTA_ATACADA         := "carta_atacada"      # {victima:Card, atacante:Card, danyo:int}
const EVENTO_CARTA_DESPLEGADA      := "carta_desplegada"   # {carta:Card, propietario:String}
const EVENTO_CARTA_MUERTA          := "carta_muerta"       # {carta:Card, propietario:String}
const EVENTO_CARTA_ATACO           := "carta_ataco"        # {carta:Card, propietario:String}

# IDs de carta relevantes para habilidades con requisitos
const ID_USB_CIFRADO        := 28
const ID_DESCIFRADOR        := 27
const ID_HACKER             := 22
const ID_HACKER_EXPERTO     := 29
const ID_ROBOT              := 21
const ID_ROBOT_BLINDADO     := 25
const ID_ROBOT_EXTERMINADOR := 30
const ID_SOLDADOR           := 24
const ID_CANON_PLASMA       := 26


# ═════════════════════════════════════════════
#  ESTADO INTERNO EN RUNTIME
# ═════════════════════════════════════════════

# Efectos de duración activos sobre nodos Card
# { Card -> { "tipo": String, "turnos_restantes": int, "propietario": String } }
var _efectos_activos: Dictionary = {}



# ═════════════════════════════════════════════
#  PUNTO DE ENTRADA — HABILIDADES ACTIVAS
# ═════════════════════════════════════════════

## Activa la habilidad propia de `carta`. Llamado desde la UI.
## Devuelve true si se ejecutó con éxito.
func activar_habilidad_activa(carta: Card, propietario: String) -> bool:
	if not GameManager.es_mi_turno(propietario):
		emit_signal("habilidad_fallida", carta, "No es tu turno")
		return false
	if carta.usada_este_turno:
		emit_signal("habilidad_fallida", carta, "Esta carta ya actuó este turno")
		return false
	if carta.habilidad_es_pasiva:
		emit_signal("habilidad_fallida", carta, "Esta habilidad es pasiva")
		return false

	var ok: bool = _ejecutar_habilidad(carta.habilidad_id, carta, propietario)
	if ok:
		carta.marcar_como_usada()
		emit_signal("habilidad_activada", carta, carta.habilidad_id)
	return ok





# ═════════════════════════════════════════════
#  PUNTO DE ENTRADA — EVENTOS PASIVOS
# ═════════════════════════════════════════════

## Notifica un evento para que las habilidades pasivas reaccionen.
## Llámalo desde GameManager o el sistema de combate en los momentos clave.
func notificar_evento(evento: String, datos: Dictionary) -> void:
	for carta in _get_todas_cartas_desplegadas():
		if carta.habilidad_id >= 0 and carta.habilidad_es_pasiva:
			_evaluar_pasiva(carta.habilidad_id, carta, evento, datos)



## Reduce en 1 los efectos de duración. Llama al FINAL de cada turno.
func tick_efectos_turno() -> void:
	var a_eliminar: Array = []
	for carta in _efectos_activos.keys():
		var efecto: Dictionary = _efectos_activos[carta]
		efecto["turnos_restantes"] -= 1

		match efecto["tipo"]:
			"quemadura":     # hab 18 - Firewall
				GameManager.aplicar_danyo_a_carta(efecto["propietario"], carta.get_datos_actuales(), 1)
				print("[AbilityManager] Firewall: 1 daño a '%s' (%d turnos restantes)" % [
					carta.nombre, efecto["turnos_restantes"]
				])
			"inhabilitada":  # hab 22 - Antivirus
				# La carta sigue inhabilitada; se libera al llegar a 0
				pass

		if efecto["turnos_restantes"] <= 0:
			a_eliminar.append(carta)
			if efecto["tipo"] == "inhabilitada":
				carta.usada_este_turno = false
				print("[AbilityManager] Antivirus: '%s' liberada" % carta.nombre)

	for carta in a_eliminar:
		_efectos_activos.erase(carta)


# ═════════════════════════════════════════════
#  HOOKS ESPECIALES (llamar desde combate)
# ═════════════════════════════════════════════




## Llama ANTES de aplicar daño a una carta con Antiabductor (hab 24).
## Devuelve true si el daño queda anulado (1% de probabilidad).
func comprobar_antiabductor(carta_nodo: Card) -> bool:
	if carta_nodo.habilidad_id != 24:
		return false
	if randf() <= 0.01:
		print("[AbilityManager] Antiabductor: ¡daño anulado en '%s'!" % carta_nodo.nombre)
		return true
	return false


## Llama al COLOCAR un equipamiento en el slot global.
## Activa habilidades que se disparan al equipar (hab 25 - Ataque sorpresa).
func notificar_equipamiento(monstruo: Card, equip: Card, propietario: String) -> void:
	if equip.habilidad_id == 25:
		_hab_ataque_sorpresa(propietario)


# ═════════════════════════════════════════════
#  DISPATCHER — ACTIVAS
# ═════════════════════════════════════════════

func _ejecutar_habilidad(id: int, carta: Card, propietario: String) -> bool:
	match id:
		2:  return _hab_familia(carta, propietario)
		3:  return _hab_sugestion(carta, propietario)
		5:  return _hab_supresion_sacrificial(carta, propietario)
		7:  return _hab_dualidad(carta, propietario)
		10: return _hab_nostalgia(carta, propietario)
		12: return _hab_precoz(carta, propietario)
		15: return _hab_maldicion(carta, propietario)
		16: return _hab_sudo_update(carta, propietario)
		17: return _hab_reforjado(carta, propietario)
		18: return _hab_firewall(carta, propietario)
		19: return _hab_mega_update(carta, propietario)
		20: return _hab_troyan(carta, propietario)
		22: return _hab_antivirus(carta, propietario)
		26: return _hab_heal(propietario)
		27: return _hab_terremoto(propietario)
		28: return _hab_otra_vez(carta, propietario)
		29: return _hab_paguitas(propietario)
		30: return _hab_ligamento_cruzado(carta, propietario)
		32: return _hab_existencia()
		_:
			push_warning("[AbilityManager] ID de habilidad activa desconocido: %d" % id)
			return false


# ═════════════════════════════════════════════
#  DISPATCHER — PASIVAS
# ═════════════════════════════════════════════

func _evaluar_pasiva(id: int, carta: Card, evento: String, datos: Dictionary) -> void:
	match id:
		1:  _pas_cuerpo_elemental(carta, evento, datos)
		4:  _pas_resiliencia(carta, evento, datos)
		6:  _pas_espejito_rebotin(carta, evento, datos)
		8:  _pas_penitencia_racial(carta, evento, datos)
		9:  _pas_foco(carta, evento, datos)
		11: _pas_escuadron(carta, evento, datos)
		13: _pas_sacrificio_prometido(carta, evento, datos)
		14: _pas_paciencia(carta, evento, datos)
		21: _pas_datapack(carta, evento, datos)
		23: _pas_exterminator(carta, evento, datos)
		32: pass   # Existencia: no hace nada, ni como pasiva


# ═════════════════════════════════════════════
#  HABILIDADES ACTIVAS — IMPLEMENTACIÓN
# ═════════════════════════════════════════════

# ── 2 · Familia ───────────────────────────────────────────────────────────────
# Fusiona un slime (expansion "Fantasticas" con "Slime" en el nombre)
# del campo o la mano para curar +1 vida y +1 ataque a esta carta.
func _hab_familia(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	var slime_dict: Dictionary = {}
	var slime_zona: String = ""

	# Busca en monstruos desplegados primero, luego en mano
	for zona in ["monstruos", "mano"]:
		for c in p[zona]:
			if c.get("expansion", "") == "Fantasticas" \
			and "Slime" in c.get("nombre", "") \
			and c.get("id", -1) != carta.id:
				slime_dict = c
				slime_zona = zona
				break
		if not slime_dict.is_empty():
			break

	if slime_dict.is_empty():
		print("[AbilityManager] Familia: no hay Slimes disponibles en campo o mano")
		return false

	# Descarta el slime
	if slime_zona == "monstruos":
		GameManager.enviar_al_cementerio(propietario, slime_dict, "monstruos")
	else:
		p["mano"].erase(slime_dict)
		p["cementerio"].append(slime_dict)

	carta.recibir_curacion(1)
	carta.ataque_actual += 1
	carta._actualizar_textos()
	print("[AbilityManager] Familia: '%s' fusionado → '%s' +1 vida +1 atk" % [
		slime_dict.get("nombre","???"), carta.nombre
	])
	return true


# ── 3 · Sugestión ─────────────────────────────────────────────────────────────
# Igual que Familia pero puede tomar un Slime del campo enemigo.
func _hab_sugestion(carta: Card, propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)

	# Busca slime en monstruos enemigos
	for c in p_en["monstruos"]:
		if c.get("expansion","") == "Fantasticas" and "Slime" in c.get("nombre",""):
			GameManager.enviar_al_cementerio(enemigo, c, "monstruos")
			carta.recibir_curacion(1)
			carta.ataque_actual += 1
			carta._actualizar_textos()
			print("[AbilityManager] Sugestión: slime enemigo '%s' convencido" % c.get("nombre","???"))
			return true

	# Si no hay en el enemigo, usa Familia sobre los propios
	return _hab_familia(carta, propietario)


# ── 5 · Supresión sacrificial ─────────────────────────────────────────────────
# Roba el primer monstruo enemigo y lo pone en tu campo. Descarta esta carta.
func _hab_supresion_sacrificial(carta: Card, propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)
	var p_pr: Dictionary = GameManager._get_jugador(propietario)

	if p_en["monstruos"].is_empty():
		print("[AbilityManager] Supresión sacrificial: el enemigo no tiene monstruos")
		return false
	if p_pr["monstruos"].size() >= GameManager.MAX_MONSTRUOS:
		print("[AbilityManager] Supresión sacrificial: tu zona de monstruos está llena")
		return false

	# Roba el primer monstruo (TODO: la UI debería permitir elegir)
	var robado: Dictionary = p_en["monstruos"][0]
	p_en["monstruos"].erase(robado)
	robado["propietario"] = propietario
	p_pr["monstruos"].append(robado)

	# Descarta esta carta al cementerio
	GameManager.enviar_al_cementerio(propietario, carta.get_datos_actuales(), "monstruos")
	print("[AbilityManager] Supresión: '%s' tomado del enemigo" % robado.get("nombre","???"))
	return true


# ── 7 · Dualidad ──────────────────────────────────────────────────────────────
# Cura 1 de vida al aliado con menos vida.
# (Alternativamente el jugador puede atacar; eso lo gestiona el sistema de combate.)
func _hab_dualidad(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	if p["monstruos"].is_empty():
		print("[AbilityManager] Dualidad: no hay aliados para curar")
		return false

	# Elige el aliado con menos vida (TODO: la UI debería permitir elegir)
	var objetivo: Dictionary = p["monstruos"][0]
	for c in p["monstruos"]:
		if c.get("vida_actual", 0) < objetivo.get("vida_actual", 0):
			objetivo = c

	var vida_max: int = objetivo.get("defensa_base", objetivo.get("vida_actual", 0))
	objetivo["vida_actual"] = min(objetivo.get("vida_actual", 0) + 1, vida_max)
	print("[AbilityManager] Dualidad: '%s' curado 1 vida (%d/%d)" % [
		objetivo.get("nombre","???"), objetivo["vida_actual"], vida_max
	])
	return true


# ── 10 · Nostalgia ────────────────────────────────────────────────────────────
# Sacrifica esta carta para buscar un juguete no legendario en la baraja.
# Juguetes = expansion "Juguetes" (ids: 11,12,13,14,15,16,17,18,19,20)
func _hab_nostalgia(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)

	var objetivo: Dictionary = {}
	for c in p["baraja"]:
		if c.get("expansion","") == "Juguetes" and c.get("rarity", 3) != 3:
			objetivo = c
			break

	if objetivo.is_empty():
		print("[AbilityManager] Nostalgia: no hay juguetes no legendarios en la baraja")
		return false

	GameManager.enviar_al_cementerio(propietario, carta.get_datos_actuales(), "monstruos")
	p["baraja"].erase(objetivo)
	p["mano"].append(objetivo)
	print("[AbilityManager] Nostalgia: '%s' sacado a la mano" % objetivo.get("nombre","???"))
	return true


# ── 12 · Precoz ───────────────────────────────────────────────────────────────
# 4 de daño a una carta enemiga al azar.
func _hab_precoz(carta: Card, propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)
	var pool: Array = p_en["monstruos"] + p_en["hechizos"]

	if pool.is_empty():
		print("[AbilityManager] Precoz: el enemigo no tiene cartas desplegadas")
		return false

	var objetivo: Dictionary = pool[randi() % pool.size()]
	GameManager.aplicar_danyo_a_carta(enemigo, objetivo, 4)
	print("[AbilityManager] Precoz: 4 daño a '%s'" % objetivo.get("nombre","???"))
	return true


# ── 15 · Maldición ────────────────────────────────────────────────────────────
# Reduce a la mitad (floor) la vida de un monstruo enemigo.
func _hab_maldicion(carta: Card, propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)

	if p_en["monstruos"].is_empty():
		print("[AbilityManager] Maldición: el enemigo no tiene monstruos")
		return false

	# TODO: la UI debería permitir elegir; por ahora el primero
	var objetivo: Dictionary = p_en["monstruos"][0]
	objetivo["vida_actual"] = max(1, int(objetivo.get("vida_actual", 1) / 2.0))
	print("[AbilityManager] Maldición: '%s' queda con %d de vida" % [
		objetivo.get("nombre","???"), objetivo["vida_actual"]
	])
	return true


# ── 16 · Sudo Update ──────────────────────────────────────────────────────────
# Requiere: USB Cifrado (id 28) + Descifrador de datos (id 27) en campo o mano.
# Efecto: descarta ambas cartas y evoluciona "Hacker" (id 22) → "Hacker Experto" (id 29).
func _hab_sudo_update(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)

	var usb        := _buscar_carta_por_id(p, ID_USB_CIFRADO)
	var descifrador := _buscar_carta_por_id(p, ID_DESCIFRADOR)

	if usb.is_empty() or descifrador.is_empty():
		print("[AbilityManager] Sudo Update: faltan USB Cifrado o Descifrador de datos")
		return false

	_descartar_carta_por_id(p, propietario, ID_USB_CIFRADO)
	_descartar_carta_por_id(p, propietario, ID_DESCIFRADOR)

	# Aplica stats de Hacker Experto (id 29: atk 4, def 2)
	carta.nombre        = "Hacker Experto"
	carta.ataque_actual = 4
	carta.vida_actual   = max(carta.vida_actual, 2)
	carta.habilidad_id  = 22   # Antivirus (habilidad de Hacker Experto)
	carta.habilidad_nombre = "Antivirus"
	carta.habilidad_es_pasiva = false
	carta._actualizar_textos()
	print("[AbilityManager] Sudo Update: Hacker → Hacker Experto")
	return true


# ── 17 · Reforjado ────────────────────────────────────────────────────────────
# Requiere: "Robot" (id 21) en el campo propio.
# Efecto: Robot (id 21) evoluciona a Robot Blindado (id 25, atk 2, def 4).
func _hab_reforjado(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	var robot_dict := _buscar_carta_por_id_en_zona(p["monstruos"], ID_ROBOT)

	if robot_dict.is_empty():
		print("[AbilityManager] Reforjado: no hay Robot desplegado")
		return false

	# Evoluciona el diccionario del Robot (el nodo lo actualizará por señal)
	robot_dict["nombre"]       = "Robot Blindado"
	robot_dict["attack"]       = 2
	robot_dict["defense"]      = 4
	robot_dict["ataque_actual"] = 2
	robot_dict["vida_actual"]  = robot_dict.get("vida_actual", 1) + 2

	# Actualiza el nodo Card en escena si existe
	var nodo: Card = _buscar_nodo_por_id(ID_ROBOT, propietario)
	if nodo:
		nodo.nombre        = "Robot Blindado"
		nodo.ataque_actual = 2
		nodo.vida_actual   = nodo.vida_actual + 2
		nodo._actualizar_textos()

	print("[AbilityManager] Reforjado: Robot → Robot Blindado")
	return true


# ── 18 · Firewall ─────────────────────────────────────────────────────────────
# Quema una carta enemiga al azar durante 3 turnos (1 daño/turno en tick_efectos_turno).
func _hab_firewall(carta: Card, propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)
	var pool: Array = p_en["monstruos"] + p_en["hechizos"]

	if pool.is_empty():
		print("[AbilityManager] Firewall: el enemigo no tiene cartas")
		return false

	# TODO: la UI debería permitir elegir
	var objetivo_dict: Dictionary = pool[randi() % pool.size()]
	var objetivo_nodo: Card = _buscar_nodo_por_dict(objetivo_dict, enemigo)
	if objetivo_nodo == null:
		return false

	_efectos_activos[objetivo_nodo] = {
		"tipo": "quemadura",
		"turnos_restantes": 3,
		"propietario": enemigo
	}
	print("[AbilityManager] Firewall: '%s' en llamas (3 turnos)" % objetivo_dict.get("nombre","???"))
	return true


# ── 19 · Mega Update ──────────────────────────────────────────────────────────
# Requiere: Soldador (id 24) + Cañón de plasma (id 26) en campo o mano.
# Efecto: descarta ambos y evoluciona Robot Blindado (id 25) → Robot Exterminador (id 30, atk 5, def 3).
func _hab_mega_update(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)

	var soldador := _buscar_carta_por_id(p, ID_SOLDADOR)
	var canon    := _buscar_carta_por_id(p, ID_CANON_PLASMA)

	if soldador.is_empty() or canon.is_empty():
		print("[AbilityManager] Mega Update: faltan Soldador o Cañón de plasma")
		return false

	_descartar_carta_por_id(p, propietario, ID_SOLDADOR)
	_descartar_carta_por_id(p, propietario, ID_CANON_PLASMA)

	# Aplica stats de Robot Exterminador (id 30: atk 5, def 3)
	carta.nombre        = "Robot Exterminador"
	carta.ataque_actual = 5
	carta.vida_actual   = max(carta.vida_actual, 3)
	carta.habilidad_id  = 23   # Exterminator
	carta.habilidad_nombre = "Exterminator"
	carta.habilidad_es_pasiva = true
	carta._actualizar_textos()
	print("[AbilityManager] Mega Update: Robot Blindado → Robot Exterminador")
	return true


# ── 20 · Troyan ───────────────────────────────────────────────────────────────
# 2 de daño a un objetivo aleatorio (carta o jugador enemigo).
func _hab_troyan(carta: Card, propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)
	var pool: Array = p_en["monstruos"] + p_en["hechizos"]

	if pool.is_empty():
		GameManager.aplicar_danyo(enemigo, 2)
		print("[AbilityManager] Troyan: 2 daño directo al jugador enemigo")
	else:
		var objetivo: Dictionary = pool[randi() % pool.size()]
		GameManager.aplicar_danyo_a_carta(enemigo, objetivo, 2)
		print("[AbilityManager] Troyan: 2 daño a '%s'" % objetivo.get("nombre","???"))
	return true


# ── 22 · Antivirus ────────────────────────────────────────────────────────────
# Inhabilita 1 carta enemiga durante 3 turnos.
func _hab_antivirus(carta: Card, propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)
	var pool: Array = p_en["monstruos"] + p_en["hechizos"]

	if pool.is_empty():
		print("[AbilityManager] Antivirus: el enemigo no tiene cartas")
		return false

	# TODO: la UI debería permitir elegir
	var objetivo_dict: Dictionary = pool[0]
	var objetivo_nodo: Card = _buscar_nodo_por_dict(objetivo_dict, enemigo)
	if objetivo_nodo == null:
		return false

	_efectos_activos[objetivo_nodo] = {
		"tipo": "inhabilitada",
		"turnos_restantes": 3,
		"propietario": enemigo
	}
	objetivo_nodo.usada_este_turno = true
	print("[AbilityManager] Antivirus: '%s' inhabilitada 3 turnos" % objetivo_dict.get("nombre","???"))
	return true


# ── 25 · Ataque sorpresa (nueva versión) ─────────────────────────────────────
# Permite ver la mano enemiga completa y descarta 1 carta al azar de ella.
# Solo se puede usar una vez (la carta hechizo va al cementerio al usarse).
# (Zapato del medio, id 35)
func _hab_ataque_sorpresa(propietario: String) -> void:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)

	if p_en["mano"].is_empty():
		print("[AbilityManager] Ataque sorpresa: el enemigo no tiene cartas en mano")
		return

	# TODO: la UI debe mostrar la mano enemiga al jugador antes de descartar.
	# Por ahora se descarta una carta al azar automáticamente.
	var idx: int = randi() % p_en["mano"].size()
	var eliminada: Dictionary = p_en["mano"][idx]
	p_en["mano"].remove_at(idx)
	p_en["cementerio"].append(eliminada)
	print("[AbilityManager] Ataque sorpresa: mano enemiga vista, '%s' descartada" % eliminada.get("nombre","???"))


# ── 26 · Heal ─────────────────────────────────────────────────────────────────
# El jugador se cura 2 de vida. (PotiPoti, id 36)
func _hab_heal(propietario: String) -> bool:
	GameManager.curar(propietario, 2)
	print("[AbilityManager] Heal: %s se cura 2 de vida" % propietario)
	return true


# ── 27 · Terremoto ────────────────────────────────────────────────────────────
# 2 daño a un monstruo enemigo O 1 daño directo al jugador. (Factura, id 37)
func _hab_terremoto(propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)

	if not p_en["monstruos"].is_empty():
		# TODO: la UI debería permitir elegir objetivo
		var objetivo: Dictionary = p_en["monstruos"][0]
		GameManager.aplicar_danyo_a_carta(enemigo, objetivo, 2)
		print("[AbilityManager] Terremoto: 2 daño a '%s'" % objetivo.get("nombre","???"))
	else:
		GameManager.aplicar_danyo(enemigo, 1)
		print("[AbilityManager] Terremoto: 1 daño directo al jugador enemigo")
	return true


# ── 28 · Otra vez ─────────────────────────────────────────────────────────────
# Activa la habilidad de esta misma carta una segunda vez. (Disco rayado, id 38)
# Solo aplicable a hechizos (la carta hechizo tiene una habilidad que se usa al desplegarse).
# Aquí lo interpretamos como: vuelve a ejecutar la habilidad de la carta objetivo
# que el jugador seleccione entre las desplegadas.
# TODO: la UI debe pedir al jugador qué carta quiere reutilizar.
func _hab_otra_vez(carta: Card, propietario: String) -> bool:
	# Por ahora reutiliza la primera carta monstruo propia con habilidad activa
	var p: Dictionary = GameManager._get_jugador(propietario)
	for c_dict in p["monstruos"]:
		var c_nodo: Card = _buscar_nodo_por_dict(c_dict, propietario)
		if c_nodo and not c_nodo.habilidad_es_pasiva and c_nodo.habilidad_id != 28:
			var ok: bool = _ejecutar_habilidad(c_nodo.habilidad_id, c_nodo, propietario)
			print("[AbilityManager] Otra vez: habilidad %d de '%s' repetida" % [
				c_nodo.habilidad_id, c_nodo.nombre
			])
			return ok
	print("[AbilityManager] Otra vez: no hay habilidad activa que repetir")
	return false


# ── 29 · Paguitas ─────────────────────────────────────────────────────────────
# Roba 2 cartas. (Día de pago, id 39)
func _hab_paguitas(propietario: String) -> bool:
	for i in 2:
		GameManager._robar_carta_interno(propietario)
	print("[AbilityManager] Paguitas: %s roba 2 cartas" % propietario)
	return true


# ── 30 · Ligamento cruzado ────────────────────────────────────────────────────
# Aplica una maldición a una carta propia desplegada: cada vez que esa carta
# reciba daño, el jugador enemigo recibe 1 de daño adicional.
# (Contrato maldito, id 40)
# El hook comprobar_ligamento() debe llamarse desde el sistema de combate
# ANTES de aplicar daño a cualquier carta del jugador.
var _cartas_con_ligamento: Array = []   # nodos Card con la maldición activa

func _hab_ligamento_cruzado(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	if p["monstruos"].is_empty():
		print("[AbilityManager] Ligamento: no hay monstruos propios desplegados")
		return false

	# TODO: la UI debería permitir elegir; por ahora el primero sin ligamento
	for c_dict in p["monstruos"]:
		var c_nodo: Card = _buscar_nodo_por_dict(c_dict, propietario)
		if c_nodo != null and not _cartas_con_ligamento.has(c_nodo):
			_cartas_con_ligamento.append(c_nodo)
			print("[AbilityManager] Ligamento cruzado aplicado a '%s'" % c_nodo.nombre)
			return true

	print("[AbilityManager] Ligamento: todas las cartas ya tienen ligamento")
	return false


## Llama ANTES de aplicar daño a una carta para comprobar ligamento cruzado.
## Si la carta tiene la maldición, el jugador enemigo recibe 1 de daño adicional.
func comprobar_ligamento(carta_nodo: Card, propietario_defensor: String) -> void:
	if not _cartas_con_ligamento.has(carta_nodo):
		return
	var enemigo: String = "oponente" if propietario_defensor == "jugador" else "jugador"
	GameManager.aplicar_danyo(enemigo, 1)
	print("[AbilityManager] Ligamento cruzado: '%s' recibe daño → 1 al enemigo" % carta_nodo.nombre)


# ── 32 · Existencia ───────────────────────────────────────────────────────────
func _hab_existencia() -> bool:
	print("[AbilityManager] Existencia: no hace nada.")
	return true


# ═════════════════════════════════════════════
#  HABILIDADES PASIVAS — IMPLEMENTACIÓN
# ═════════════════════════════════════════════

# ── 1 · Cuerpo elemental ──────────────────────────────────────────────────────
# Cuando esta carta es atacada, el atacante sufre 1 daño si no tiene equipamiento.
func _pas_cuerpo_elemental(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_ATACADA or datos.get("victima") != carta:
		return
	var atacante: Card = datos.get("atacante")
	# Sin equipamiento global activo en el atacante → devuelve 1 daño
	if atacante == null or GameManager.tiene_equipamiento(atacante.propietario):
		return
	atacante.recibir_danyo(1)
	print("[AbilityManager] Cuerpo elemental: '%s' devuelve 1 daño a '%s'" % [
		carta.nombre, atacante.nombre
	])


# ── 4 · Resiliencia ───────────────────────────────────────────────────────────
# Si el daño no es letal, no se aplica.
func _pas_resiliencia(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_ATACADA or datos.get("victima") != carta:
		return
	var danyo: int = datos.get("danyo", 0)
	if danyo < carta.vida_actual:
		datos["cancelado"] = true
		print("[AbilityManager] Resiliencia: daño no letal cancelado en '%s'" % carta.nombre)


# ── 6 · Espejito rebotín ──────────────────────────────────────────────────────
# El daño no letal recibido se refleja al atacante (y se cancela en la víctima).
func _pas_espejito_rebotin(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_ATACADA or datos.get("victima") != carta:
		return
	var danyo: int = datos.get("danyo", 0)
	if danyo >= carta.vida_actual:
		return   # daño letal: no se refleja
	var atacante: Card = datos.get("atacante")
	if atacante == null:
		return
	atacante.recibir_danyo(danyo)
	datos["cancelado"] = true
	print("[AbilityManager] Espejito rebotín: %d daño reflejado a '%s'" % [danyo, atacante.nombre])


# ── 8 · Penitencia racial ─────────────────────────────────────────────────────
# Cuando otra carta entra al campo, si NO es de expansion "Juguetes", pierde 1 vida.
func _pas_penitencia_racial(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_DESPLEGADA:
		return
	var nueva: Card = datos.get("carta")
	if nueva == null or nueva == carta:
		return
	if nueva.expansion == "Juguetes":
		return
	nueva.recibir_danyo(1)
	print("[AbilityManager] Penitencia racial: '%s' pierde 1 vida al entrar" % nueva.nombre)


# ── 9 · Foco ──────────────────────────────────────────────────────────────────
# Cada vez que esta carta ataca, +1 ataque permanente.
func _pas_foco(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_ATACO or datos.get("carta") != carta:
		return
	carta.ataque_actual += 1
	carta._actualizar_textos()
	print("[AbilityManager] Foco: '%s' +1 atk → %d" % [carta.nombre, carta.ataque_actual])


# ── 11 · Escuadrón ────────────────────────────────────────────────────────────
# Si esta carta atacó, crea una copia en el campo si hay espacio.
func _pas_escuadron(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_ATACO or datos.get("carta") != carta:
		return
	var propietario: String = carta.propietario
	var p: Dictionary = GameManager._get_jugador(propietario)
	if p["monstruos"].size() >= GameManager.MAX_MONSTRUOS:
		return

	var copia: Dictionary = carta.get_datos_actuales().duplicate(true)
	copia["nombre"] = carta.nombre + " (copia)"
	p["monstruos"].append(copia)
	# La instancia visual la crea el sistema de UI cuando detecte la nueva entrada
	print("[AbilityManager] Escuadrón: copia de '%s' creada en el campo" % carta.nombre)


# ── 13 · Sacrificio prometido ─────────────────────────────────────────────────
# Al morir esta carta: roba 1 carta y descarta 1 al azar de la mano.
func _pas_sacrificio_prometido(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_MUERTA or datos.get("carta") != carta:
		return
	var propietario: String = carta.propietario
	GameManager._robar_carta_interno(propietario)

	var p: Dictionary = GameManager._get_jugador(propietario)
	if not p["mano"].is_empty():
		var idx: int = randi() % p["mano"].size()
		var descartada: Dictionary = p["mano"][idx]
		p["mano"].remove_at(idx)
		p["cementerio"].append(descartada)
		print("[AbilityManager] Sacrificio prometido: '%s' descartada al azar" % descartada.get("nombre","???"))


# ── 14 · Paciencia ────────────────────────────────────────────────────────────
# Al atacar: resetea ataque al base. Sin atacar: se acumula en tick_paciencia().
func _pas_paciencia(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_ATACO or datos.get("carta") != carta:
		return
	# Revierte al ataque base; el buff del equipamiento global se re-aplica si sigue activo
	carta.ataque_actual = carta.ataque_base
	var p := GameManager._get_jugador(carta.propietario)
	if not p["equipamiento"].is_empty():
		carta.ataque_actual += p["equipamiento"].get("attack", 0)
	carta._actualizar_textos()
	print("[AbilityManager] Paciencia: '%s' atk reseteado a %d" % [carta.nombre, carta.ataque_actual])


## Llama al INICIO de cada turno del propietario para acumular Paciencia.
func tick_paciencia(propietario: String) -> void:
	for carta in _get_cartas_desplegadas_nodos(propietario):
		if carta.habilidad_id == 14 \
		and not carta.usada_este_turno:
			carta.ataque_actual += 1
			carta._actualizar_textos()
			print("[AbilityManager] Paciencia: '%s' +1 atk acumulado → %d" % [
				carta.nombre, carta.ataque_actual
			])


# ── 21 · Datapack ─────────────────────────────────────────────────────────────
# Al entrar al campo, roba 1 carta. (USB Cifrado, id 28)
func _pas_datapack(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_DESPLEGADA or datos.get("carta") != carta:
		return
	GameManager._robar_carta_interno(carta.propietario)
	print("[AbilityManager] Datapack: '%s' roba 1 carta al desplegarse" % carta.nombre)


# ── 23 · Exterminator ─────────────────────────────────────────────────────────
# Al ser desplegado, extermina una carta enemiga al azar. (Robot Exterminador, id 30)
func _pas_exterminator(carta: Card, evento: String, datos: Dictionary) -> void:
	if evento != EVENTO_CARTA_DESPLEGADA or datos.get("carta") != carta:
		return
	var enemigo: String = "oponente" if carta.propietario == "jugador" else "jugador"
	var p_en: Dictionary = GameManager._get_jugador(enemigo)
	var pool: Array = p_en["monstruos"] + p_en["hechizos"]

	if pool.is_empty():
		return

	var objetivo: Dictionary = pool[randi() % pool.size()]
	var zona: String = "monstruos" if p_en["monstruos"].has(objetivo) else "hechizos"
	GameManager.enviar_al_cementerio(enemigo, objetivo, zona)
	print("[AbilityManager] Exterminator: '%s' exterminada" % objetivo.get("nombre","???"))


# ═════════════════════════════════════════════
#  HELPERS INTERNOS
# ═════════════════════════════════════════════

func _get_todas_cartas_desplegadas() -> Array:
	return _get_cartas_desplegadas_nodos("jugador") + _get_cartas_desplegadas_nodos("oponente")


func _get_cartas_desplegadas_nodos(propietario: String) -> Array:
	var resultado: Array = []
	_buscar_cards_recursivo(get_tree().get_root(), propietario, resultado)
	return resultado


func _buscar_cards_recursivo(nodo: Node, propietario: String, resultado: Array) -> void:
	if nodo is Card and nodo.propietario == propietario and not nodo.mostrar_reverso:
		resultado.append(nodo)
	for hijo in nodo.get_children():
		_buscar_cards_recursivo(hijo, propietario, resultado)


## Busca un Dictionary de carta por su id dentro de monstruos, hechizos y mano.
func _buscar_carta_por_id(p: Dictionary, card_id: int) -> Dictionary:
	for zona in ["monstruos", "hechizos", "mano"]:
		var encontrada := _buscar_carta_por_id_en_zona(p[zona], card_id)
		if not encontrada.is_empty():
			return encontrada
	return {}


func _buscar_carta_por_id_en_zona(zona: Array, card_id: int) -> Dictionary:
	for c in zona:
		if c.get("id", -1) == card_id:
			return c
	return {}


## Descarta (→ cementerio) la primera carta con ese id encontrada en monstruos/hechizos/mano.
func _descartar_carta_por_id(p: Dictionary, propietario: String, card_id: int) -> void:
	for zona_nombre in ["monstruos", "hechizos", "mano"]:
		for c in p[zona_nombre]:
			if c.get("id", -1) == card_id:
				p[zona_nombre].erase(c)
				p["cementerio"].append(c)
				print("[AbilityManager] Descartada carta id=%d de zona '%s'" % [card_id, zona_nombre])
				return


## Busca el nodo Card en escena con el id dado y propietario.
func _buscar_nodo_por_id(card_id: int, propietario: String) -> Card:
	for carta in _get_cartas_desplegadas_nodos(propietario):
		if carta.id == card_id:
			return carta
	return null


## Busca el nodo Card en escena que coincide con un Dictionary (por id y nombre).
func _buscar_nodo_por_dict(datos: Dictionary, propietario: String) -> Card:
	for carta in _get_cartas_desplegadas_nodos(propietario):
		if carta.id == datos.get("id", -1):
			return carta
	return null
