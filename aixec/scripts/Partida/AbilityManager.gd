extends Node
# AbilityManager.gd
# SINGLETON — AutoLoad > nombre: "AbilityManager"


# ═════════════════════════════════════════════
#  SEÑALES
# ═════════════════════════════════════════════
signal habilidad_activada(carta, habilidad_id: int)
signal habilidad_fallida(carta, razon: String)
signal carta_evolucionada(carta_vieja: Card, id_nueva: int, propietario: String)
signal hechizo_usado(nodo: Card)   ## emitida con el nodo exacto para moverlo al cementerio


# ═════════════════════════════════════════════
#  CONSTANTES DE EVENTOS
# ═════════════════════════════════════════════
const EVENTO_CARTA_ATACADA    := "carta_atacada"
const EVENTO_CARTA_DESPLEGADA := "carta_desplegada"
const EVENTO_CARTA_MUERTA     := "carta_muerta"
const EVENTO_CARTA_ATACO      := "carta_ataco"


# ═════════════════════════════════════════════
#  CONSTANTES DE IDs DE CARTAS
# ═════════════════════════════════════════════
const ID_USB_CIFRADO        := 28
const ID_DESCIFRADOR        := 27
const ID_HACKER_EXPERTO     := 29
const ID_ROBOT              := 21
const ID_ROBOT_BLINDADO     := 25
const ID_SOLDADOR           := 24
const ID_CANON_PLASMA       := 26
const ID_ROBOT_EXTERMINADOR := 30
const IDS_SLIME: Array      = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]


# ═════════════════════════════════════════════
#  ESTADO INTERNO
# ═════════════════════════════════════════════

## Efectos de duración: { Card -> { tipo, turnos_restantes, propietario } }
var _efectos_activos: Dictionary = {}

## Cartas con Paciencia acumulada: { Card -> int (turnos sin atacar) }
var _paciencia: Dictionary = {}


# ═════════════════════════════════════════════
#  API PÚBLICA — ACTIVAS
# ═════════════════════════════════════════════

## Activa la habilidad activa de una carta. Llamado desde GameUI al pulsar el botón.
func activar_habilidad_activa(carta: Card, propietario: String, carta_objetivo: Card = null) -> bool:
	if not GameManager.es_mi_turno(propietario):
		emit_signal("habilidad_fallida", carta, "No es tu turno")
		return false
	if carta.usada_este_turno:
		emit_signal("habilidad_fallida", carta, "Esta carta ya actuó este turno")
		return false
	if carta.habilidad_es_pasiva:
		emit_signal("habilidad_fallida", carta, "Esta habilidad es pasiva")
		return false

	# Valida condiciones antes de ejecutar
	var error_validacion: String = _validar_habilidad(carta.habilidad_id, propietario, carta_objetivo)
	if error_validacion != "":
		emit_signal("habilidad_fallida", carta, error_validacion)
		return false

	# Para hechizos NO marcamos como usada (se van al cementerio igualmente)
	# Para monstruos sí marcamos siempre para evitar reuso
	if carta.tipo != Card.TIPO_HECHIZO:
		carta.marcar_como_usada()

	var ok: bool = _ejecutar_activa(carta.habilidad_id, carta, propietario, carta_objetivo)
	if ok:
		emit_signal("habilidad_activada", carta, carta.habilidad_id)
		# Los hechizos se descartan usando el índice del nodo en p["hechizos"]
		if carta.tipo == Card.TIPO_HECHIZO:
			var p: Dictionary = GameManager._get_jugador(propietario)
			# Busca el índice del hechizo por id para soportar duplicados
			var idx_hechizo: int = -1
			for i in p["hechizos"].size():
				if int(p["hechizos"][i].get("id", -1)) == carta.id:
					idx_hechizo = i
					break
			if idx_hechizo >= 0:
				var datos: Dictionary = p["hechizos"][idx_hechizo]
				p["hechizos"].remove_at(idx_hechizo)
				p["cementerio"].append(datos)
				# Emite señal con el nodo exacto para que GameUI mueva el slot correcto
				emit_signal("hechizo_usado", carta)
				# Comprueba derrota por si se quedó sin cartas
				GameManager._comprobar_derrota_sin_cartas(propietario)
	else:
		# Si falla y era monstruo, la marca ya fue puesta — no pasa nada
		emit_signal("habilidad_fallida", carta, "La habilidad no pudo ejecutarse")
	return ok


