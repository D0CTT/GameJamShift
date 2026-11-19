extends Node3D
## Intro del nivel 1. Envuelve el prototipo 05 sin modificar sus escenas.
signal intro_finished
const ESCAPE_AVALANCHE = preload("res://scripts/levels/escape_avalanche.gd")
var escape_avalanche: ESCAPE_AVALANCHE
const REINDEER_ART = preload("res://scenes/art/characters/reindeer.tscn")
const ELF_ART = preload("res://scenes/art/characters/fallen_elf.tscn")
const HAND = preload("res://scenes/art/player/elf_hand.tscn")
const FINAL_COMBAT = preload("res://scripts/levels/santa_combat.gd")
var final_combat: Node3D
var final_pending: bool = false
# Solo guardamos los indicadores visibles al comenzar la cinemática.
var intro_hidden_previews: Array[MeshInstance3D] = []

@export var play_intro := true
@export_file("*.tscn") var next_level_scene: String = "res://tests/test_level_02_transition.tscn"
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
var reindeer_running := false
# Ruta cinematográfica ajustada al bosque y relieve del nivel 1.
const ESCAPE_SPEED: float = 5.3
const ESCAPE_SPACING: float = 1.75
var escape_curve: Curve3D
var coat: StandardMaterial3D
var skin: StandardMaterial3D
var cream: StandardMaterial3D
var green: StandardMaterial3D
var dark: StandardMaterial3D
var brown: StandardMaterial3D
var antler: StandardMaterial3D

func _ready() -> void:
	$Level.set("integrated_transition", true)
	$Level.connect("forest_completed", _on_forest_completed)
	_build_props()
	escape_avalanche = ESCAPE_AVALANCHE.new()
	escape_avalanche.name = "EscapeAvalanche"
	props.add_child(escape_avalanche)
	escape_avalanche.call("configure", get_node_or_null("Level01Art"))
	_build_hands()
	if play_intro and not LevelManager.travel_busy:
		_hide_intro_previews()
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
		escape_avalanche.call("settle_immediately")

func _physics_process(_delta: float) -> void:
	if final_pending or is_instance_valid(final_combat) or LevelManager.travel_busy:
		return
	if GameState.phase != GameState.Phase.DESCENT or not GameState.level_01_completed:
		return
	# Start only after the elf crosses back into the original crash clearing.
	if player.global_position.z >= -3.8:
		final_pending = true
		_start_final_combat.call_deferred()

func _start_final_combat() -> void:
	if not is_inside_tree():
		return
	GameState.phase = GameState.Phase.COMBAT
	# Keep a non-combat object, if any, in the world rather than deleting it.
	var held := player.get("held_item") as Node3D
	if is_instance_valid(held):
		player.set("held_item", null)
		player.set("pickup_parent", null)
		player.set("drop_requested", false)
		held.reparent(clearing, false)
		held.position = Vector3(4.35, 0.35, 4.2)
		held.rotation = Vector3.ZERO
		held.call("set_returned")
		player.emit_signal("held_item_changed", null)
	GameState.carried_item_id = &""
	player.call("set_controls_enabled", false)
	# Close the forest entrance for the duel; no level changes while fighting.
	var gate := $Level.get("gate") as StaticBody3D
	var gate_shape := $Level.get("gate_shape") as CollisionShape3D
	gate_shape.set_deferred("disabled", false)
	(gate.get_node("MeshInstance3D") as MeshInstance3D).hide()
	$Level.set("gate_open", false)
	$Level/Overlay/Hint.hide()
	var old_santa := clearing.get_node_or_null("Sleigh/SantaIntroModel") as Node3D
	if is_instance_valid(old_santa):
		old_santa.hide()
	_spawn_final_combat()

