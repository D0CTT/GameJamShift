extends Node3D
## Intro del nivel 1. Envuelve el prototipo 05 sin modificar sus escenas.
signal intro_finished

@export var play_intro := true
@onready var player: CharacterBody3D = $Level/Clearing/Player
@onready var head: Node3D = $Level/Clearing/Player/Head
@onready var camera: Camera3D = $Level/Clearing/Player/Head/Camera3D
@onready var hud: CanvasLayer = $Level/Clearing/Player/HUD
@onready var clearing: Node3D = $Level/Clearing
@onready var shade: ColorRect = $IntroOverlay/Fade
@onready var props: Node3D = $IntroProps
@onready var bells: AudioStreamPlayer3D = $EscapeBells

var hands: Node3D
var left_hand: Node3D
var right_hand: Node3D
var rudolph_nose: MeshInstance3D
var nose_mat: StandardMaterial3D
var runners: Array[Node3D] = []
var bag: Node3D
var elapsed := 0.0
var coat: StandardMaterial3D
var skin: StandardMaterial3D
var cream: StandardMaterial3D
var green: StandardMaterial3D
var dark: StandardMaterial3D
var brown: StandardMaterial3D
var antler: StandardMaterial3D

func _ready() -> void:
	_build_props()
	_build_hands()
	if play_intro:
		player.call("set_controls_enabled", false)
		hud.hide()
		shade.color.a = 1.0
		camera.position.y = -0.56
		camera.rotation.z = deg_to_rad(12.0)
		player.rotation.y = 0.0
		head.rotation.x = deg_to_rad(12.0)
		_run_intro.call_deferred()
	else:
		shade.hide()
		hands.hide()
		for runner in runners:
			runner.hide()

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(rudolph_nose):
		nose_mat.emission_energy_multiplier = 0.15 + 2.5 * pow(0.5 + 0.5 * sin(elapsed * 4.0), 3.0)