func _ejecutar_activa(id: int, carta: Card, propietario: String, carta_objetivo: Card = null) -> bool:
	match id:
		2:  return _hab_familia(carta, propietario)
		3:  return _hab_sugestion(carta, propietario)
		5:  return _hab_supresion_sacrificial(carta, propietario, carta_objetivo)
		8:  return _hab_penitencia_racial(propietario)
		15: return _hab_maldicion(propietario, carta_objetivo)
		16: return _hab_sudo_update(carta, propietario)
		17: return _hab_reforjado(carta, propietario)
		19: return _hab_mega_update(carta, propietario)
		21: return _hab_datapack(carta, propietario)
		22: return _hab_antivirus(propietario)
		26: return _hab_heal(propietario)
		27: return _hab_terremoto(propietario)
		28: return _hab_otra_vez(propietario, carta_objetivo)
		29: return _hab_paguitas(propietario)
		30: return _hab_ligamento_cruzado(propietario)
		_:
			emit_signal("habilidad_fallida", carta, "Habilidad no implementada")
			return false


# ─────────────────────────────────────────────────────────────────────────────
#  IMPLEMENTACIÓN HABILIDADES ACTIVAS
# ─────────────────────────────────────────────────────────────────────────────

# ── 2 · Familia ───────────────────────────────────────────────────────────────
# Por cada Slime desplegado (incluidos enemigos), esta carta gana +1 ataque.
func _hab_familia(carta: Card, propietario: String) -> bool:
	var slimes: int = 0
	for c in get_tree().get_nodes_in_group("desplegadas"):
		if c is Card and "Slime" in c.nombre:
			slimes += 1
	if slimes == 0:
		return false
	carta.ataque_actual += slimes
	carta._actualizar_textos()
	print("[AbilityManager] Familia: '%s' +%d atk" % [carta.nombre, slimes])
	return true


# ── 3 · Sugestión ─────────────────────────────────────────────────────────────
# Por cada Slime desplegado (incluidos enemigos), esta carta gana +1 vida.
func _hab_sugestion(carta: Card, propietario: String) -> bool:
	var slimes: int = 0
	for c in get_tree().get_nodes_in_group("desplegadas"):
		if c is Card and "Slime" in c.nombre:
			slimes += 1
	if slimes == 0:
		return false
	carta.vida_actual += slimes
	carta._actualizar_textos()
	print("[AbilityManager] Sugestión: '%s' +%d vida" % [carta.nombre, slimes])
	return true


# ── 5 · Supresión sacrificial ─────────────────────────────────────────────────
# Esta carta obtiene las estadísticas y habilidad de la carta enemiga seleccionada.
func _hab_supresion_sacrificial(carta: Card, propietario: String, carta_objetivo: Card = null) -> bool:
	var enemiga: Card = carta_objetivo
	if enemiga == null:
		return false
	carta.ataque_actual   = enemiga.ataque_actual
	carta.ataque_base     = enemiga.ataque_base
	carta.vida_actual     = enemiga.vida_actual
	carta.defensa_base    = enemiga.defensa_base
	carta.habilidad_id    = enemiga.habilidad_id
	carta.habilidad_nombre      = enemiga.habilidad_nombre
	carta.habilidad_descripcion = enemiga.habilidad_descripcion
	carta.habilidad_es_pasiva   = enemiga.habilidad_es_pasiva
	carta._actualizar_textos()
	print("[AbilityManager] Supresión: '%s' copia stats de '%s'" % [carta.nombre, enemiga.nombre])
	return true