func _spawn_final_combat(retry: bool = false) -> void:
	player.global_position = Vector3(0.0, 0.05, -3.65)
	player.velocity = Vector3.ZERO
	player.rotation.y = PI
	head.rotation.x = 0.0
	var controller := FINAL_COMBAT.new()
	controller.name = "FinalCombat"
	controller.embedded_player = player
	controller.santa_spawn = Vector3(-2.1, 0.0, 2.0)
	controller.snowman_target = clearing.get_node_or_null("Snowman") as Node3D
	controller.fallen_rudolph = props.get_node_or_null("Rudolph") as Node3D
	controller.play_intro = not retry
	for child_name in ["Arena", "Projectiles"]:
		var child := Node3D.new()
		child.name = child_name
		controller.add_child(child)
	controller.retry_requested.connect(_retry_final_combat)
	final_combat = controller
	add_child(controller)

func _retry_final_combat() -> void:
	# Retry only the duel. Preserve the original level and its objects.
	if not is_instance_valid(final_combat):
		return
	var held := player.get("held_item") as Node3D
	if is_instance_valid(held) and held.get("item_id") == &"combat_snowball":
		player.set("held_item", null)
		player.set("pickup_parent", null)
		player.set("drop_requested", false)
		held.queue_free()
		player.emit_signal("held_item_changed", null)
	var old := final_combat
	final_combat = null
	remove_child(old)
	old.queue_free()
	_spawn_final_combat(true)

func _update_phase_hud() -> void:
	var objective := player.get_node("HUD/Objective") as Label
	var down: bool = GameState.phase == GameState.Phase.DESCENT
	objective.text = "MAKE SHIT CHRISTMAS" if down else "MAKE/SHIFT CHRISTMAS"
	objective.add_theme_color_override("font_color", Color(1.0, 0.23, 0.26) if down else Color.WHITE)

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(rudolph_nose):
		nose_mat.emission_energy_multiplier = 0.25 + 1.35 * pow(0.5 + 0.5 * sin(elapsed * 2.4), 2.0)
	if reindeer_running:
		# Los cascabeles siguen a la manada en lugar de cruzar en recta.
		bells.position = runners[1].position + Vector3.UP * 0.95
		for i in range(runners.size()):
			var visual := runners[i].get_node("Visual") as Node3D
			var stride := elapsed * 15.0 + float(i) * 1.6
			visual.position.y = 0.045 + 0.065 * absf(sin(stride))
			visual.rotation.x = sin(stride * 2.0) * 0.045
			for side in range(2):
				for leg in range(2):
					var pivot := visual.get_node("Leg%d%d" % [side, leg]) as Node3D
					pivot.rotation.x = sin(stride + PI * float(side + leg)) * 0.58

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
	# Huida por el hueco real entre los pinos del lado derecho.
	await _look_at_point(runners[1].global_position + Vector3.UP * 0.9, 0.65)
	bells.position = runners[1].position + Vector3.UP * 0.95
	bells.play()
	reindeer_running = true
	var escape := create_tween().set_parallel(true)
	var route_length := escape_curve.get_baked_length()
	for i in range(runners.size()):
		var runner := runners[i]
		var start_distance := _escape_start_distance(i)
		# Misma velocidad y separación entre individuos; cada uno gira con la ruta.
		escape.tween_method(_place_escape_runner.bind(runner), start_distance, route_length, (route_length - start_distance) / ESCAPE_SPEED).set_trans(Tween.TRANS_LINEAR)
	# La mirada acompaña el principio de la huida hacia el hueco de la arboleda.
	await _look_at_point(Vector3(6.7, 1.0, 6.4), 1.65)
	bells.play()
	await get_tree().create_timer(0.65, false).timeout
	# Mantener la mirada en el paso hasta que caiga la nieve.
	if escape.is_running():
		await escape.finished
	reindeer_running = false
	for runner in runners:
		runner.hide()
	bells.stop()
	# Respaldo si se modifica la duración o el recorrido de la huida.
	if not bool(escape_avalanche.get("started")):
		escape_avalanche.call("play")
	if not bool(escape_avalanche.get("finished")):
		await escape_avalanche.settled
	await get_tree().create_timer(0.40, false).timeout
	await _look_at_point(Vector3(2.7, 0.35, -0.9), 0.85)
	# Rudolph y los elfos abatidos, luego Santa sobre el trineo.
	await get_tree().create_timer(0.85, false).timeout
	await _look_at_point(Vector3(-1.7, 0.35, 1.1), 0.85)
	await get_tree().create_timer(0.75, false).timeout
	await _look_at_point(Vector3(-3.4, 1.25, 0.08), 0.9)
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
	_restore_intro_previews()
	player.call("set_controls_enabled", true)
	intro_finished.emit()

