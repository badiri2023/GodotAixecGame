extends Node
# AbilityManager.gd
# SINGLETON — AutoLoad > nombre: "AbilityManager"


# ═════════════════════════════════════════════
#  SEÑALES
# ═════════════════════════════════════════════
signal habilidad_activada(carta, habilidad_id: int)
signal habilidad_fallida(carta, razon: String)


# ═════════════════════════════════════════════
#  CONSTANTES DE EVENTOS
# ═════════════════════════════════════════════
const EVENTO_CARTA_ATACADA    := "carta_atacada"
const EVENTO_CARTA_DESPLEGADA := "carta_desplegada"
const EVENTO_CARTA_MUERTA     := "carta_muerta"
const EVENTO_CARTA_ATACO      := "carta_ataco"


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

	var ok: bool = _ejecutar_activa(carta.habilidad_id, carta, propietario)
	if ok:
		carta.marcar_como_usada()
		emit_signal("habilidad_activada", carta, carta.habilidad_id)
		# Los hechizos se descartan al usar su habilidad
		if carta.tipo == Card.TIPO_HECHIZO:
			var p: Dictionary = GameManager._get_jugador(propietario)
			var datos: Dictionary = _buscar_dict_por_id(p["hechizos"], carta.id)
			if not datos.is_empty():
				GameManager.enviar_al_cementerio(propietario, datos, "hechizos")
	return ok


func _ejecutar_activa(id: int, carta: Card, propietario: String) -> bool:
	match id:
		2:  return _hab_familia(carta, propietario)
		3:  return _hab_sugestion(carta, propietario)
		5:  return _hab_supresion_sacrificial(carta, propietario)
		8:  return _hab_penitencia_racial(propietario)
		15: return _hab_maldicion(propietario)
		16: return _hab_sudo_update(carta, propietario)
		17: return _hab_reforjado(carta, propietario)
		19: return _hab_mega_update(carta, propietario)
		21: return _hab_datapack(carta, propietario)
		22: return _hab_antivirus(propietario)
		26: return _hab_heal(propietario)
		27: return _hab_terremoto(propietario)
		28: return _hab_otra_vez(propietario)
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
func _hab_supresion_sacrificial(carta: Card, propietario: String) -> bool:
	var enemiga: Card = SelectionManager.carta_enemiga_seleccionada
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
func _hab_maldicion(propietario: String) -> bool:
	var enemiga: Card = SelectionManager.carta_enemiga_seleccionada
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
	var usb  := _buscar_dict_por_nombre(p["mano"], "USB Cifrado")
	var desc := _buscar_dict_por_nombre(p["mano"], "Descifrador de datos")
	if usb.is_empty() or desc.is_empty():
		return false
	p["mano"].erase(usb)
	p["mano"].erase(desc)
	p["cementerio"].append(usb)
	p["cementerio"].append(desc)
	carta.nombre           = "Hacker Experto"
	carta.ataque_base      = 4
	carta.ataque_actual    = 4
	carta.defensa_base     = 2
	carta.vida_actual      = max(carta.vida_actual, 2)
	carta.habilidad_id     = 22
	carta.habilidad_nombre      = "Antivirus"
	carta.habilidad_descripcion = "Al activarse la habilidad, hace 1 de daño a todas las cartas enemigas que sean Futuristico."
	carta.habilidad_es_pasiva   = false
	carta._actualizar_textos()
	print("[AbilityManager] Sudo Update: Hacker → Hacker Experto")
	return true


# ── 17 · Reforjado ────────────────────────────────────────────────────────────
# Requiere "Robot" en mano. Lo descarta y evoluciona esta carta a "Robot Blindado"
# (id 25: atk 2, def 4, hab 19).
func _hab_reforjado(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	var robot := _buscar_dict_por_nombre(p["mano"], "Robot")
	if robot.is_empty():
		return false
	p["mano"].erase(robot)
	p["cementerio"].append(robot)
	carta.nombre           = "Robot Blindado"
	carta.ataque_base      = 2
	carta.ataque_actual    = 2
	carta.defensa_base     = 4
	carta.vida_actual      = max(carta.vida_actual, 4)
	carta.habilidad_id     = 19
	carta.habilidad_nombre      = "Mega Update"
	carta.habilidad_descripcion = "Si Soldador y Canon de plasma estan en tu mano, las descartas y esta carta evoluciona a Robot Exterminador."
	carta.habilidad_es_pasiva   = false
	carta._actualizar_textos()
	print("[AbilityManager] Reforjado: carta → Robot Blindado")
	return true


# ── 19 · Mega Update ──────────────────────────────────────────────────────────
# Requiere "Soldador" y "Canon de plasma" en mano. Los descarta y evoluciona
# esta carta a "Robot Exterminador" (id 30: atk 5, def 3, hab 23).
func _hab_mega_update(carta: Card, propietario: String) -> bool:
	var p: Dictionary = GameManager._get_jugador(propietario)
	var soldador := _buscar_dict_por_nombre(p["mano"], "Soldador")
	var canon    := _buscar_dict_por_nombre(p["mano"], "Canon de plasma")
	if soldador.is_empty() or canon.is_empty():
		return false
	p["mano"].erase(soldador)
	p["mano"].erase(canon)
	p["cementerio"].append(soldador)
	p["cementerio"].append(canon)
	carta.nombre           = "Robot Exterminador"
	carta.ataque_base      = 5
	carta.ataque_actual    = 5
	carta.defensa_base     = 3
	carta.vida_actual      = max(carta.vida_actual, 3)
	carta.habilidad_id     = 23
	carta.habilidad_nombre      = "Exterminator"
	carta.habilidad_descripcion = "Si al recibir daño y este no es letal, mata instantáneamente a la carta atacante."
	carta.habilidad_es_pasiva   = true
	carta._actualizar_textos()
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
func _hab_otra_vez(propietario: String) -> bool:
	var enemiga: Card = SelectionManager.carta_enemiga_seleccionada
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
#  HELPERS INTERNOS
# ═════════════════════════════════════════════

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
