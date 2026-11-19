extends Node3D
## Cierre cinematográfico de la ruta de fuga. Persiste en la escena cacheada.
signal settled
const RUMBLE = preload("res://assets/audio/escape_snowfall.wav")
const FLAKE = preload("res://assets/textures/snow_flake.png")
const CENTER := Vector3(5.95, 0.0, 6.40)
var started := false
var finished := false
var bank: Node3D
var barrier: StaticBody3D
var snow: StandardMaterial3D
var pines: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

func configure(art: Node3D) -> void:
	if art != null:
		for path in ["BoundaryPines/EdgePine06", "BoundaryPines/ExtensionPine1"]:
			var pine := art.get_node_or_null(path) as Node3D
			if pine != null:
				pines.append(pine)
	rng.seed = 1978
	snow = StandardMaterial3D.new()
	snow.albedo_color = Color(0.78, 0.87, 0.94)
	snow.roughness = 1.0
	bank = Node3D.new()
	bank.name = "SnowBankVisual"
	add_child(bank)
	bank.position = CENTER
	# Solapamiento de lóbulos facetados para una acumulación irregular.
	_make_lobe(Vector3(0.12, 0.15, -0.85), Vector3(0.95, 0.85, 0.89))
	_make_lobe(Vector3(0.10, 0.38, -0.32), Vector3(0.88, 1.40, 0.93))
	_make_lobe(Vector3(0.08, 0.40, 0.45), Vector3(0.90, 1.47, 0.93))
	_make_lobe(Vector3(0.14, 0.15, 1.05), Vector3(0.86, 0.88, 0.77))
	_make_lobe(Vector3(-0.35, 0.08, -0.40), Vector3(0.61, 0.40, 0.91))
	_make_lobe(Vector3(-0.28, 0.10, 0.65), Vector3(0.67, 0.48, 0.92))
	bank.hide()
	barrier = StaticBody3D.new()
	barrier.name = "EscapeSnowBarrier"
	barrier.collision_layer = 0
	barrier.collision_mask = 0
	add_child(barrier)
	# Núcleo sólido alineado con el límite original del claro; no invade las piezas.
	barrier.position = CENTER + Vector3(-0.04, 0.89, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.90, 1.78, 2.65)
	collision.shape = shape
	barrier.add_child(collision)

func _make_lobe(at: Vector3, dimensions: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	mesh.material = snow
	visual.mesh = mesh
	bank.add_child(visual)
	visual.position = at
	visual.scale = dimensions
	visual.rotation.y = rng.randf_range(-PI, PI)

func play() -> void:
	if started:
		return
	started = true
	var sound := AudioStreamPlayer3D.new()
	sound.stream = RUMBLE
	sound.unit_size = 5.0
	sound.max_distance = 24.0
	sound.volume_db = -2.0
	add_child(sound)
	sound.position = CENTER + Vector3.UP
	sound.finished.connect(sound.queue_free)
	sound.play()
	# Sacudir solo los pinos decorativos de los dos lados del paso.
	var origins: Array[Vector3] = [Vector3(6.55, 2.4, 4.7), Vector3(6.8, 2.5, 8.0)]
	for i in range(pines.size()):
		var pine := pines[i]
		var initial := pine.rotation.z
		var shake := create_tween()
		shake.tween_property(pine, "rotation:z", initial + 0.055, 0.12)
		shake.tween_property(pine, "rotation:z", initial - 0.040, 0.17)
		shake.tween_property(pine, "rotation:z", initial + 0.025, 0.13)
		shake.tween_property(pine, "rotation:z", initial, 0.18)
	await get_tree().create_timer(0.16, false).timeout
	for origin in origins:
		_spawn_powder(origin, false)
		for i in range(11):
			_drop_chunk(origin, i)
	await get_tree().create_timer(0.37, false).timeout
	bank.scale.y = 0.04
	bank.show()
	var rise := create_tween()
	rise.tween_property(bank, "scale:y", 1.0, 0.60).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_powder(CENTER + Vector3(0, 0.65, 0), true)
	await rise.finished
	settle_immediately()

func settle_immediately() -> void:
	if finished:
		return
	started = true
	bank.scale = Vector3.ONE
	bank.show()
	barrier.set_deferred("collision_layer", 1)
	finished = true
	settled.emit()

func _drop_chunk(origin: Vector3, index: int) -> void:
	var chunk := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	var radius := rng.randf_range(0.10, 0.23)
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = snow
	chunk.mesh = mesh
	add_child(chunk)
	var start := origin + Vector3(rng.randf_range(-0.40, 0.40), rng.randf_range(-0.35, 0.45), rng.randf_range(-0.38, 0.38))
	var target := CENTER + Vector3(rng.randf_range(-0.50, 0.45), rng.randf_range(0.12, 0.75), rng.randf_range(-1.25, 1.25))
	chunk.position = start
	var fall := create_tween()
	fall.tween_interval(float(index % 4) * 0.065)
	fall.tween_property(chunk, "position", target, rng.randf_range(0.40, 0.70)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(chunk, "rotation", Vector3(1.3, 0.7, 2.1), 0.48)
	fall.tween_callback(chunk.queue_free)

func _spawn_powder(at: Vector3, ground_cloud: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 75 if ground_cloud else 100
	particles.lifetime = 1.1
	particles.explosiveness = 0.86
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.5, 0.16, 0.85) if ground_cloud else Vector3(0.62, 0.36, 0.62)
	particles.direction = Vector3(-1.0, 0.45, 0.0) if ground_cloud else Vector3(-0.25, -1.0, 0.0)
	particles.spread = 58.0 if ground_cloud else 22.0
	particles.gravity = Vector3(0.0, -3.5, 0.0)
	particles.initial_velocity_min = 0.55
	particles.initial_velocity_max = 1.65
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.6
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = FLAKE
	mat.albedo_color = Color(0.83, 0.91, 1.0, 0.85)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.19, 0.19) if ground_cloud else Vector2(0.13, 0.13)
	quad.material = mat
	particles.mesh = quad
	add_child(particles)
	particles.position = at
	particles.emitting = true
	get_tree().create_timer(2.0, false).timeout.connect(particles.queue_free)
