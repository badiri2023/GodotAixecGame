extends Node
# AbilityManager.gd
# SINGLETON — AutoLoad > nombre: "AbilityManager"
#
# Las habilidades están deshabilitadas temporalmente.
# Se reimplementarán una vez el sistema de selección de carta y combate esté completo.


# ═════════════════════════════════════════════
#  SEÑALES (se mantienen para no romper conexiones en GameUI)
# ═════════════════════════════════════════════
signal habilidad_activada(carta, habilidad_id: int)
signal habilidad_fallida(carta, razon: String)


# ═════════════════════════════════════════════
#  CONSTANTES DE EVENTOS (se mantienen para referencias futuras)
# ═════════════════════════════════════════════
const EVENTO_CARTA_ATACADA     := "carta_atacada"
const EVENTO_CARTA_DESPLEGADA  := "carta_desplegada"
const EVENTO_CARTA_MUERTA      := "carta_muerta"
const EVENTO_CARTA_ATACO       := "carta_ataco"


# ═════════════════════════════════════════════
#  API PÚBLICA — todo deshabilitado por ahora
# ═════════════════════════════════════════════

func activar_habilidad_activa(carta: Card, propietario: String) -> bool:
	emit_signal("habilidad_fallida", carta, "Habilidades no disponibles aún")
	return false


func notificar_evento(_evento: String, _datos: Dictionary) -> void:
	pass   # deshabilitado


func tick_efectos_turno() -> void:
	pass   # deshabilitado


func tick_paciencia(_propietario: String) -> void:
	pass   # deshabilitado


func notificar_equipamiento(_monstruo: Card, _equip: Card, _propietario: String) -> void:
	pass   # deshabilitado


func comprobar_ligamento(_carta_nodo: Card, _propietario_defensor: String) -> void:
	pass   # deshabilitado


func comprobar_antiabductor(_carta_nodo: Card) -> bool:
	return false   # deshabilitado
