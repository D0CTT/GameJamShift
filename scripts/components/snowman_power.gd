extends Node3D

signal lights_powered

@onready var snowman: Node3D = get_parent() as Node3D
@onready var battery_slot: StaticBody3D = $BatterySlot
@onready var lights_slot: StaticBody3D = $LightsSlot
@onready var powered: StaticBody3D = $PoweredLights
@onready var decoration: Node3D = $WrappedLights
@onready var bell: AudioStreamPlayer3D = $PlacementSound
@onready var celebration: AudioStreamPlayer3D = $CelebrationSound
var stage: int = 0

# Orden del cable: desde el extremo próximo a la batería, alrededor
# de la base y luego alrededor del torso.
const BULB_ORDER = [5, 6, 7, 8, 9, 10, 11, 12, 0, 1, 2, 3, 4, 18, 19, 20, 21, 22, 23, 24, 25, 13, 14, 15, 16, 17]
@export var unwrap_duration: float = 1.6
var bulbs: Array[MeshInstance3D] = []
var cable_segments: Array[MeshInstance3D] = []
var path_points: Array[Vector3] = []
var path_offsets: Array[float] = []
var total_length: float = 0.0
var cable_root: Node3D

func _ready() -> void:
	_set_slot(battery_slot, false)
	_set_slot(lights_slot, false)
	powered.hide()
	powered.call("set_carried")
	decoration.hide()
	_prepare_garland()
	_set_portable_coil(false)
	snowman.connect("battery_revealed", _on_battery_revealed)
	battery_slot.connect("piece_placed", _on_battery_placed)
	lights_slot.connect("piece_placed", _on_lights_placed)
	powered.connect("taken_from_snowman", _on_powered_taken)

func _set_slot(slot: StaticBody3D, active: bool) -> void:
	slot.get_node("Preview").visible = active
	slot.collision_layer = 1 if active else 0
	slot.collision_mask = 0

func _on_battery_revealed(_battery: Node3D) -> void:
	if stage != 0:
		return
	stage = 1
	_set_slot(battery_slot, true)

func _on_battery_placed(_item_id: StringName) -> void:
	if stage != 1:
		return
	stage = 2
	_set_slot(battery_slot, false)
	_set_slot(lights_slot, true)
	bell.play()

func _on_lights_placed(_item_id: StringName) -> void:
	if stage != 2:
		return
	stage = 3
	_set_slot(lights_slot, false)
	# Replace the two input items with a single powered pickup.
	for slot in [battery_slot, lights_slot]:
		var point: Node3D = slot.get_node("PlacementPoint") as Node3D
		for item in point.get_children():
			if item is StaticBody3D:
				item.hide()
				item.call("set_carried")
				item.queue_free()
	decoration.show()
	_set_portable_coil(false)
	_update_cable()
	powered.set("on_snowman", true)
	powered.show()
	powered.call("set_returned")
	celebration.play()
	lights_powered.emit()

func _on_powered_taken() -> void:
	if stage != 3:
		return
	stage = 4
	# La señal se emite antes de que Player cambie el padre a HoldPoint.
	# El tween comienza en diferido; el objeto ya estará en las manos.
	_start_unwrap.call_deferred()


func _prepare_garland() -> void:
	cable_root = Node3D.new()
	cable_root.name = "AnimatedCable"
	decoration.add_child(cable_root)
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.035, 0.16, 0.06)
	wire_mat.roughness = 0.9
	var wire_mesh := CylinderMesh.new()
	wire_mesh.top_radius = 0.009
	wire_mesh.bottom_radius = 0.009
	wire_mesh.height = 1.0
	wire_mesh.radial_segments = 6
	wire_mesh.rings = 1
	wire_mesh.material = wire_mat
	for bulb_id in BULB_ORDER:
		var bulb := decoration.get_node("Bulb%d" % bulb_id) as MeshInstance3D
		if not path_points.is_empty():
			total_length += path_points[-1].distance_to(bulb.position)
		bulbs.append(bulb)
		path_points.append(bulb.position)
		path_offsets.append(total_length)
		var segment := MeshInstance3D.new()
		segment.mesh = wire_mesh
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cable_root.add_child(segment)
		cable_segments.append(segment)


func _set_portable_coil(value: bool) -> void:
	for child in powered.get_children():
		if child is MeshInstance3D:
			var visual := child as MeshInstance3D
			if String(visual.name).begins_with("Bulb") or String(visual.name).begins_with("Cable"):
				visual.visible = value


func _start_unwrap() -> void:
	if not is_instance_valid(powered) or not is_inside_tree():
		return
	var animation := create_tween()
	animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_method(_animate_unwrap, 0.0, 1.0, maxf(0.1, unwrap_duration))
	animation.tween_callback(_finish_unwrap)


func _sample_path(distance: float) -> Vector3:
	var d := clampf(distance, 0.0, total_length)
	for i in range(1, path_points.size()):
		if d <= path_offsets[i]:
			var segment_length := path_offsets[i] - path_offsets[i - 1]
			var fraction := (d - path_offsets[i - 1]) / maxf(segment_length, 0.0001)
			return path_points[i - 1].lerp(path_points[i], fraction)
	return path_points[-1]


func _animate_unwrap(progress: float) -> void:
	if not is_instance_valid(powered):
		decoration.hide()
		return
	# Las bombillas recorren el trazado original hacia el extremo
	# de recogida. Después se reúnen, una a una, en la batería portátil.
	var gather_distance: float = 0.48
	var travel: float = progress * (total_length + gather_distance)
	for i in range(bulbs.size()):
		var remaining: float = path_offsets[i] - travel
		var bulb := bulbs[i]
		if remaining >= 0.0:
			bulb.position = _sample_path(remaining)
			bulb.scale = Vector3.ONE
		else:
			var target := powered.get_node("Bulb%d" % BULB_ORDER[i]) as MeshInstance3D
			var hand_position := decoration.to_local(target.global_position)
			var blend := smoothstep(0.0, 1.0, clampf(-remaining / gather_distance, 0.0, 1.0))
			bulb.position = path_points[0].lerp(hand_position, blend)
			bulb.scale = Vector3.ONE * lerpf(1.0, 0.020 / 0.033, blend)
	_update_cable()


func _update_cable() -> void:
	if not is_instance_valid(powered):
		return
	var previous := decoration.to_local(powered.to_global(Vector3(0.0, 0.075, 0.0)))
	for i in range(bulbs.size()):
		var next := bulbs[i].position
		var delta := next - previous
		var length := delta.length()
		var segment := cable_segments[i]
		segment.visible = length > 0.0001
		if segment.visible:
			var orientation := Basis(Quaternion(Vector3.UP, delta / length))
			var stretch := Basis.from_scale(Vector3(1.0, length, 1.0))
			segment.transform = Transform3D(orientation * stretch, (previous + next) * 0.5)
		previous = next


func _finish_unwrap() -> void:
	decoration.hide()
	if is_instance_valid(powered):
		_set_portable_coil(true)