func _run_intro() -> void:
	# Despertar a ras de suelo, fundido y recuperación de altura.
	var wake := create_tween().set_parallel(true)
	wake.tween_property(shade, "color:a", 0.0, 1.3)
	wake.tween_property(camera, "position:y", -0.19, 1.5).set_trans(Tween.TRANS_SINE)
	wake.tween_property(camera, "rotation:z", 0.0, 1.5)
	await wake.finished
	# Mira las manos rojas brillantes.
	hands.show()
	var look_hands := create_tween().set_parallel(true)
	look_hands.tween_property(head, "rotation:x", -0.52, 0.7)
	look_hands.tween_property(left_hand, "position:y", -0.22, 0.7)
	look_hands.tween_property(right_hand, "position:y", -0.22, 0.7)
	look_hands.tween_property(camera, "position:y", 0.0, 0.7)
	await look_hands.finished
	await get_tree().create_timer(0.85, false).timeout
	var lower := create_tween().set_parallel(true)
	lower.tween_property(left_hand, "position:y", -0.65, 0.45)
	lower.tween_property(right_hand, "position:y", -0.65, 0.45)
	await lower.finished
	hands.hide()
	# Renos escapando a la derecha del claro.
	await _look_at_point(Vector3(3.0, 0.9, -0.5), 0.65)
	bells.position = runners[0].position
	bells.play()
	var escape := create_tween().set_parallel(true)
	for i in range(runners.size()):
		var runner := runners[i]
		var endpoint := runner.position + Vector3(10.0, 0.0, -1.1 - i * 0.35)
		escape.tween_property(runner, "position", endpoint, 1.4 + i * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	escape.tween_property(bells, "position", Vector3(13.0, 0.7, -1.8), 1.8)
	await escape.finished
	for runner in runners:
		runner.hide()
	# Rudolph y los elfos abatidos, luego Santa sobre el trineo.
	await _look_at_point(Vector3(2.7, 0.35, -0.9), 0.85)
	await get_tree().create_timer(0.85, false).timeout
	await _look_at_point(Vector3(-1.7, 0.35, 1.1), 0.85)
	await get_tree().create_timer(0.75, false).timeout
	await _look_at_point(Vector3(-3.4, 0.72, 0.6), 0.9)
	await get_tree().create_timer(1.2, false).timeout
	# El saco en la cima es el último punto de atención.
	await _look_at_point(bag.global_position, 1.25)
	await get_tree().create_timer(1.3, false).timeout
	# Restablecer exactamente la pose de juego, sin sustituir al Player.
	var settle := create_tween().set_parallel(true)
	settle.tween_property(head, "rotation:x", 0.0, 0.55)
	settle.tween_property(player, "rotation:y", _nearest_yaw(0.0), 0.55)
	await settle.finished
	player.rotation.y = 0.0
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	hud.show()
	shade.hide()
	player.call("set_controls_enabled", true)
	intro_finished.emit()

func _nearest_yaw(target: float) -> float:
	return player.rotation.y + wrapf(target - player.rotation.y, -PI, PI)

func _look_at_point(point: Vector3, duration: float) -> void:
	var direction := point - camera.global_position
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
	var t := create_tween().set_parallel(true)
	t.tween_property(player, "rotation:y", _nearest_yaw(yaw), duration).set_trans(Tween.TRANS_SINE)
	t.tween_property(head, "rotation:x", clampf(pitch, -1.4, 1.4), duration).set_trans(Tween.TRANS_SINE)
	await t.finished

func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _group(parent: Node3D, label: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = label
	parent.add_child(n)
	n.position = pos
	return n

func _mesh(parent: Node3D, pos: Vector3, mesh: Mesh, mat: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	n.scale = scale_value
	return n

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, pos, mesh, mat)

func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	return _mesh(parent, pos, mesh, mat, stretch)

func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	return _mesh(parent, pos, mesh, mat)

func _build_hands() -> void:
	hands = _group(camera, "IntroHands", Vector3.ZERO)
	left_hand = _group(hands, "LeftHand", Vector3(-0.25, -0.65, -0.52))
	right_hand = _group(hands, "RightHand", Vector3(0.25, -0.65, -0.52))
	for hand in [left_hand, right_hand]:
		var h := hand as Node3D
		_box(h, Vector3(0, -0.105, 0.10), Vector3(0.115, 0.18, 0.22), green).rotation_degrees.x = -28
		_sphere(h, Vector3.ZERO, 0.078, skin, Vector3(0.9, 0.65, 1.15))
		for i in range(4):
			_sphere(h, Vector3(-0.045 + i * 0.027, 0.005, -0.075), 0.023, skin, Vector3(0.8, 0.85, 1.65))
		var side := 1.0 if h == left_hand else -1.0
		_sphere(h, Vector3(side * 0.075, 0.01, -0.02), 0.032, skin)
	hands.hide()

func _build_props() -> void:
	coat = _mat(Color(0.56, 0.055, 0.06))
	skin = _mat(Color(0.72, 0.055, 0.055), 0.20)
	skin.metallic = 0.15
	cream = _mat(Color(0.89, 0.88, 0.80))
	green = _mat(Color(0.12, 0.31, 0.13))
	dark = _mat(Color(0.065, 0.05, 0.045))
	brown = _mat(Color(0.38, 0.22, 0.12))
	antler = _mat(Color(0.65, 0.52, 0.36))
	var sleigh := clearing.get_node("Sleigh") as Node3D
	(sleigh.get_node("SantaPlaceholder") as MeshInstance3D).hide()
	# Santa tumbado sobre el trineo; no se toca el nodo recogible SantaLights.
	var santa := _group(sleigh, "SantaIntroModel", Vector3(0, 0.30, 0))
	santa.rotation_degrees.z = -90
	_sphere(santa, Vector3(0, 0.02, 0), 0.33, coat, Vector3(0.93, 1.6, 0.83))
	_box(santa, Vector3(0, -0.19, 0), Vector3(0.58, 0.12, 0.48), dark)
	_sphere(santa, Vector3(0, 0.48, 0), 0.21, cream, Vector3(0.93, 1.0, 1.05))
	_sphere(santa, Vector3(0, 0.53, 0.10), 0.16, _mat(Color(0.75, 0.49, 0.32)))
	_cone(santa, Vector3(0, 0.77, 0), 0.19, 0.30, coat)
	_sphere(santa, Vector3(0, 0.92, 0), 0.06, cream)
	for s in [-1, 1]:
		_box(santa, Vector3(s * 0.14, -0.52, 0), Vector3(0.21, 0.50, 0.23), coat)
		_box(santa, Vector3(s * 0.14, -0.79, 0.04), Vector3(0.24, 0.19, 0.32), dark)
		_box(santa, Vector3(s * 0.36, 0.02, 0), Vector3(0.16, 0.46, 0.18), coat).rotation_degrees.z = s * 20
	# Otros elfos abatidos, decorativos para no bloquear la recogida.
	for i in range(3):
		var positions := [Vector3(-1.7, 0.12, 1.1), Vector3(1.45, 0.12, -2.35), Vector3(-3.85, 0.12, -1.95)]
		var elf := _group(props, "FallenElf%d" % i, positions[i])
		elf.rotation_degrees = Vector3(90, i * 37.0, 0)
		_box(elf, Vector3(0, 0.04, 0), Vector3(0.27, 0.36, 0.20), green)
		_sphere(elf, Vector3(0, 0.32, 0), 0.13, _mat(Color(0.44, 0.66, 0.30)))
		_cone(elf, Vector3(0, 0.50, 0), 0.12, 0.26, coat)
		for s in [-1, 1]:
			_box(elf, Vector3(s * 0.09, -0.29, 0), Vector3(0.10, 0.28, 0.11), dark)
			_box(elf, Vector3(s * 0.20, 0.04, 0), Vector3(0.09, 0.30, 0.11), green).rotation_degrees.z = s * 35
	var rudolph := _reindeer("Rudolph", Vector3(2.65, 0.23, -0.9), true)
	rudolph.rotation_degrees.y = 145.0
	for i in range(3):
		var deer := _reindeer("EscapingReindeer%d" % i, Vector3(1.8 + i * 0.65, 0, -0.4 - i * 0.7), false)
		deer.rotation_degrees.y = -90.0
		runners.append(deer)
	# Hito montañoso lejano, solo visual; no altera la navegación del bosque.
	var mountain := _group(props, "DistantMountain", Vector3(0, 0, -53))
	_cone(mountain, Vector3(0, 7.0, 0), 12.0, 14.0, _mat(Color(0.36, 0.47, 0.56)))
	_cone(mountain, Vector3(0, 11.7, 0), 4.0, 4.6, cream)
	bag = _group(mountain, "GiftBag", Vector3(0, 14.5, 0.1))
	_sphere(bag, Vector3.ZERO, 0.72, coat, Vector3(1, 0.87, 0.8))
	_box(bag, Vector3(0, 0.55, 0), Vector3(0.48, 0.10, 0.42), cream)
	_cone(bag, Vector3(0, 0.83, 0), 0.26, 0.42, coat).rotation_degrees.z = 180

func _reindeer(label: String, pos: Vector3, fallen: bool) -> Node3D:
	var deer := _group(props, label, pos)
	var height := 0.0 if fallen else 0.78
	_sphere(deer, Vector3(0, height, 0), 0.32, brown, Vector3(0.72, 0.78, 1.8))
	_sphere(deer, Vector3(0, height + 0.22, -0.43), 0.16, brown, Vector3(0.95, 1.5, 0.95))
	_sphere(deer, Vector3(0, height + 0.42, -0.60), 0.19, brown, Vector3(0.75, 0.8, 1.20))
	for side in [-1, 1]:
		_box(deer, Vector3(side * 0.10, height + 0.66, -0.58), Vector3(0.045, 0.32, 0.045), antler).rotation_degrees.z = -side * 22
		_box(deer, Vector3(side * 0.16, height + 0.75, -0.58), Vector3(0.045, 0.14, 0.17), antler).rotation_degrees.x = -40
		_sphere(deer, Vector3(side * 0.12, height + 0.46, -0.66), 0.025, dark)
		for z in [-0.29, 0.33]:
			var leg := _box(deer, Vector3(side * 0.16, 0.34 if not fallen else 0.02, z), Vector3(0.09, 0.68 if not fallen else 0.38, 0.10), brown)
			if fallen:
				leg.rotation_degrees.z = side * 75.0
	if fallen:
		nose_mat = _mat(Color(0.83, 0.025, 0.015), 0.35)
		nose_mat.emission_enabled = true
		nose_mat.emission = Color(1.0, 0.025, 0.01)
		rudolph_nose = _sphere(deer, Vector3(0, height + 0.37, -0.83), 0.087, nose_mat)
	else:
		_sphere(deer, Vector3(0, height + 0.37, -0.83), 0.067, dark)
	return deer
