extends Node
## Estado de la partida; no guarda nodos que desaparecen al cambiar de escena.
enum Phase { ASCENT, DESCENT, COMBAT }

var phase: Phase = Phase.ASCENT
var current_level: int = 1
var level_01_completed: bool = false
var carried_item_id: StringName = &""
var carried_item_pending: bool = false
var skin_color: StringName = &"red"
var destroyed_objects: Dictionary = {}

func complete_level_01(item_id: StringName) -> void:
	level_01_completed = true
	prepare_item_transfer(item_id)
	print("Level 1 completed")
	print("Carried item: ", carried_item_id)

func prepare_item_transfer(item_id: StringName) -> void:
	carried_item_id = item_id
	carried_item_pending = true

## Call from the real summit revelation, or the provisional cabin test.
func begin_descent() -> void:
	if phase != Phase.ASCENT:
		return
	phase = Phase.DESCENT
	skin_color = &"green"

func reset_run() -> void:
	phase = Phase.ASCENT
	current_level = 1
	level_01_completed = false
	carried_item_id = &""
	carried_item_pending = false
	skin_color = &"red"
	destroyed_objects.clear()
