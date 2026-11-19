extends StaticBody3D
## Reusable Christmas target. Add a Visual Node3D containing static meshes.
signal destroyed(object_id: StringName)

enum DestructionStyle { BREAK, FALL }
const XRAY_SHADER = preload("res://shaders/destruction_xray.gdshader")
const HIT_SOUND = preload("res://assets/audio/destruction_hit.wav")

@export var object_id: StringName = &""
@export var style: DestructionStyle = DestructionStyle.BREAK
@export_range(0.1, 2.0, 0.05) var duration: float = 0.45
@export var requires_empty_hands: bool = true
@onready var visual: Node3D = $Visual

var is_destroyed: bool = false
var destroying: bool = false
var _markers: Array[MeshInstance3D] = []
var _highlight_active: bool = false
var _initial_rotation: Vector3

func _ready() -> void:
	add_to_group("destructible")
	_initial_rotation = visual.rotation
	if object_id == &"":
		push_error("Destructible needs a unique object_id: " + str(get_path()))
		set_process(false)
		return
	if GameState.destroyed_objects.get(object_id, false) == true:
		is_destroyed = true
		_apply_destroyed_visual()
		_disable_collision()
		set_process(false)
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	var material := ShaderMaterial.new()
	material.shader = XRAY_SHADER
	material.render_priority = 100
	for source in meshes:
		if source.mesh == null:
			continue
		var marker := MeshInstance3D.new()
		marker.name = "DestructionXRay"
		marker.mesh = source.mesh
		marker.material_override = material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.ignore_occlusion_culling = true
		source.add_child(marker)
		marker.hide()
		_markers.append(marker)
	_refresh_highlight()

func _process(_delta: float) -> void:
	_refresh_highlight()

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)

func _refresh_highlight() -> void:
	var active: bool = GameState.phase == GameState.Phase.DESCENT and not is_destroyed and not destroying
	if active == _highlight_active:
		return
	_highlight_active = active
	for marker in _markers:
		if is_instance_valid(marker):
			marker.visible = active

## Only the melee hit invokes this. E no longer destroys targets.
func punch_with_player(player: Node3D) -> void:
	if GameState.phase != GameState.Phase.DESCENT or destroying or is_destroyed or object_id == &"":
		return
	if requires_empty_hands and is_instance_valid(player.get("held_item")):
		return
	get_tree().call_group("makeshift_retro_fx", "pulse", 0.65, false)
	destroy()

func destroy() -> void:
	if GameState.phase != GameState.Phase.DESCENT or destroying or is_destroyed or object_id == &"":
		return
	destroying = true
	_refresh_highlight()
	_disable_collision()
	var sound := AudioStreamPlayer3D.new()
	sound.stream = HIT_SOUND
	sound.unit_size = 2.0
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	var tween := create_tween()
	if style == DestructionStyle.FALL:
		# Visual's origin is the base of the tree.
		tween.tween_property(visual, "rotation:z", visual.rotation.z + PI * 0.49, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.set_parallel(true)
		tween.tween_property(visual, "scale", visual.scale * 0.04, duration)
		tween.tween_property(visual, "rotation:z", visual.rotation.z + 0.7, duration)
	await tween.finished
	_apply_destroyed_visual()
	is_destroyed = true
	destroying = false
	GameState.destroyed_objects[object_id] = true
	destroyed.emit(object_id)
	set_process(false)

func _apply_destroyed_visual() -> void:
	if style == DestructionStyle.FALL:
		visual.rotation = _initial_rotation + Vector3(0.0, 0.0, PI * 0.49)
	else:
		visual.hide()

func _disable_collision() -> void:
	# Keep the root alive so the destruction signal and ID remain accessible.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
