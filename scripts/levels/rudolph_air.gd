extends Node3D
## Phase two: alternating locked pulse and sweep, interruptible nose, dive and jumping shockwave.
signal laser_hit
signal dive_hit
signal warning_sound(at: Vector3)
signal impact_sound(at: Vector3)
signal cover_hit(body: Object)
signal laser_fired(at: Vector3)
enum Stage { TAKEOFF, PATROL, AIM, LASER, REST, DIVE_WARNING, DIVE, LANDED, RISE, INTERRUPTED }
var deer: CharacterBody3D
var player: CharacterBody3D
var running: bool = false
var enraged: bool = false
var stage: int = Stage.TAKEOFF
var clock: float = 0.0
var orbit: float = 0.0
var aim: Vector3 = Vector3.ZERO
var landing: Vector3 = Vector3.ZERO
var dive_start: Vector3 = Vector3.ZERO
var beam: MeshInstance3D
var beam_core: MeshInstance3D
var beam_core_mat: StandardMaterial3D
var ring: MeshInstance3D
var wave: MeshInstance3D
var beam_mat: StandardMaterial3D
var ring_mat: StandardMaterial3D
var nose: MeshInstance3D
var nose_mat: StandardMaterial3D
var sweep: bool = false
var next_sweep: bool = false
var laser_duration: float = 0.19
var laser_covered: Dictionary = {}
var wave_live: bool = false
var wave_radius: float = 0.0
var wave_hit: bool = false
const RADIUS: float = 1.6
const ALTITUDE: float = 3.0
const WAVE_MAX: float = 4.2
const WAVE_SPEED: float = 4.0
const LASER_WARNING: float = 1.35
const DIVE_WARNING: float = 1.45
const LANDED_RECOVERY: float = 2.20

func _ready() -> void:
	beam_mat = _glow(Color(1.0, 0.04, 0.06, 0.55))
	beam = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	beam.mesh = box
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.hide()
	beam_core = MeshInstance3D.new()
	beam_core.mesh = box
	beam_core_mat = _glow(Color(1.0, 0.84, 0.78, 1.0))
	beam_core.material_override = beam_core_mat
	beam_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam_core)
	beam_core.hide()
	ring_mat = _glow(Color(1.0, 0.16, 0.08, 0.65))
	ring = _make_ring(RADIUS, ring_mat)
	wave = _make_ring(1.0, _glow(Color(0.78, 0.92, 1.0, 0.85)))