func _hide_intro_previews() -> void:
	intro_hidden_previews.clear()
	var snowman := clearing.get_node_or_null("Snowman") as Node3D
	if snowman == null:
		return
	# Los nodos Slot ya han ejecutado _ready y solo la pieza actual es visible.
	for child in snowman.get_children():
		if child is StaticBody3D and child.has_signal("piece_placed"):
			var preview := child.get_node_or_null("Preview") as MeshInstance3D
			if is_instance_valid(preview) and preview.visible:
				intro_hidden_previews.append(preview)
				preview.hide()

func _restore_intro_previews() -> void:
	for preview in intro_hidden_previews:
		if not is_instance_valid(preview):
			continue
		var slot := preview.get_parent() as StaticBody3D
		# No reactivar un paso ya completado o deshabilitado.
		if is_instance_valid(slot) and slot.collision_layer != 0 and not bool(slot.get("filled")):
			preview.show()
	intro_hidden_previews.clear()

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
	left_hand = HAND.instantiate() as Node3D
	right_hand = HAND.instantiate() as Node3D
	for i in range(2):
		var hand := left_hand if i == 0 else right_hand
		hands.add_child(hand)
		hand.name = "LeftHand" if i == 0 else "RightHand"
		hand.position = Vector3(-0.25 if i == 0 else 0.25, -0.65, -0.52)
		hand.rotation.x = 0.12
		hand.call("configure", i == 1, &"red", 0.12)
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
	# Santa sentado pertenece a la propia escena del accidente.
	for i in range(3):
		var spots := [Vector3(-1.7, 0.14, 1.1), Vector3(1.45, 0.14, -2.35), Vector3(-3.85, 0.14, -1.95)]
		var elf := _group(props, "FallenElf%d" % i, spots[i])
		elf.rotation_degrees.y = i * 37.0
		var pose := _group(elf, "LyingPose", Vector3.ZERO)
		pose.rotation_degrees.x = -90.0
		var visual := ELF_ART.instantiate() as Node3D
		pose.add_child(visual)
		visual.position.y = -0.55
	var rudolph := _reindeer("Rudolph", Vector3(2.65, 0.23, -0.9), true)
	rudolph.rotation_degrees.y = 145.0
	_build_escape_curve()
	for i in range(3):
		var deer := _reindeer("EscapingReindeer%d" % i, Vector3.ZERO, false)
		_place_escape_runner(_escape_start_distance(i), deer)
		runners.append(deer)
	# Hito montañoso lejano, solo visual; no altera la navegación del bosque.
	var mountain := _group(props, "DistantMountain", Vector3(0, 0, -53))
	_cone(mountain, Vector3(0, 7.0, 0), 12.0, 14.0, _mat(Color(0.36, 0.47, 0.56)))
	_cone(mountain, Vector3(0, 11.7, 0), 4.0, 4.6, cream)
	bag = _group(mountain, "GiftBag", Vector3(0, 14.5, 0.1))
	_sphere(bag, Vector3.ZERO, 0.72, coat, Vector3(1, 0.87, 0.8))
	_box(bag, Vector3(0, 0.55, 0), Vector3(0.48, 0.10, 0.42), cream)
	_cone(bag, Vector3(0, 0.83, 0), 0.26, 0.42, coat).rotation_degrees.z = 180

