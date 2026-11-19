extends Node3D
## A separate, live 3D cinematic for the main menu. Never modifies gameplay scenes.
const SLEIGH = preload("res://scenes/art/level_01/sleigh_visual.tscn")
const SANTA = preload("res://scenes/art/characters/santa_seated.tscn")
const ELF = preload("res://scenes/art/characters/fallen_elf.tscn")
const DEER = preload("res://scenes/art/characters/reindeer.tscn")
const PINE = preload("res://scenes/art/level_01/snow_pine.tscn")
const TILE_LENGTH: float = 36.0
const TILE_COUNT: int = 5
@export var flight_speed: float = 6.0
var flight: Node3D
var carriage: Node3D
var camera: Camera3D
var sky_group: Node3D
var terrain_tiles: Array[Node3D] = []
var deer: Array[Node3D] = []
var elves: Array[Node3D] = []
var reins: Array[MeshInstance3D] = []
var santa: Node3D
var clock: float = 0.0
var distance: float = 0.0
var rope_mat: StandardMaterial3D

func _ready() -> void:
	_build_world()
	_build_flight()
	_build_landscape()
	_build_sky()
	_update_flight(0.0)

func _group(parent: Node3D, label: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = label
	parent.add_child(n)
	n.position = at
	return n

func _mat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _mesh(parent: Node3D, at: Vector3, geo: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = geo
	n.material_override = mat
	parent.add_child(n)
	n.position = at
	return n

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, at, mesh, mat)

func _sphere(parent: Node3D, at: Vector3, radius: float, mat: Material, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var n := _mesh(parent, at, mesh, mat)
	n.scale = stretch
	return n

func _instance(scene: PackedScene, parent: Node3D, at: Vector3, label: String) -> Node3D:
	var n := scene.instantiate() as Node3D
	n.name = label
	parent.add_child(n)
	n.position = at
	return n

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.027, 0.048, 0.085)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.64, 0.74, 0.94)
	environment.ambient_light_energy = 0.48
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon_light := DirectionalLight3D.new()
	add_child(moon_light)
	moon_light.rotation_degrees = Vector3(-22, -75, 0)
	moon_light.light_color = Color(0.72, 0.82, 1.0)
	moon_light.light_energy = 0.90
	moon_light.shadow_enabled = true
	var fill := DirectionalLight3D.new()
	add_child(fill)
	fill.rotation_degrees = Vector3(-28, 95, 0)
	fill.light_color = Color(0.89, 0.83, 0.76)
	fill.light_energy = 0.42
	camera = Camera3D.new()
	camera.name = "TrackingCamera"
	camera.fov = 47.0
	camera.far = 240.0
	add_child(camera)
	camera.current = true