func _make_ring(radius: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.055
	torus.outer_radius = radius
	torus.rings = 40
	torus.ring_segments = 6
	mesh.mesh = torus
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.hide()
	return mesh

func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m

func prepare_intro() -> void:
	var visual := deer.get("visual") as Node3D
	nose = visual.get_node("RedNose") as MeshInstance3D
	nose_mat = nose.material_override as StandardMaterial3D
	deer.collision_layer = 0
	deer.collision_mask = 0

func set_intro_glow(strength: float) -> void:
	_set_nose(strength)

func preview_beam(target: Vector3, fire: bool) -> void:
	# No collision or damage signal in the cinematic.
	_draw_beam(nose.global_position, target, fire)

func end_preview() -> void:
	_hide_beam()
	_set_nose(1.0)

func begin_after_intro() -> void:
	begin()
	stage = Stage.PATROL
	clock = 3.5

func begin() -> void:
	deer.call("stop_fight")
	prepare_intro()
	deer.collision_layer = 1
	deer.collision_mask = 0
	stage = Stage.TAKEOFF
	clock = 1.25
	running = true
	deer.set("cinematic_running", true)
	deer.set("flight_pose", 1.0)

func halt() -> void:
	running = false
	_hide_beam()
	ring.hide()
	wave.hide()
	wave_live = false
	if is_instance_valid(deer):
		deer.call("stop_fight")

func warning_text() -> String:
	if stage == Stage.AIM:
		return "Rudolph: aim at the glowing nose!"
	if stage == Stage.LASER and sweep:
		return "Rudolph: sweeping laser! Take cover!"
	if stage in [Stage.DIVE_WARNING, Stage.DIVE]:
		return "Rudolph: dive! Leave the circle!"
	if wave_live:
		return "Rudolph: jump over the shockwave!"
	if stage == Stage.INTERRUPTED:
		return "Rudolph interrupted!"
	return "Avoid the laser and dive"

func hit_weak_point(at: Vector3) -> bool:
	# Impact must be on the front of the physical hitbox adjacent to the actual nose.
	if not running or stage != Stage.AIM or not is_instance_valid(nose):
		return false
	if at.distance_to(nose.global_position) > 0.38:
		return false
	stage = Stage.INTERRUPTED
	clock = 1.65
	_hide_beam()
	_set_nose(1.0)
	return true

func _set_nose(strength: float) -> void:
	if is_instance_valid(nose_mat):
		nose_mat.emission_energy_multiplier = strength

func _physics_process(delta: float) -> void:
	if not running or not is_instance_valid(deer) or not is_instance_valid(player):
		return
	_tick_wave(delta)
	if not running:
		return
	clock -= delta
	match stage:
		Stage.TAKEOFF:
			deer.global_position.y = move_toward(deer.global_position.y, ALTITUDE, delta * 3.2)
			deer.call("face", player.global_position)
			if clock <= 0.0:
				stage = Stage.PATROL
				clock = 3.5
		Stage.PATROL:
			orbit += delta * (1.12 if enraged else 0.85)
			var desired := Vector3(cos(orbit) * 2.6, ALTITUDE + sin(orbit * 2.0) * 0.25, 1.0 + sin(orbit) * 2.4)
			deer.global_position = deer.global_position.move_toward(desired, delta * (2.8 if enraged else 2.2))
			deer.call("face", player.global_position)
			if clock <= 0.0:
				stage = Stage.AIM
				clock = LASER_WARNING
				sweep = next_sweep
				next_sweep = not next_sweep
				aim = player.global_position + Vector3.UP * 0.53
				laser_covered.clear()
				warning_sound.emit(nose.global_position)
				_trace(false, -0.60 if sweep else 0.0)
		Stage.AIM:
			_set_nose(2.5 + 2.5 * (1.0 - clampf(clock / LASER_WARNING, 0.0, 1.0)))
			_trace(false, -0.60 if sweep else 0.0)
			if clock <= 0.0:
				stage = Stage.LASER
				laser_duration = (0.95 if enraged else 1.35) if sweep else 0.19
				clock = laser_duration
				laser_fired.emit(nose.global_position)
				_trace(true, -0.60 if sweep else 0.0)
		Stage.LASER:
			if sweep:
				var progress := clampf(1.0 - clock / laser_duration, 0.0, 1.0)
				_trace(true, lerpf(-0.60, 0.60, progress))
			else:
				# The visible pulse remains dangerous for its entire duration.
				_trace(true, 0.0)
			if not running:
				return
			if clock <= 0.0:
				_hide_beam()
				_set_nose(1.0)
				stage = Stage.REST
				clock = 0.75 if enraged else 1.1
		Stage.INTERRUPTED:
			if clock <= 0.0:
				stage = Stage.REST
				clock = 0.5
		Stage.REST:
			deer.call("face", player.global_position)
			if clock <= 0.0:
				landing = player.global_position
				landing.y = 0.0
				dive_start = deer.global_position
				stage = Stage.DIVE_WARNING
				clock = DIVE_WARNING
				ring.global_position = landing + Vector3.UP * 0.035
				ring.show()
				warning_sound.emit(deer.global_position)
		Stage.DIVE_WARNING:
			deer.call("face", landing)
			if clock <= 0.0:
				stage = Stage.DIVE
				deer.set("flight_pose", 2.0)
				clock = 0.52
		Stage.DIVE:
			var t := clampf(1.0 - clock / 0.52, 0.0, 1.0)
			deer.global_position = dive_start.lerp(landing + Vector3.UP * 0.18, t * t)
			if clock <= 0.0:
				ring.hide()
				impact_sound.emit(landing)
				var gap: Vector3 = player.global_position - landing
				wave_hit = Vector2(gap.x, gap.z).length() <= RADIUS and gap.y < 1.0
				if wave_hit:
					dive_hit.emit()
				if not running:
					return
				wave_live = true
				wave_radius = RADIUS
				wave.global_position = landing + Vector3.UP * 0.065
				wave.scale = Vector3(wave_radius, 1.0, wave_radius)
				wave.show()
				stage = Stage.LANDED
				deer.set("flight_pose", 3.0)
				clock = LANDED_RECOVERY
		Stage.LANDED:
			if clock <= 0.0:
				stage = Stage.RISE
				deer.set("flight_pose", 1.0)
				clock = 1.1
		Stage.RISE:
			deer.global_position.y = move_toward(deer.global_position.y, ALTITUDE, delta * 3.0)
			if clock <= 0.0:
				stage = Stage.PATROL
				clock = 1.65 if enraged else 2.15

func _tick_wave(delta: float) -> void:
	if not wave_live:
		return
	var previous: float = wave_radius
	wave_radius = minf(WAVE_MAX, wave_radius + delta * WAVE_SPEED)
	wave.scale = Vector3(wave_radius, 1.0, wave_radius)
	var gap: Vector3 = player.global_position - landing
	var distance := Vector2(gap.x, gap.z).length()
	if not wave_hit and distance >= previous - 0.22 and distance <= wave_radius + 0.22 and gap.y < 0.32:
		wave_hit = true
		dive_hit.emit()
	if wave_radius >= WAVE_MAX or not running:
		wave.hide()
		wave_live = false

func _trace(fire: bool, angle: float) -> void:
	var flat: Vector3 = aim - deer.global_position
	flat.y = 0.0
	var target: Vector3 = deer.global_position + flat.rotated(Vector3.UP, angle)
	target.y = aim.y
	deer.call("face", target)
	var start: Vector3 = nose.global_position
	var direction := (target - start).normalized()
	if direction.length_squared() < 0.001:
		return
	var end := start + direction * 24.0
	var query := PhysicsRayQueryParameters3D.create(start, end, 1, [deer.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"]
	_draw_beam(start, end, fire)
	if fire and not hit.is_empty():
		var body: Object = hit.get("collider")
		if body == player:
			laser_hit.emit()
		elif body is StaticBody3D and not laser_covered.has(body):
			laser_covered[body] = true
			cover_hit.emit(body)

func _hide_beam() -> void:
	beam.hide()
	beam_core.hide()

func _draw_beam(start: Vector3, end: Vector3, fire: bool) -> void:
	var length: float = start.distance_to(end)
	if length < 0.01:
		_hide_beam()
		return
	var direction: Vector3 = (end - start).normalized()
	beam.global_position = (start + end) * 0.5
	beam.look_at(end, Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT)
	beam.scale = Vector3(0.15 if fire else 0.022, 0.15 if fire else 0.022, length)
	beam_mat.albedo_color = Color(1.0, 0.035, 0.06, 0.65) if fire else Color(1.0, 0.06, 0.10, 0.48)
	beam.show()
	beam_core.visible = fire
	if fire:
		beam_core.global_transform = beam.global_transform
		beam_core.scale = Vector3(0.045, 0.045, length)