# ── 8 · Penitencia racial ─────────────────────────────────────────────────────
# 1 de daño a todas las cartas enemigas que NO sean de expansión "Juguetes".
func _hab_penitencia_racial(propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var afectadas: int = 0
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == enemigo and carta.expansion != "Juguetes":
			carta.recibir_danyo(1)
			afectadas += 1
	print("[AbilityManager] Penitencia racial: %d cartas dañadas" % afectadas)
	return true


# ── 15 · Maldición ────────────────────────────────────────────────────────────
# Reduce a la mitad (redondeando arriba) la vida de la carta enemiga seleccionada,
# ignorando habilidades pasivas.
func _hab_maldicion(propietario: String, carta_objetivo: Card = null) -> bool:
	var enemiga: Card = carta_objetivo
	if enemiga == null:
		return false
	# ceil() para redondear arriba
	var nueva_vida: int = int(ceil(enemiga.vida_actual / 2.0))
	enemiga.vida_actual = max(1, nueva_vida)
	enemiga._actualizar_textos()
	print("[AbilityManager] Maldición: '%s' queda con %d vida" % [enemiga.nombre, enemiga.vida_actual])
	return true


# ── 16 · Sudo Update ──────────────────────────────────────────────────────────
# Requiere "USB Cifrado" y "Descifrador de datos" en mano. Los descarta y
# evoluciona esta carta a "Hacker Experto" (id 29: atk 4, def 2, hab 22).
func _hab_sudo_update(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	var usb  := _buscar_dict_por_id(p["mano"], ID_USB_CIFRADO)
	var desc := _buscar_dict_por_id(p["mano"], ID_DESCIFRADOR)
	if usb.is_empty() or desc.is_empty():
		return false
	# Descarta por índice para evitar problemas con referencias duplicadas
	var idx_usb:  int = p["mano"].find(usb)
	var idx_desc: int = p["mano"].find(desc)
	if idx_usb > idx_desc:
		p["mano"].remove_at(idx_usb)
		p["mano"].remove_at(idx_desc)
	else:
		p["mano"].remove_at(idx_desc)
		p["mano"].remove_at(idx_usb)
	p["cementerio"].append(usb)
	p["cementerio"].append(desc)
	# Actualiza el dict de monstruos con los nuevos datos
	_actualizar_dict_monstruo(p, carta.id, ID_HACKER_EXPERTO)
	# Emite señal para que GameUI haga la sustitución visual
	emit_signal("carta_evolucionada", carta, ID_HACKER_EXPERTO, propietario)
	print("[AbilityManager] Sudo Update: Hacker → Hacker Experto")
	return true


# ── 17 · Reforjado ────────────────────────────────────────────────────────────
# Requiere "Robot" en mano. Lo descarta y evoluciona esta carta a "Robot Blindado"
# (id 25: atk 2, def 4, hab 19).
func _hab_reforjado(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	var robot := _buscar_dict_por_id(p["mano"], ID_ROBOT)
	if robot.is_empty():
		return false
	var idx_robot: int = p["mano"].find(robot)
	if idx_robot >= 0:
		p["mano"].remove_at(idx_robot)
	p["cementerio"].append(robot)
	_actualizar_dict_monstruo(p, carta.id, ID_ROBOT_BLINDADO)
	emit_signal("carta_evolucionada", carta, ID_ROBOT_BLINDADO, propietario)
	print("[AbilityManager] Reforjado: carta → Robot Blindado")
	return true


# ── 19 · Mega Update ──────────────────────────────────────────────────────────
# Requiere "Soldador" y "Canon de plasma" en mano. Los descarta y evoluciona
# esta carta a "Robot Exterminador" (id 30: atk 5, def 3, hab 23).
func _hab_mega_update(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	var soldador := _buscar_dict_por_id(p["mano"], ID_SOLDADOR)
	var canon    := _buscar_dict_por_id(p["mano"], ID_CANON_PLASMA)

	if soldador.is_empty() or canon.is_empty():
		return false
	# Descarta por índice para evitar problemas con referencias
	var idx_soldador: int = p["mano"].find(soldador)
	var idx_canon:    int = p["mano"].find(canon)
	# Eliminar el de mayor índice primero para no desplazar el otro
	if idx_soldador > idx_canon:
		p["mano"].remove_at(idx_soldador)
		p["mano"].remove_at(idx_canon)
	else:
		p["mano"].remove_at(idx_canon)
		p["mano"].remove_at(idx_soldador)
	p["cementerio"].append(soldador)
	p["cementerio"].append(canon)
	_actualizar_dict_monstruo(p, carta.id, ID_ROBOT_EXTERMINADOR)
	emit_signal("carta_evolucionada", carta, ID_ROBOT_EXTERMINADOR, propietario)
	print("[AbilityManager] Mega Update: carta → Robot Exterminador")
	return true


# ── 21 · Datapack ────────────────────────────────────────────────────────────
# Roba 1 carta de la baraja pero esta carta recibe 1 de daño.
func _hab_datapack(carta: Card, propietario: String) -> bool:
	GameManager._robar_carta_interno(propietario)
	carta.recibir_danyo(1)
	if carta.vida_actual <= 0:
		var p: Dictionary = GameManager._get_jugador(propietario)
		var datos := _buscar_dict_por_id(p["monstruos"], carta.id)
		if not datos.is_empty():
			GameManager.enviar_al_cementerio(propietario, datos, "monstruos")
	print("[AbilityManager] Datapack: carta robada, '%s' recibe 1 daño" % carta.nombre)
	return true


# ── 22 · Antivirus ────────────────────────────────────────────────────────────
# 1 de daño a todas las cartas enemigas de expansión "Futuristico".
func _hab_antivirus(propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var afectadas: int = 0
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == enemigo and carta.expansion == "Futuristico":
			carta.recibir_danyo(1)
			afectadas += 1
	print("[AbilityManager] Antivirus: %d cartas Futuristico dañadas" % afectadas)
	return true


# ── 26 · Heal ─────────────────────────────────────────────────────────────────
# Cura 2 de vida al jugador.
func _hab_heal(propietario: String) -> bool:
	GameManager.curar(propietario, 2)
	print("[AbilityManager] Heal: %s curado 2 vida" % propietario)
	return true


# ── 27 · Terremoto ────────────────────────────────────────────────────────────
# 50%: 2 daño a un monstruo enemigo aleatorio. 50%: 1 daño al jugador enemigo.
func _hab_terremoto(propietario: String) -> bool:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	if randf() < 0.5:
		var enemigas: Array = []
		for carta in get_tree().get_nodes_in_group("desplegadas"):
			if carta is Card and carta.propietario == enemigo and carta.tipo == Card.TIPO_MONSTRUO:
				enemigas.append(carta)
		if not enemigas.is_empty():
			var objetivo: Card = enemigas[randi() % enemigas.size()]
			objetivo.recibir_danyo(2)
			print("[AbilityManager] Terremoto: 2 daño a '%s'" % objetivo.nombre)
		else:
			# Sin monstruos → daño directo igualmente
			GameManager.aplicar_danyo(enemigo, 1)
			print("[AbilityManager] Terremoto: sin monstruos, 1 daño directo")
	else:
		GameManager.aplicar_danyo(enemigo, 1)
		print("[AbilityManager] Terremoto: 1 daño directo al jugador")
	return true


# ── 28 · Otra vez ─────────────────────────────────────────────────────────────
# Una de tus cartas seleccionadas al azar hace su daño al enemigo seleccionado.
func _hab_otra_vez(propietario: String, carta_objetivo: Card = null) -> bool:
	var enemiga: Card = carta_objetivo
	var aliadas: Array = []
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == propietario and carta.tipo == Card.TIPO_MONSTRUO:
			aliadas.append(carta)
	if aliadas.is_empty():
		return false
	var atacante: Card = aliadas[randi() % aliadas.size()]
	if enemiga != null:
		enemiga.recibir_danyo(atacante.ataque_actual)
		print("[AbilityManager] Otra vez: '%s' hace %d daño a '%s'" % [
			atacante.nombre, atacante.ataque_actual, enemiga.nombre
		])
	else:
		var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
		GameManager.aplicar_danyo(enemigo, atacante.ataque_actual)
		print("[AbilityManager] Otra vez: '%s' hace %d daño directo" % [
			atacante.nombre, atacante.ataque_actual
		])
	return true


# ── 29 · Paguitas ─────────────────────────────────────────────────────────────
# Roba 2 cartas de la baraja.
func _hab_paguitas(propietario: String) -> bool:
	for i in 2:
		GameManager._robar_carta_interno(propietario)
	print("[AbilityManager] Paguitas: %s roba 2 cartas" % propietario)
	return true


# ── 30 · Ligamento cruzado ────────────────────────────────────────────────────
# Permite ver la mano enemiga por el resto de la partida, pero hace 1 de daño
# al jugador que la activa.
var _mano_enemiga_visible: Dictionary = {"jugador": false, "oponente": false}

func _hab_ligamento_cruzado(propietario: String) -> bool:
	if _mano_enemiga_visible[propietario]:
		return false   # ya activada
	_mano_enemiga_visible[propietario] = true
	GameManager.aplicar_danyo(propietario, 1)
	# Muestra el frente de las cartas enemigas en mano (quita el reverso)
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var org: Node = _buscar_organizador_mano(enemigo)
	if org:
		for hijo in org.get_children():
			if hijo is Card:
				hijo.mostrar_reverso = false
	print("[AbilityManager] Ligamento cruzado: mano de %s visible para %s" % [enemigo, propietario])
	return true


func _buscar_organizador_mano(propietario: String) -> Node:
	var nombre_nodo: String = "DisponiblesOrganizador"
	var nombre_padre: String = "Oponente" if propietario == "oponente" else "Jugador"
	var raiz: Node = get_tree().get_root()
	return _buscar_en_subarbol_con_padre(raiz, nombre_nodo, nombre_padre)


func _buscar_en_subarbol_con_padre(nodo: Node, nombre: String, padre_nombre: String) -> Node:
	if nodo.name == padre_nombre:
		return _buscar_en_subarbol(nodo, nombre)
	for hijo in nodo.get_children():
		var r: Node = _buscar_en_subarbol_con_padre(hijo, nombre, padre_nombre)
		if r: return r
	return null


func _buscar_en_subarbol(nodo: Node, nombre: String) -> Node:
	if nodo.name == nombre: return nodo
	for hijo in nodo.get_children():
		var r: Node = _buscar_en_subarbol(hijo, nombre)
		if r: return r
	return null


func notificar_equipamiento(_monstruo: Card, _equip: Card, _propietario: String) -> void:
	pass


func tick_efectos_turno() -> void:
	pass


# ═════════════════════════════════════════════
#  API PÚBLICA — PASIVAS
# ═════════════════════════════════════════════

## Llama esto desde SelectionManager.ejecutar_ataque() ANTES de aplicar el daño.
## Devuelve un Dictionary con modificaciones al ataque:
##   "cancelar":      bool  → el daño queda anulado (Antiabductor)
##   "danyo_extra":   int   → daño adicional a aplicar (Precoz)
##   "danyo_atacante": int  → daño que recibe el atacante (Cuerpo elemental, Espejito)
##   "anular_danyo_defensor": bool → el defensor no recibe daño (Resiliencia)
func pre_ataque(atacante: Card, defensor: Card, danyo: int) -> Dictionary:
	var resultado := {
		"cancelar":               false,
		"danyo_extra":            0,
		"danyo_atacante":         0,
		"anular_danyo_defensor":  false,
	}

	# ── 24 · Antiabductor (defensor) ─────────────────────────────────────────
	# 1% de anular todo el daño
	if defensor.habilidad_id == 24:
		if randf() <= 0.01:
			print("[AbilityManager] Antiabductor: daño anulado en '%s'" % defensor.nombre)
			resultado["cancelar"] = true
			return resultado

	# ── 4 · Resiliencia (defensor) ────────────────────────────────────────────
	# Si el daño no es letal, la carta no recibe daño
	if defensor.habilidad_id == 4:
		if danyo < defensor.vida_actual:
			print("[AbilityManager] Resiliencia: daño no letal cancelado en '%s'" % defensor.nombre)
			resultado["anular_danyo_defensor"] = true

	# ── 1 · Cuerpo elemental (defensor) ──────────────────────────────────────
	# Si el atacante no tiene equipamiento, recibe 1 de daño
	if defensor.habilidad_id == 1:
		if not GameManager.tiene_equipamiento(atacante.propietario):
			print("[AbilityManager] Cuerpo elemental: 1 daño al atacante '%s'" % atacante.nombre)
			resultado["danyo_atacante"] += 1

	# ── 6 · Espejito rebotín (defensor) ──────────────────────────────────────
	# El daño que recibe la carta también lo recibe el atacante
	if defensor.habilidad_id == 6:
		print("[AbilityManager] Espejito rebotín: %d daño reflejado a '%s'" % [danyo, atacante.nombre])
		resultado["danyo_atacante"] += danyo

	# ── 12 · Precoz (atacante) ────────────────────────────────────────────────
	# 10% de causar 4 de daño adicional
	if atacante.habilidad_id == 12:
		if randf() <= 0.10:
			print("[AbilityManager] Precoz: 4 daño adicional")
			resultado["danyo_extra"] += 4

	return resultado


## Llama esto desde SelectionManager DESPUÉS de aplicar el daño y confirmar que
## el ataque ocurrió (la carta atacante atacó de verdad).
func post_ataque(atacante: Card, defensor: Card, danyo_aplicado: int,
				 defensor_murio: bool, propietario_atacante: String) -> void:

	var propietario_defensor: String = "oponente" if propietario_atacante == "jugador" else "jugador"

	# ── 9 · Foco (atacante) ───────────────────────────────────────────────────
	if atacante.habilidad_id == 9:
		atacante.ataque_actual += 1
		atacante._actualizar_textos()
		print("[AbilityManager] Foco: '%s' +1 atk → %d" % [atacante.nombre, atacante.ataque_actual])

	# ── 11 · Escuadrón (atacante) ─────────────────────────────────────────────
	if atacante.habilidad_id == 11:
		atacante.vida_actual = min(atacante.vida_actual * 2,
								   atacante.defensa_base + (GameManager.get_buff_vida_equip(propietario_atacante) if atacante.buffed else 0))
		atacante._actualizar_textos()
		print("[AbilityManager] Escuadrón: '%s' vida duplicada → %d" % [atacante.nombre, atacante.vida_actual])

	# ── 14 · Paciencia (atacante) — resetea al atacar ─────────────────────────
	if atacante.habilidad_id == 14:
		atacante.ataque_actual = 1
		atacante._actualizar_textos()
		_paciencia.erase(atacante)
		print("[AbilityManager] Paciencia: '%s' atk reseteado a 1" % atacante.nombre)

	# ── 18 · Firewall (atacante) ──────────────────────────────────────────────
	# Todas las cartas enemigas EXCEPTO la seleccionada reciben 1 de daño
	if atacante.habilidad_id == 18:
		for carta in get_tree().get_nodes_in_group("desplegadas"):
			if carta is Card and carta.propietario == propietario_defensor and carta != defensor:
				carta.recibir_danyo(1)
				print("[AbilityManager] Firewall: 1 daño a '%s'" % carta.nombre)

	# ── 20 · Troyan (atacante) ────────────────────────────────────────────────
	# También hace 2 de daño a un enemigo aleatorio en el campo
	if atacante.habilidad_id == 20:
		var enemigas: Array = []
		for carta in get_tree().get_nodes_in_group("desplegadas"):
			if carta is Card and carta.propietario == propietario_defensor:
				enemigas.append(carta)
		if not enemigas.is_empty():
			var objetivo: Card = enemigas[randi() % enemigas.size()]
			objetivo.recibir_danyo(2)
			print("[AbilityManager] Troyan: 2 daño a '%s'" % objetivo.nombre)

	# ── 25 · Ataque sorpresa (atacante) ───────────────────────────────────────
	# Hace 1 de daño a una carta enemiga aleatoria
	if atacante.habilidad_id == 25:
		var enemigas: Array = []
		for carta in get_tree().get_nodes_in_group("desplegadas"):
			if carta is Card and carta.propietario == propietario_defensor:
				enemigas.append(carta)
		if not enemigas.is_empty():
			var objetivo: Card = enemigas[randi() % enemigas.size()]
			objetivo.recibir_danyo(1)
			print("[AbilityManager] Ataque sorpresa: 1 daño a '%s'" % objetivo.nombre)

	# ── 7 · Dualidad (atacante) ───────────────────────────────────────────────
	# El daño provocado se da en forma de vida a una carta aliada al azar
	if atacante.habilidad_id == 7:
		var aliadas: Array = []
		for carta in get_tree().get_nodes_in_group("desplegadas"):
			if carta is Card and carta.propietario == propietario_atacante and carta != atacante:
				aliadas.append(carta)
		if not aliadas.is_empty():
			var objetivo: Card = aliadas[randi() % aliadas.size()]
			objetivo.recibir_curacion(danyo_aplicado)
			print("[AbilityManager] Dualidad: %d vida a '%s'" % [danyo_aplicado, objetivo.nombre])

	# ── 13 · Sacrificio prometido (defensor) ──────────────────────────────────
	# Al recibir daño, 25% de que el enemigo descarte 1 carta de su mano al azar
	if defensor.habilidad_id == 13 and not defensor_murio:
		if randf() <= 0.25:
			var p_atacante: Dictionary = GameManager._get_jugador(propietario_atacante)
			if not p_atacante["mano"].is_empty():
				var idx: int = randi() % p_atacante["mano"].size()
				var descartada: Dictionary = p_atacante["mano"][idx]
				p_atacante["mano"].remove_at(idx)
				p_atacante["cementerio"].append(descartada)
				print("[AbilityManager] Sacrificio prometido: '%s' descartada de la mano de %s" % [
					descartada.get("name","???"), propietario_atacante
				])

	# ── 23 · Exterminator (defensor) ─────────────────────────────────────────
	# Si el daño no es letal, mata instantáneamente al atacante
	if defensor.habilidad_id == 23 and not defensor_murio:
		print("[AbilityManager] Exterminator: '%s' mata instantáneamente a '%s'" % [
			defensor.nombre, atacante.nombre
		])
		atacante.vida_actual = 0
		atacante.emit_signal("carta_muerta", atacante)


## Llama al inicio de cada turno del propietario para acumular Paciencia.
func tick_paciencia(propietario: String) -> void:
	for carta in get_tree().get_nodes_in_group("desplegadas"):
		if carta is Card and carta.propietario == propietario:
			if carta.habilidad_id == 14 and not carta.usada_este_turno:
				carta.ataque_actual += 1
				carta._actualizar_textos()
				_paciencia[carta] = _paciencia.get(carta, 0) + 1
				print("[AbilityManager] Paciencia: '%s' +1 atk → %d" % [carta.nombre, carta.ataque_actual])


## Llama cuando se despliega una carta para pasivas de despliegue.
func notificar_despliegue(carta: Card, propietario: String) -> void:
	# ── 10 · Nostalgia (cualquier carta desplegada) ───────────────────────────
	# Si hay una carta con Nostalgia desplegada y otra carta muere, Nostalgia muere
	# en su lugar y la otra queda con 1 de vida. Se gestiona en notificar_muerte.
	pass


## Llama cuando una carta muere para activar la habilidad 10 (Nostalgia).
## Devuelve true si Nostalgia intervino (la carta no muere realmente).
func notificar_muerte(carta_que_muere: Card, propietario: String) -> bool:
	# ── 10 · Nostalgia ────────────────────────────────────────────────────────
	for nostalgia_carta in get_tree().get_nodes_in_group("desplegadas"):
		if nostalgia_carta is Card \
		and nostalgia_carta.propietario == propietario \
		and nostalgia_carta.habilidad_id == 10 \
		and nostalgia_carta != carta_que_muere:
			# Nostalgia sacrifica a la carta que moriría, ella misma muere en su lugar
			carta_que_muere.vida_actual = 1
			carta_que_muere._actualizar_textos()
			nostalgia_carta.vida_actual = 0
			nostalgia_carta.emit_signal("carta_muerta", nostalgia_carta)
			print("[AbilityManager] Nostalgia: '%s' muere en lugar de '%s'" % [
				nostalgia_carta.nombre, carta_que_muere.nombre
			])
			return true
	return false


# ═════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════
func comprobar_antiabductor(_carta_nodo: Card) -> bool:
	return false   # gestionado en pre_ataque

func comprobar_ligamento(_carta_nodo: Card, _propietario_defensor: String) -> void:
	pass   # habilidad 30 pendiente (activa)



# ═════════════════════════════════════════════
#  VALIDACIÓN DE HABILIDADES ACTIVAS
# ═════════════════════════════════════════════

## Devuelve "" si la habilidad puede usarse, o un mensaje de error si no.
func _validar_habilidad(id: int, propietario: String, carta_objetivo: Card) -> String:
	var enemigo: String = "oponente" if propietario == "jugador" else "jugador"
	var p_propio: Dictionary   = GameManager._get_jugador(propietario)
	var p_enemigo: Dictionary  = GameManager._get_jugador(enemigo)

	match id:
		# ── Requieren carta enemiga seleccionada ────────────────────────────
		5, 15, 28:
			if carta_objetivo == null:
				match id:
					5:  return "Selecciona una carta enemiga para copiar sus estadísticas"
					15: return "Selecciona una carta enemiga para aplicar la maldición"
					28: return "Selecciona una carta enemiga como objetivo del ataque"

		# ── Requieren cartas específicas en mano ────────────────────────────
		16:
			var tiene_usb:  bool = not _buscar_dict_por_id(p_propio["mano"], ID_USB_CIFRADO).is_empty()
			var tiene_desc: bool = not _buscar_dict_por_id(p_propio["mano"], ID_DESCIFRADOR).is_empty()
			if not tiene_usb and not tiene_desc:
				return "Necesitas USB Cifrado (id %d) y Descifrador de datos (id %d) en la mano" % [ID_USB_CIFRADO, ID_DESCIFRADOR]
			if not tiene_usb:
				return "Necesitas USB Cifrado (id %d) en la mano" % ID_USB_CIFRADO
			if not tiene_desc:
				return "Necesitas Descifrador de datos (id %d) en la mano" % ID_DESCIFRADOR

		17:
			if _buscar_dict_por_id(p_propio["mano"], ID_ROBOT).is_empty():
				return "Necesitas Robot (id %d) en la mano" % ID_ROBOT

		19:
			var tiene_soldador: bool = not _buscar_dict_por_id(p_propio["mano"], ID_SOLDADOR).is_empty()
			var tiene_canon:    bool = not _buscar_dict_por_id(p_propio["mano"], ID_CANON_PLASMA).is_empty()
			if not tiene_soldador and not tiene_canon:
				return "Necesitas Soldador (id %d) y Canon de plasma (id %d) en la mano" % [ID_SOLDADOR, ID_CANON_PLASMA]
			if not tiene_soldador:
				return "Necesitas Soldador (id %d) en la mano" % ID_SOLDADOR
			if not tiene_canon:
				return "Necesitas Canon de plasma (id %d) en la mano" % ID_CANON_PLASMA

		# ── Requieren Slimes en el campo ────────────────────────────────────
		2, 3:
			var hay_slime: bool = false
			for carta in get_tree().get_nodes_in_group("desplegadas"):
				if carta is Card and int(carta.id) in IDS_SLIME:
					hay_slime = true
					break
			if not hay_slime:
				if id == 2:
					return "No hay Slimes desplegados en el campo"
				else:
					return "No hay Slimes desplegados en el campo"

		# ── Requieren cartas enemigas con expansión específica ───────────────
		8:
			var hay_no_juguete: bool = false
			for carta in get_tree().get_nodes_in_group("desplegadas"):
				if carta is Card and carta.propietario == enemigo and carta.expansion != "Juguetes":
					hay_no_juguete = true
					break
			if not hay_no_juguete:
				return "No hay cartas enemigas que no sean Juguetes"

		22:
			var hay_futuristico: bool = false
			for carta in get_tree().get_nodes_in_group("desplegadas"):
				if carta is Card and carta.propietario == enemigo and carta.expansion == "Futuristico":
					hay_futuristico = true
					break
			if not hay_futuristico:
				return "No hay cartas enemigas de expansión Futuristico"

		# ── Terremoto: requiere que haya algo que atacar (monstruo o jugador) ──
		27:
			# Siempre se puede usar: si no hay monstruos el daño va al jugador enemigo
			if p_enemigo.is_empty():
				return "No hay oponente al que atacar"

		# ── Sin comprobación ────────────────────────────────────────────────
		21, 26, 29, 30:
			pass

	return ""


# ═════════════════════════════════════════════
#  HELPERS INTERNOS
# ═════════════════════════════════════════════

## Actualiza el dict de la carta en p["monstruos"] con los datos de la carta nueva
func _actualizar_dict_monstruo(p: Dictionary, id_viejo: int, id_nuevo: int) -> void:
	var datos_nuevos: Dictionary = CardLoader.get_carta(id_nuevo)
	if datos_nuevos.is_empty():
		return
	for i in p["monstruos"].size():
		if int(p["monstruos"][i].get("id", -1)) == id_viejo:
			p["monstruos"][i] = datos_nuevos
			break


func _buscar_dict_por_nombre(lista: Array, nombre: String) -> Dictionary:
	for c in lista:
		if c.get("name", c.get("nombre", "")) == nombre:
			return c
	return {}


func _buscar_dict_por_id(lista: Array, card_id: int) -> Dictionary:
	for c in lista:
		if int(c.get("id", -1)) == card_id:
			return c
	return {}


## Devuelve el índice en p["hechizos"] que corresponde al nodo carta según
## el orden visual de sus slots (SlotHechizos1→0, SlotHechizos2→1, SlotHechizos3→2).
func _get_indice_hechizo_por_nodo(carta: Card, propietario: String) -> int:
	# Busca en la escena el slot que contiene este nodo
	var raiz: Node = get_tree().get_root()
	var zona: String = "Jugador" if propietario == "jugador" else "Oponente"
	var despliegue: String = "DespliegueJugador" if propietario == "jugador" else "DespliegueOponente"
	var base: Node = null
	# Busca el nodo base recursivamente
	for n in raiz.get_children():
		var encontrado: Node = _buscar_nodo_por_ruta(n, zona + "/" + despliegue)
		if encontrado:
			base = encontrado
			break
	if base == null:
		return 0  # fallback: primer hechizo

	# Recorre los slots de hechizos en orden y encuentra cuál contiene este nodo
	var slot_index: int = 0
	for hijo in base.get_children():
		var slots_en_hijo: Array = []
		if "Slot" in hijo.name and "Hechizo" in hijo.name:
			slots_en_hijo.append(hijo)
		else:
			for nieto in hijo.get_children():
				if "Slot" in nieto.name and "Hechizo" in nieto.name:
					slots_en_hijo.append(nieto)
		for slot in slots_en_hijo:
			for c in slot.get_children():
				if c == carta:
					return slot_index
			slot_index += 1
	return 0


func _buscar_nodo_por_ruta(nodo: Node, ruta: String) -> Node:
	var partes: Array = ruta.split("/")
	var actual: Node = nodo
	for parte in partes:
		var encontrado: Node = null
		for hijo in actual.get_children():
			if hijo.name == parte:
				encontrado = hijo
				break
		if encontrado == null:
			return null
		actual = encontrado
	return actual
