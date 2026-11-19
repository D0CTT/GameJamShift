extends Node
## El identificador se traduce a una escena reutilizable al llegar al destino.
const ITEM_SCENES: Dictionary = {
	&"powered_lights": preload("res://scenes/components/powered_lights.tscn"),
}

func change_level(level_number: int, scene_path: String) -> void:
	var result := get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_error("Could not load level: " + scene_path + " (" + error_string(result) + ")")
		return
	GameState.current_level = level_number
	print("Loading level: ", level_number)

## Llamar una sola vez al entrar en el nivel, después del _ready del Player.
## world_parent debe existir en el escenario para que Q pueda devolver el objeto al mundo.
func restore_carried_item(player: Node3D, world_parent: Node3D) -> bool:
	if not GameState.carried_item_pending:
		return true
	var item_id: StringName = GameState.carried_item_id
	if item_id == &"":
		GameState.carried_item_pending = false
		return true
	if not is_instance_valid(player) or not is_instance_valid(world_parent):
		return false
	if not player.has_method("try_pickup") or not world_parent.is_inside_tree():
		return false
	if not ITEM_SCENES.has(item_id):
		push_error("Unknown carried item: " + String(item_id))
		return false
	var packed := ITEM_SCENES[item_id] as PackedScene
	var item := packed.instantiate() as Node3D
	if item == null:
		return false
	world_parent.add_child(item)
	if not bool(player.call("try_pickup", item)):
		item.queue_free()
		push_error("Could not restore carried item: " + String(item_id))
		return false
	GameState.carried_item_pending = false
	print("Restored carried item: ", item_id)
	return true


# Cache de estas dos escenas durante la partida, sin mantener dos mundos activos.
# Los nodos estacionados salen del SceneTree, pero NO se destruyen.
var travel_busy: bool = false
var parked_scenes: Dictionary = {}
var travel_fade: ColorRect

func _ready() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 90 # debajo del menú de idiomas (100)
	add_child(overlay)
	travel_fade = ColorRect.new()
	overlay.add_child(travel_fade)
	travel_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	travel_fade.hide()

func travel_between(level_number: int, scene_path: String) -> void:
	if travel_busy:
		return
	var tree := get_tree()
	var source := tree.current_scene
	if not is_instance_valid(source) or not source.has_method("get_travel_player"):
		return
	var source_player := source.call("get_travel_player") as Node3D
	var source_path := source.scene_file_path
	if scene_path == source_path or not is_instance_valid(source_player):
		return
	var destination := parked_scenes.get(scene_path) as Node
	var from_cache := is_instance_valid(destination)
	if not from_cache:
		var packed := load(scene_path) as PackedScene
		if packed != null:
			destination = packed.instantiate()
	if not is_instance_valid(destination) or not destination.has_method("get_travel_player") or not destination.has_method("get_travel_items") or not destination.has_method("prepare_travel_arrival"):
		if is_instance_valid(destination) and not from_cache:
			destination.free()
		if source.has_method("travel_failed"):
			source.call("travel_failed")
		push_error("Invalid travel destination: " + scene_path)
		return

	travel_busy = true
	source_player.call("set_controls_enabled", false)
	travel_fade.show()
	var fade_out := create_tween()
	fade_out.tween_property(travel_fade, "color:a", 1.0, 0.65)
	await fade_out.finished

	# Mover el mismo objeto, no generar una copia. Los objetos soltados con Q
	# se quedan en su escena. El nuevo padre se registra al hacer try_pickup.
	var held := source_player.get("held_item") as Node3D
	var item_id: StringName = &""
	if is_instance_valid(held):
		item_id = StringName(held.get("item_id"))
		source_player.set("held_item", null)
		source_player.set("pickup_parent", null)
		source_player.set("drop_requested", false)
		held.get_parent().remove_child(held)
		source_player.emit_signal("held_item_changed", null)

	parked_scenes.erase(scene_path)
	parked_scenes[source_path] = source
	tree.current_scene = null
	tree.root.remove_child(source)
	GameState.current_level = level_number
	GameState.carried_item_id = item_id
	GameState.carried_item_pending = false
	tree.root.add_child(destination)
	tree.current_scene = destination
	var destination_player := destination.call("get_travel_player") as Node3D
	var item_parent := destination.call("get_travel_items") as Node3D
	destination_player.call("set_controls_enabled", false)
	destination.call("prepare_travel_arrival")
	if is_instance_valid(held):
		item_parent.add_child(held)
		# Si la recogida fallase, queda accesible delante del jugador.
		held.global_position = destination_player.global_position - destination_player.global_transform.basis.z * 0.9 + Vector3.UP * 0.16
		if not bool(destination_player.call("try_pickup", held)):
			held.call("set_returned")
			GameState.carried_item_id = &""
			push_warning("Transferred item placed on the ground")
	var camera := destination_player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera != null:
		camera.make_current()
	# Unos breves instantes en negro para que el nuevo mundo aparezca ya encuadrado.
	await tree.create_timer(0.20, false).timeout
	var fade_in := create_tween()
	fade_in.tween_property(travel_fade, "color:a", 0.0, 0.80)
	await fade_in.finished
	travel_fade.hide()
	destination_player.call("set_controls_enabled", true)
	travel_busy = false
	print("Loading level: ", level_number, " | carried: ", item_id)

func clear_travel_cache() -> void:
	for scene in parked_scenes.values():
		if is_instance_valid(scene):
			scene.free()
	parked_scenes.clear()

func _exit_tree() -> void:
	clear_travel_cache()
