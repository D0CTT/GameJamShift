extends CharacterBody3D
## Rudolph: embestidas telegrafiadas, con colisión barrida y muerte por contacto.
signal player_touched
const ART = preload("res://scenes/art/characters/reindeer.tscn")
const BELL = preload("res://assets/audio/forest_sleigh_bell.wav")
enum State { REST, AIM, CHARGE }
@export var charge_speed: float = 7.0
@export var warning_time: float = 1.0
@export var recovery_time: float = 2.0
@export var charge_duration: float = 1.15
var player: CharacterBody3D
var visual: Node3D
var hit_shape: CollisionShape3D
var warning: AudioStreamPlayer3D
var nose: StandardMaterial3D
var state: State = State.REST
var clock: float = 0.0
var running: bool = false
var cinematic_running: bool = false
var stride: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var touched: bool = false
var touch_box: BoxShape3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	visual = ART.instantiate() as Node3D
	add_child(visual)
	visual.get_node("Nose").hide()
	var red_nose := visual.get_node("RedNose") as MeshInstance3D
	red_nose.show()
	nose = red_nose.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	red_nose.material_override = nose
	nose.emission_enabled = true
	nose.emission_energy_multiplier = 1.0
	var box := BoxShape3D.new()
	box.size = Vector3(0.50, 1.18, 1.65)
	hit_shape = CollisionShape3D.new()
	hit_shape.shape = box
	hit_shape.position = Vector3(0, 0.75, -0.24)
	add_child(hit_shape)
	touch_box = BoxShape3D.new()
	touch_box.size = box.size + Vector3(0.10, 0.08, 0.10)
	warning = AudioStreamPlayer3D.new()
	warning.stream = BELL
	warning.unit_size = 3.0
	warning.max_distance = 20.0
	warning.volume_db = -3.0
	add_child(warning)

func face(target: Vector3) -> void:
	var flat := target - global_position
	flat.y = 0.0
	if flat.length_squared() > 0.001:
		rotation.y = atan2(-flat.x, -flat.z)

func start_fight() -> void:
	cinematic_running = false
	collision_layer = 1
	collision_mask = 1
	state = State.REST
	clock = recovery_time
	running = true
	touched = false

func stop_fight() -> void:
	running = false
	cinematic_running = false
	warning.stop()
	_reset_pose()

func _physics_process(delta: float) -> void:
	if cinematic_running:
		_gallop(delta)
		return
	if not running or not is_instance_valid(player):
		return
	if _touching_player():
		_hit_player()
		return
	clock -= delta
	var toward := player.global_position - global_position
	toward.y = 0.0
	match state:
		State.REST:
			# Reposition slowly if the elf is far away or cover blocks the charge.
			if toward.length() > 3.2:
				var path := _steer(toward.normalized(), delta)
				if path.length_squared() > 0.01:
					face(global_position + path)
					_move(path * 1.7 * delta)
					_gallop(delta * 0.42)
				else:
					_reset_pose()
			else:
				_reset_pose()
			if clock <= 0.0 and not touched:
				state = State.AIM
				clock = maxf(0.25, warning_time)
				warning.play()
		State.AIM:
			# Lock the direction on the last frame, then no homing during charge.
			face(player.global_position)
			visual.rotation.x = -0.12
			nose.emission_energy_multiplier = 1.8 + 1.5 * (1.0 - clampf(clock / maxf(0.25, warning_time), 0.0, 1.0))
			if clock <= 0.0:
				direction = -global_transform.basis.z.normalized()
				direction.y = 0.0
				state = State.CHARGE
				clock = charge_duration
		State.CHARGE:
			_gallop(delta)
			if _move(direction * charge_speed * delta) or clock <= 0.0:
				state = State.REST
				clock = recovery_time
				_reset_pose()
	if not touched and _touching_player():
		_hit_player()

func _steer(desired: Vector3, delta: float) -> Vector3:
	# Short shape tests, not a navmesh: choose an open direction around rocks.
	for angle in [0.0, 0.75, -0.75, 1.4, -1.4, 2.1, -2.1]:
		var step := desired.rotated(Vector3.UP, float(angle))
		var pose := Transform3D(Basis(Vector3.UP, atan2(-step.x, -step.z)), global_position)
		if not test_move(pose, step * maxf(0.30, 1.7 * delta)):
			return step
	return Vector3.ZERO

func _move(motion: Vector3) -> bool:
	var hit := move_and_collide(motion)
	if hit == null:
		return false
	if hit.get_collider() == player:
		_hit_player()
	return true

func _touching_player() -> bool:
	# Slightly expanded body catches the elf walking into Rudolph too.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = touch_box
	query.transform = hit_shape.global_transform
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		if result.get("collider") == player:
			return true
	return false

func _hit_player() -> void:
	if touched or not running:
		return
	touched = true
	stop_fight()
	player_touched.emit()

func _gallop(delta: float) -> void:
	stride += delta * 17.0
	visual.position.y = 0.035 + absf(sin(stride)) * 0.065
	visual.rotation.x = sin(stride * 2.0) * 0.055
	for side in range(2):
		for leg in range(2):
			var pivot := visual.get_node("Leg%d%d" % [side, leg]) as Node3D
			pivot.rotation.x = sin(stride + PI * float(side + leg)) * 0.65

func _reset_pose() -> void:
	visual.position.y = 0.0
	visual.rotation.x = 0.0
	nose.emission_energy_multiplier = 1.0
	for side in range(2):
		for leg in range(2):
			var pivot := visual.get_node("Leg%d%d" % [side, leg]) as Node3D
			pivot.rotation.x = 0.0
