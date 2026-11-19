extends "res://scripts/components/pickup.gd"
@export var unwrap_duration: float = 1.6
var wrapped: bool = true
var animating: bool = false
var decoration: Node3D
var wrapped_collider: CollisionShape3D
var coil: Array[MeshInstance3D] = []
var bulbs: Array[MeshInstance3D] = []
var segments: Array[MeshInstance3D] = []
var path_points: Array[Vector3] = []
var offsets: Array[float] = []
var total_length: float = 0.0
var animation: Tween
@onready var compact_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	super._ready()
	for i in range(8):
		coil.append(get_node("Bulb%d" % i) as MeshInstance3D)
	var santa := get_parent().get_node_or_null("Sleigh/SantaIntroModel") as Node3D
	if santa == null:
		wrapped = false
		return
	decoration = Node3D.new()
	decoration.name = "WrappedGarland"
	santa.add_child(decoration)
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.035, 0.16, 0.065)
	wire_mat.roughness = 0.9
	var wire_mesh := CylinderMesh.new()
	wire_mesh.top_radius = 0.012
	wire_mesh.bottom_radius = 0.012
	wire_mesh.height = 1.0
	wire_mesh.radial_segments = 6
	wire_mesh.rings = 1
	wire_mesh.material = wire_mat
	for i in range(43):
		var t: float = float(i) / 42.0
		var angle: float = t * TAU * 3.0 + 0.15
		var pos := Vector3(cos(angle) * lerpf(0.59, 0.53, t), lerpf(0.21, 0.67, t), 0.025 + sin(angle) * lerpf(0.43, 0.37, t))
		if not path_points.is_empty():
			total_length += path_points[-1].distance_to(pos)
		path_points.append(pos)
		offsets.append(total_length)
		var bulb := MeshInstance3D.new()
		bulb.mesh = coil[i % coil.size()].mesh
		bulb.position = pos
		decoration.add_child(bulb)
		bulbs.append(bulb)
		var seg := MeshInstance3D.new()
		seg.mesh = wire_mesh
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decoration.add_child(seg)
		segments.append(seg)
	_set_compact(false)
	compact_shape.set_deferred("disabled", true)
	wrapped_collider = CollisionShape3D.new()
	wrapped_collider.name = "WrappedCollider"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.12, 0.55, 0.76)
	wrapped_collider.shape = shape
	add_child(wrapped_collider)
	wrapped_collider.position = Vector3(-0.52, 0.02, 0.0)
	_update_wire(false)

func _set_compact(value: bool) -> void:
	$Cable.visible = value
	for bulb in coil:
		bulb.visible = value

func set_carried() -> void:
	super.set_carried()
	if not wrapped:
		return
	wrapped = false
	animating = true
	if is_instance_valid(wrapped_collider):
		wrapped_collider.set_deferred("disabled", true)
	compact_shape.set_deferred("disabled", false)
	_start_unwrap.call_deferred()

func _start_unwrap() -> void:
	if not animating or not is_instance_valid(decoration) or not is_inside_tree():
		return
	animation = create_tween()
	animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_method(_animate_unwrap, 0.0, 1.0, maxf(0.1, unwrap_duration))
	animation.tween_callback(_finish_unwrap)

func _sample_path(distance: float) -> Vector3:
	var d: float = clampf(distance, 0.0, total_length)
	for i in range(1, path_points.size()):
		if d <= offsets[i]:
			var fraction: float = (d - offsets[i - 1]) / maxf(0.0001, offsets[i] - offsets[i - 1])
			return path_points[i - 1].lerp(path_points[i], fraction)
	return path_points[-1]

func _animate_unwrap(progress: float) -> void:
	if not animating or not is_instance_valid(decoration):
		return
	var gather: float = 0.65
	var travel: float = progress * (total_length + gather)
	for i in range(bulbs.size()):
		var remaining: float = offsets[i] - travel
		if remaining >= 0.0:
			bulbs[i].position = _sample_path(remaining)
		else:
			var target: Vector3 = decoration.to_local(coil[i % coil.size()].global_position)
			var blend: float = smoothstep(0.0, 1.0, clampf(-remaining / gather, 0.0, 1.0))
			bulbs[i].position = path_points[0].lerp(target, blend)
			bulbs[i].scale = Vector3.ONE * lerpf(1.0, 0.9, blend)
	_update_wire(true)

func _update_wire(connect_to_hand: bool) -> void:
	var previous: Vector3 = decoration.to_local(global_position) if connect_to_hand else path_points[0]
	for i in range(bulbs.size()):
		var next: Vector3 = bulbs[i].position
		var delta: Vector3 = next - previous
		var length: float = delta.length()
		segments[i].visible = length > 0.0001
		if length > 0.0001:
			var orientation := Basis(Quaternion(Vector3.UP, delta / length))
			segments[i].transform = Transform3D(orientation * Basis.from_scale(Vector3(1.0, length, 1.0)), (previous + next) * 0.5)
		previous = next

func _finish_unwrap() -> void:
	animating = false
	if is_instance_valid(decoration):
		decoration.hide()
	_set_compact(true)

func _finish_if_needed() -> void:
	if animating:
		if animation != null and animation.is_valid():
			animation.kill()
		_finish_unwrap()

func set_placed() -> void:
	_finish_if_needed()
	super.set_placed()

func set_returned() -> void:
	_finish_if_needed()
	super.set_returned()