func _build_flight() -> void:
	flight = _group(self, "FlyingTeam")
	carriage = _group(flight, "SleighBank")
	# Original art faces +Z. Rotate only this instance for the -Z flight.
	var sleigh := _instance(SLEIGH, carriage, Vector3.ZERO, "IntactSleigh")
	sleigh.rotation.y = PI
	sleigh.scale.z = 1.24
	for child in sleigh.get_children():
		if String(child.name).begins_with("Shard") or String(child.name).begins_with("Snow"):
			(child as Node3D).hide()
	# Recreate the missing runner and damaged side using the intact left side.
	var left: Node3D = sleigh.get_node("Left")
	var right: Node3D = sleigh.get_node("Right")
	for child in right.get_children():
		(child as Node3D).hide()
	for child in left.get_children():
		var original := child as MeshInstance3D
		if original == null:
			continue
		var mirror := original.duplicate() as MeshInstance3D
		right.add_child(mirror)
		mirror.position.x = -original.position.x
		mirror.rotation_degrees.y = -original.rotation_degrees.y
		mirror.rotation_degrees.z = -original.rotation_degrees.z
	# Same seated Santa, awake and looking forward; no accident lights or blood.
	santa = _instance(SANTA, sleigh, Vector3(0, 0.52, -0.57), "AwakeSanta")
	var santa_head := santa.get_node("SlumpedHead") as Node3D
	santa_head.rotation_degrees = Vector3(-4, 0, 0)
	var eye_mat := _mat(Color(0.027, 0.022, 0.021))
	for i in range(2):
		var shut := santa_head.get_node("ClosedEye%d" % i) as Node3D
		shut.hide()
		_sphere(santa_head, Vector3(-0.09 if i == 0 else 0.09, 0.074, 0.239), 0.024, eye_mat, Vector3(0.8, 1.0, 0.54))
	# The three elves are the same art as the accident, but standing upright.
	var elf_positions: Array[Vector3] = [Vector3(-0.40, 0.16, 0.30), Vector3(0.39, 0.16, 0.35), Vector3(0, 0.16, 0.88)]
	for i in range(elf_positions.size()):
		var elf := _instance(ELF, sleigh, elf_positions[i], "Elf%d" % i)
		elf.scale = Vector3.ONE * 0.87
		elves.append(elf)
	# Cargo platform and the sack, matching the original mountain landmark geometry.
	var wood := _mat(Color(0.31, 0.13, 0.055))
	var gold := _mat(Color(0.70, 0.43, 0.09))
	var cloth := _mat(Color(0.51, 0.045, 0.055))
	var tie := _mat(Color(0.82, 0.70, 0.44))
	_box(sleigh, Vector3(0, 0.13, -1.60), Vector3(1.26, 0.14, 0.68), wood)
	_box(sleigh, Vector3(0, 0.22, -1.92), Vector3(1.26, 0.10, 0.09), gold)
	var sack := _group(sleigh, "GiftBag", Vector3(0, 0.53, -1.60))
	_sphere(sack, Vector3.ZERO, 0.47, cloth, Vector3(1.07, 0.90, 0.82))
	_box(sack, Vector3(0, 0.35, 0), Vector3(0.30, 0.065, 0.27), tie)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.18
	neck.bottom_radius = 0.08
	neck.height = 0.22
	neck.radial_segments = 7
	_mesh(sack, Vector3(0, 0.49, 0), neck, cloth)
	# Two pairs of reindeer: Rudolph leads on the camera-facing side.
	for row in range(2):
		for side in range(2):
			var animal := _instance(DEER, flight, Vector3(-0.64 if side == 0 else 0.64, -0.28, -2.7 - row * 2.50), "Reindeer%d" % deer.size())
			deer.append(animal)
			if row == 1 and side == 1:
				(animal.get_node("Nose") as Node3D).hide()
				(animal.get_node("RedNose") as Node3D).show()
				var lamp := OmniLight3D.new()
				animal.add_child(lamp)
				lamp.position = Vector3(0, 1.21, -1.02)
				lamp.light_color = Color(1, 0.08, 0.06)
				lamp.light_energy = 0.65
				lamp.omni_range = 1.6
	rope_mat = _mat(Color(0.34, 0.19, 0.075))
	for i in range(4):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.018
		cylinder.bottom_radius = 0.018
		cylinder.height = 1.0
		cylinder.radial_segments = 6
		reins.append(_mesh(flight, Vector3.ZERO, cylinder, rope_mat))

func _build_landscape() -> void:
	var snow := _mat(Color(0.48, 0.59, 0.73))
	var mountain_mat := _mat(Color(0.13, 0.20, 0.31))
	var cap_mat := _mat(Color(0.50, 0.62, 0.78))
	for tile_idx in range(TILE_COUNT):
		var tile := _group(self, "Landscape%d" % tile_idx)
		terrain_tiles.append(tile)
		_box(tile, Vector3(0, -9.8, 0), Vector3(100, 1, TILE_LENGTH + 0.15), snow)
		# Repeat a deterministic layout, no per-frame random changes.
		var rng := RandomNumberGenerator.new()
		rng.seed = 4198
		for i in range(40):
			var x := rng.randf_range(-27.0, 15.0)
			var z := rng.randf_range(-17.0, 17.0)
			var pine := _instance(PINE, tile, Vector3(x, -9.3, z), "Pine%d" % i)
			pine.scale = Vector3.ONE * rng.randf_range(0.85, 1.65)
			pine.rotation.y = rng.randf_range(0, TAU)
		for i in range(4):
			var height := rng.randf_range(10.0, 19.0)
			var peak := CylinderMesh.new()
			peak.top_radius = 0.0
			peak.bottom_radius = rng.randf_range(8.0, 13.0)
			peak.height = height
			peak.radial_segments = 5
			var at := Vector3(-39.0 - float(i % 2) * 6.0, -9.3 + height * 0.5, -14.0 + float(i) * 9.0)
			_mesh(tile, at, peak, mountain_mat)
			var cap := CylinderMesh.new()
			cap.top_radius = 0.0
			cap.bottom_radius = peak.bottom_radius * 0.30 + 0.04
			cap.height = height * 0.30
			cap.radial_segments = 5
			_mesh(tile, at + Vector3.UP * height * 0.35, cap, cap_mat)