func _build_escape_curve() -> void:
	# Puntos muestreados de una curva suave; alturas obtenidas del terreno OBJ
	# y del montículo que precede al paso. No se modifican los pinos ni sus colisiones.
	escape_curve = Curve3D.new()
	escape_curve.bake_interval = 0.08
	var points: Array[Vector3] = [
		Vector3(3.700, 0.000, 0.350),
		Vector3(3.694, 0.000, 0.570),
		Vector3(3.687, 0.000, 0.790),
		Vector3(3.681, 0.000, 1.010),
		Vector3(3.674, 0.000, 1.230),
		Vector3(3.667, 0.000, 1.450),
		Vector3(3.660, 0.000, 1.669),
		Vector3(3.654, 0.000, 1.889),
		Vector3(3.646, 0.000, 2.109),
		Vector3(3.638, 0.000, 2.329),
		Vector3(3.628, 0.000, 2.549),
		Vector3(3.619, 0.000, 2.769),
		Vector3(3.610, 0.000, 2.988),
		Vector3(3.604, 0.000, 3.208),
		Vector3(3.600, 0.000, 3.428),
		Vector3(3.613, 0.000, 3.648),
		Vector3(3.669, 0.000, 3.860),
		Vector3(3.755, 0.000, 4.062),
		Vector3(3.859, 0.000, 4.256),
		Vector3(3.973, 0.000, 4.444),
		Vector3(4.089, 0.000, 4.631),
		Vector3(4.211, 0.000, 4.814),
		Vector3(4.349, 0.019, 4.986),
		Vector3(4.496, 0.173, 5.149),
		Vector3(4.651, 0.220, 5.306),
		Vector3(4.808, 0.229, 5.460),
		Vector3(4.964, 0.187, 5.615),
		Vector3(5.115, 0.085, 5.775),
		Vector3(5.268, 0.000, 5.932),
		Vector3(5.434, 0.000, 6.077),
		Vector3(5.623, 0.000, 6.189),
		Vector3(5.831, 0.000, 6.259),
		Vector3(6.045, 0.000, 6.312),
		Vector3(6.260, 0.000, 6.354),
		Vector3(6.477, 0.000, 6.391),
		Vector3(6.695, 0.000, 6.425),
		Vector3(6.912, 0.000, 6.460),
		Vector3(7.128, 0.000, 6.498),
		Vector3(7.345, 0.006, 6.537),
		Vector3(7.562, 0.020, 6.575),
		Vector3(7.779, 0.035, 6.607),
		Vector3(7.998, 0.049, 6.632),
		Vector3(8.217, 0.079, 6.647),
		Vector3(8.437, 0.115, 6.649),
		Vector3(8.657, 0.160, 6.643),
		Vector3(8.877, 0.206, 6.632),
		Vector3(9.096, 0.253, 6.617),
		Vector3(9.316, 0.302, 6.600),
		Vector3(9.535, 0.357, 6.583),
		Vector3(9.755, 0.416, 6.567),
		Vector3(9.974, 0.475, 6.555),
		Vector3(10.194, 0.538, 6.547),
		Vector3(10.414, 0.602, 6.541),
		Vector3(10.634, 0.665, 6.536),
		Vector3(10.854, 0.728, 6.532),
		Vector3(11.074, 0.782, 6.529),
		Vector3(11.294, 0.819, 6.525),
		Vector3(11.514, 0.855, 6.522),
		Vector3(11.734, 0.902, 6.517),
		Vector3(11.954, 0.949, 6.512),
		Vector3(12.174, 0.986, 6.505),
		Vector3(12.393, 1.019, 6.495),
		Vector3(12.613, 1.048, 6.478),
		Vector3(12.831, 1.070, 6.454),
		Vector3(13.049, 1.089, 6.422),
		Vector3(13.266, 1.100, 6.384),
		Vector3(13.481, 1.116, 6.341),
		Vector3(13.696, 1.136, 6.293),
		Vector3(13.910, 1.157, 6.242),
		Vector3(14.123, 1.171, 6.187),
		Vector3(14.336, 1.181, 6.130),
		Vector3(14.548, 1.190, 6.071),
		Vector3(14.759, 1.200, 6.012),
		Vector3(14.970, 1.208, 5.949),
		Vector3(15.179, 1.213, 5.879),
		Vector3(15.385, 1.217, 5.803),
		Vector3(15.589, 1.221, 5.720),
		Vector3(15.790, 1.226, 5.631),
		Vector3(15.989, 1.230, 5.537),
		Vector3(16.185, 1.237, 5.437),
		Vector3(16.378, 1.242, 5.331),
		Vector3(16.568, 1.238, 5.220),
		Vector3(16.753, 1.234, 5.101),
		Vector3(16.931, 1.229, 4.971),
		Vector3(17.102, 1.223, 4.833),
		Vector3(17.267, 1.215, 4.688),
		Vector3(17.426, 1.207, 4.536),
		Vector3(17.580, 1.199, 4.379),
		Vector3(17.700, 1.193, 4.250),
	]
	for point in points:
		escape_curve.add_point(point)