func _build_sky() -> void:
	sky_group = _group(self, "DistantSky")
	var moon_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, shadows_disabled;
varying vec3 moon_dir;
void vertex() { moon_dir = normalize(VERTEX); }
void fragment() {
 vec3 p = normalize(moon_dir);
 float marks = 0.0;
 marks += smoothstep(0.91,0.96,dot(p,normalize(vec3(1.0,0.48,-0.38))))*0.15;
 marks += smoothstep(0.95,0.98,dot(p,normalize(vec3(1.0,-0.36,0.22))))*0.18;
 marks += smoothstep(0.93,0.98,dot(p,normalize(vec3(1.0,0.04,0.47))))*0.11;
 marks += smoothstep(0.97,0.99,dot(p,normalize(vec3(1.0,0.54,0.15))))*0.10;
 float texture_noise = sin(p.y*154.0+p.z*65.0)*sin(p.z*122.0)*0.012;
 ALBEDO = vec3(0.78,0.85,0.94) - vec3(marks+texture_noise);
}"""
	moon_mat.shader = shader
	var moon := _sphere(sky_group, Vector3(-92, 12, -33), 16.0, moon_mat)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stars_mat := _mat(Color(0.63, 0.73, 0.88), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 981
	for i in range(95):
		var star := _sphere(sky_group, Vector3(-110, rng.randf_range(-9, 80), rng.randf_range(-100, 90)), rng.randf_range(0.065, 0.19), stars_mat)
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	clock += delta
	distance = fposmod(distance + delta * flight_speed, TILE_LENGTH * 100.0)
	_update_flight(delta)

func _update_flight(_delta: float) -> void:
	flight.position = Vector3(0, 0.13 * sin(clock * 1.2), -distance)
	carriage.rotation.x = 0.045 * sin(clock * 1.35)
	carriage.rotation.z = 0.025 * sin(clock * 0.82)
	for i in range(deer.size()):
		var animal := deer[i]
		var phase: float = clock * 8.0 + float(i) * 0.85
		animal.position.y = -0.28 + sin(phase) * 0.09
		animal.rotation.x = sin(phase) * 0.055
		for side in range(2):
			for leg in range(2):
				var joint := animal.get_node("Leg%d%d" % [side, leg]) as Node3D
				joint.rotation.x = sin(phase + float(leg) * PI + float(side) * 0.8) * 0.62 - 0.12
	for i in range(elves.size()):
		elves[i].rotation.z = 0.055 * sin(clock * 1.5 + float(i))
	var head := santa.get_node("SlumpedHead") as Node3D
	head.rotation.y = 0.075 * sin(clock * 0.9)
	# Lines follow the local animated endpoints and do not change shape randomly.
	for i in range(4):
		var animal := deer[i]
		var a: Vector3 = Vector3(animal.position.x, 0.56, -1.36) if i < 2 else deer[i - 2].position + Vector3(0, 0.84, -0.65)
		var b: Vector3 = animal.position + Vector3(0, 0.90, 0.31)
		var span: Vector3 = b - a
		reins[i].position = (a + b) * 0.5
		reins[i].basis = Basis(Quaternion(Vector3.UP, span.normalized())).scaled_local(Vector3(1, span.length(), 1))
	# Track the sleigh from the side, framing the group on the right of the UI.
	camera.position = flight.position + Vector3(12.4 + 0.38 * sin(clock * 0.25), 3.15 + 0.18 * sin(clock * 0.38), 1.95 + 0.30 * sin(clock * 0.31))
	camera.look_at(flight.position + Vector3(0, 0.88, 1.95), Vector3.UP)
	sky_group.position.z = flight.position.z
	var tile_center: float = floorf(flight.position.z / TILE_LENGTH) * TILE_LENGTH
	for i in range(terrain_tiles.size()):
		terrain_tiles[i].position.z = tile_center + float(i - 2) * TILE_LENGTH