func _escape_start_distance(index: int) -> float:
	return float(2 - index) * ESCAPE_SPACING

func _place_escape_runner(distance: float, runner: Node3D) -> void:
	var length := escape_curve.get_baked_length()
	var offset := clampf(distance, 0.0, length)
	runner.position = escape_curve.sample_baked(offset)
	# Cuando el último reno ha salido del hueco, empezar la avalancha.
	if reindeer_running and is_instance_valid(escape_avalanche) and not runners.is_empty():
		if runner == runners.back() and runner.position.x >= 8.5 and not bool(escape_avalanche.get("started")):
			escape_avalanche.call("play")
	# Tangente centrada para que el giro no salte en los puntos de muestreo.
	var ahead := escape_curve.sample_baked(minf(length, offset + 0.30))
	var behind := escape_curve.sample_baked(maxf(0.0, offset - 0.30))
	var tangent := ahead - behind
	if Vector2(tangent.x, tangent.z).length_squared() > 0.00001:
		runner.rotation.y = atan2(-tangent.x, -tangent.z)


func _reindeer(label: String, pos: Vector3, fallen: bool) -> Node3D:
	var deer := _group(props, label, pos)
	var visual := REINDEER_ART.instantiate() as Node3D
	visual.name = "Visual"
	if fallen:
		var pose := _group(deer, "LyingPose", Vector3.ZERO)
		pose.rotation_degrees.z = 90.0
		pose.add_child(visual)
		visual.position.y = -0.8
		for side in range(2):
			for leg in range(2):
				var pivot := visual.get_node("Leg%d%d" % [side, leg]) as Node3D
				pivot.rotation.x = -0.6 if leg == 0 else 0.7
		(visual.get_node("Nose") as MeshInstance3D).hide()
		rudolph_nose = visual.get_node("RedNose") as MeshInstance3D
		rudolph_nose.show()
		nose_mat = rudolph_nose.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		rudolph_nose.material_override = nose_mat
	else:
		deer.add_child(visual)
	return deer


func _on_forest_completed(carried_lights: Node3D) -> void:
	if not GameState.level_01_completed:
		if not is_instance_valid(carried_lights) or carried_lights.get("item_id") != &"powered_lights":
			$Level.set("arriving", false)
			return
		GameState.complete_level_01(&"powered_lights")
	LevelManager.travel_between.call_deferred(2, next_level_scene)


# Contrato de transición: cada escena expone su jugador y un padre para Q.
func get_travel_player() -> Node3D:
	return player

func get_travel_items() -> Node3D:
	return clearing

func prepare_travel_arrival() -> void:
	_update_phase_hud()
	# En una partida normal se recupera el bosque ya visitado. Si se inició
	# directamente la cabaña con F6, todavía no existe ese progreso.
	$Level.set("arriving", false)
	if GameState.level_01_completed:
		$Level.set("completed", true)
		$Level.set("event_started", true)
		$Level.set("event_finished", true)
		player.global_position = Vector3(0.0, 0.05, -25.0)
		player.rotation.y = PI
	else:
		player.global_position = Vector3(0.0, 0.05, 3.0)
		player.rotation.y = 0.0
	head.rotation.x = 0.0
	player.velocity = Vector3.ZERO

func travel_failed() -> void:
	$Level.set("arriving", false)
