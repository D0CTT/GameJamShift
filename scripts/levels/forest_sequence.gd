extends Node3D
## Prototipo de la salida del nivel 1. No modifica el Player ni el muñeco.
signal forest_completed(carried_lights: Node3D)
const RETRO_FX = preload("res://scenes/components/retro_effects.tscn")
const SNOW_PINE = preload("res://scenes/art/level_01/snow_pine.tscn")
const FOREST_SHADE = preload("res://shaders/forest_shade.gdshader")
const MOON_SURFACE = preload("res://shaders/night_moon.gdshader")

# Factor de albedo en el sendero profundo, independiente de la posicion del jugador.
@export_range(0.1, 1.0, 0.01) var forest_surface_brightness: float = 0.25
@export_range(1.0, 6.0, 0.1) var moon_radius: float = 3.3
var shade_materials: Dictionary = {}

@export_range(0.0, 2.0, 0.05) var clearing_moon_energy: float = 0.43
@export_range(0.0, 2.0, 0.05) var clearing_ambient_energy: float = 0.20
@export_range(0.0, 0.05, 0.001) var clearing_fog_density: float = 0.024

@export_range(0.0, 1.5, 0.05) var clearing_accent_energy: float = 0.45

@onready var player: CharacterBody3D = $Clearing/Player
@onready var world: WorldEnvironment = $Clearing/WorldEnvironment
@onready var moon: DirectionalLight3D = $Clearing/DirectionalLight3D
@onready var hint: Label = $Overlay/Hint
@onready var fade: ColorRect = $Overlay/Fade
@onready var bell: AudioStreamPlayer3D = $ForestBell
@onready var props: Node3D = $Forest

var environment: Environment
var gate: StaticBody3D
var gate_shape: CollisionShape3D
var exit_gate: StaticBody3D
var shadow: Node3D
var cabin: Node3D
var cabin_lamp: OmniLight3D
var integrated_transition := false
var event_started := false
var event_finished := false
var arriving := false
var completed := false
var gate_open := false
var initial_ambient: float
var initial_moon: float
var initial_background: Color
var snow_mat: StandardMaterial3D
var bark_mat: StandardMaterial3D
var leaves_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var roof_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D
var warm_mat: StandardMaterial3D

func _ready() -> void:
	environment = world.environment.duplicate() as Environment
	world.environment = environment
	# Noche legible: el claro debe permitir buscar las piezas sin luces.
	initial_ambient = clearing_ambient_energy
	initial_moon = clearing_moon_energy
	initial_background = Color(0.025, 0.042, 0.065)
	environment.ambient_light_energy = initial_ambient
	environment.background_color = initial_background
	moon.light_energy = initial_moon
	moon.light_color = Color(0.66, 0.79, 1.0)
	moon.rotation_degrees = Vector3(-32.0, -15.0, 0.0)
	moon.shadow_enabled = true
	environment.ambient_light_color = Color(0.62, 0.73, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.045, 0.069, 0.095)
	environment.fog_density = clearing_fog_density
	fade.color = Color(0, 0, 0, 0)
	hint.hide()
	_build_forest()
	_build_moon_pools()
	_build_visible_moon()
	_shade_background_art.call_deferred()
	if get_tree().get_first_node_in_group("makeshift_retro_fx") == null:
		add_child(RETRO_FX.instantiate())

func _physics_process(_delta: float) -> void:
	if (integrated_transition and GameState.phase == GameState.Phase.COMBAT) or arriving or (completed and not integrated_transition):
		return
	var z: float = player.global_position.z
	var carrying := _has_powered_lights()
	# Entrada de ida: solo se abre con las luces. Desde dentro siempre se
	# puede volver al claro, incluso al haber soltado las luces con Q.
	var returning: bool = GameState.phase == GameState.Phase.DESCENT
	# El edificio solo se revela despues del susto; sigue visible al regresar.
	if is_instance_valid(cabin):
		cabin.visible = event_finished or completed or returning
	var should_open: bool = carrying or z < -6.0 or completed or returning
	if should_open != gate_open:
		gate_open = should_open
		gate_shape.set_deferred("disabled", gate_open)
		(gate.get_node("MeshInstance3D") as MeshInstance3D).hide()
	var darkness := smoothstep(0.0, 1.0, clampf((-z - 5.0) / 6.0, 0.0, 1.0))
	environment.ambient_light_energy = lerpf(initial_ambient, 0.16 if returning else 0.065, darkness)
	moon.light_energy = lerpf(initial_moon, 0.18 if returning else 0.035, darkness)
	environment.background_color = initial_background.lerp(Color(0.012, 0.020, 0.034), darkness)
	environment.fog_density = lerpf(clearing_fog_density, 0.055, darkness)
	hint.hide()
	if z < -4.0 and z > -6.0 and absf(player.global_position.x) < 2.1 and not carrying and not completed and not returning:
		_show_hint("You need the Christmas lights to cross the forest.")
	if z < -11.0 and carrying and not event_started and not returning:
		event_started = true
		_run_scare.call_deferred(player.get("held_item"))
	if z < -27.0:
		if integrated_transition and completed:
			arriving = true
			_arrive.call_deferred()
		elif not carrying:
			_show_hint("Pick up the lights before continuing.")
		elif event_finished:
			arriving = true
			_arrive.call_deferred()

# Manchas suaves de luz lunar entre las copas: permiten leer los puntos
# narrativos y de montaje sin iluminar todo el claro por igual.
func _build_moon_pools() -> void:
	_add_moon_pool("CrashMoonPool", Vector3(-3.4, 3.9, 0.6), clearing_accent_energy, 5.6, 37.0)
	_add_moon_pool("SnowmanMoonPool", Vector3(0.0, 3.5, -0.55), clearing_accent_energy * 0.85, 5.0, 38.0)

func _add_moon_pool(label: String, pos: Vector3, energy: float, reach: float, angle: float) -> void:
	var pool := SpotLight3D.new()
	pool.name = label
	pool.position = pos
	pool.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	pool.light_color = Color(0.76, 0.85, 1.0)
	pool.light_energy = energy
	pool.spot_range = reach
	pool.spot_attenuation = 1.15
	pool.spot_angle = angle
	pool.spot_angle_attenuation = 1.45
	pool.shadow_enabled = false
	$Clearing.add_child(pool)

# El disco se situa en el mismo sentido que el origen aparente de la luz:
# DirectionalLight3D emite en -Z local, la luna esta en +Z local.
func _build_visible_moon() -> void:
	var disc := MeshInstance3D.new()
	disc.name = "MoonDisc"
	var sphere := SphereMesh.new()
	sphere.radius = moon_radius
	sphere.height = moon_radius * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var material := ShaderMaterial.new()
	material.shader = MOON_SURFACE
	disc.mesh = sphere
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	disc.global_position = global_position + moon.global_transform.basis.z.normalized() * 125.0

# El material sigue recibiendo luces reales (incluida la guirnalda).
# Usa coordenadas de mundo para que el camino ya sea oscuro desde el claro.
func _shade_forest_meshes(root: Node) -> void:
	if root is MeshInstance3D:
		var visual := root as MeshInstance3D
		if visual.mesh != null and visual.mesh.get_surface_count() == 1:
			var original := visual.get_active_material(0) as StandardMaterial3D
			if original != null:
				var tint: Color = original.albedo_color
				if not shade_materials.has(tint):
					var material := ShaderMaterial.new()
					material.shader = FOREST_SHADE
					material.set_shader_parameter("base_color", tint)
					material.set_shader_parameter("deep_brightness", forest_surface_brightness)
					shade_materials[tint] = material
				visual.material_override = shade_materials[tint] as ShaderMaterial
	for child in root.get_children():
		_shade_forest_meshes(child)

func _shade_background_art() -> void:
	# El arte exterior es hermano de Level; en test_forest aislado no existe.
	var art := get_parent().get_node_or_null("Level01Art")
	if art == null:
		return
	for label in ["Pines", "Rocks", "BoundaryPines", "BoundaryRocks", "SnowTerrain"]:
		var group := art.get_node_or_null(label)
		if group != null:
			_shade_forest_meshes(group)

func _has_powered_lights() -> bool:
	var held: Node3D = player.get("held_item") as Node3D
	return is_instance_valid(held) and held.get("item_id") == &"powered_lights"

func _show_hint(message: String) -> void:
	hint.text = message
	hint.show()

func _run_scare(lights: Node3D) -> void:
	if not is_instance_valid(lights):
		event_started = false
		return
	get_tree().call_group("makeshift_retro_fx", "set_tension", true)
	var lamp := lights.get_node_or_null("Light") as OmniLight3D
	var energy: float = lamp.light_energy if lamp != null else 2.0
	# Se conservan las visibilidades originales: compatible con el desenrollado.
	var bulbs: Array[MeshInstance3D] = []
	for child in lights.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Bulb"):
			bulbs.append(child as MeshInstance3D)
	var states: Array[bool] = []
	for bulb in bulbs:
		states.append(bulb.visible)
	for i in range(3):
		_set_lights(lamp, bulbs, states, energy, false)
		await get_tree().create_timer(0.10, false).timeout
		_set_lights(lamp, bulbs, states, energy, true)
		await get_tree().create_timer(0.16, false).timeout
	# Sonido espacial real situado detrás del jugador, no en la cámara.
	bell.global_position = player.global_position + player.global_transform.basis.z * 2.3 + Vector3.UP * 0.65
	bell.play()
	await get_tree().create_timer(0.55, false).timeout
	_set_lights(lamp, bulbs, states, energy, false)
	await get_tree().create_timer(0.42, false).timeout
	_set_lights(lamp, bulbs, states, energy, true)
	# Una figura cruza el sendero a unos metros por delante; no persigue.
	var crossing_z := maxf(-28.6, player.global_position.z - 3.0)
	shadow.position = Vector3(-1.65, 0, crossing_z)
	shadow.show()
	var movement := create_tween()
	movement.tween_property(shadow, "position:x", 1.8, 0.58)
	await movement.finished
	shadow.hide()
	# La cabaña se hace legible entre la niebla después del susto.
	cabin_lamp.light_energy = 0.75
	event_finished = true
	get_tree().call_group("makeshift_retro_fx", "set_tension", false)
	cabin.show()

func _set_lights(lamp: OmniLight3D, bulbs: Array[MeshInstance3D], states: Array[bool], energy: float, on: bool) -> void:
	if is_instance_valid(lamp):
		lamp.light_energy = energy if on else 0.0
	for i in range(bulbs.size()):
		if is_instance_valid(bulbs[i]):
			bulbs[i].visible = on and states[i]

func _arrive() -> void:
	if integrated_transition:
		# El gestor global hará el fundido ANTES del cambio real de escena.
		hint.hide()
		forest_completed.emit(player.get("held_item") as Node3D)
		return
	player.call("set_controls_enabled", false)
	hint.hide()
	var transition := create_tween()
	transition.tween_property(fade, "color:a", 1.0, 0.65)
	await transition.finished
	# El nivel 2 aún no está integrado. Llegada provisional en la misma escena:
	# conserva el nodo real de las luces, sin duplicarlo ni reiniciar el inventario.
	player.global_position = Vector3(0, 0.05, -32.0)
	player.rotation.y = 0.0
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	player.velocity = Vector3.ZERO
	exit_gate.queue_free()
	environment.ambient_light_energy = 0.18
	moon.light_energy = 0.12
	environment.fog_density = 0.035
	completed = true
	await get_tree().create_timer(0.25, false).timeout
	var reveal := create_tween()
	reveal.tween_property(fade, "color:a", 0.0, 0.8)
	await reveal.finished
	player.call("set_controls_enabled", true)
	_show_hint("Level 1 complete - Cabin reached (prototype)")
	forest_completed.emit(player.get("held_item") as Node3D)
	await get_tree().create_timer(4.0, false).timeout
	hint.hide()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid: bool = true) -> Node3D:
	var root: Node3D
	if solid:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	parent.add_child(root)
	root.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = mesh
	root.add_child(visual)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.name = "CollisionShape3D"
		collider.shape = shape
		root.add_child(collider)
	return root

func _boundary(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := _box(parent, pos, size, mat) as StaticBody3D
	# Conserva el nodo MeshInstance3D para los scripts del porton y del duelo.
	# Sin recurso Mesh no se dibuja, incluso si otro script llama a show().
	var visual := body.get_node("MeshInstance3D") as MeshInstance3D
	visual.mesh = null
	return body

func _tree(pos: Vector3, height: float) -> void:
	var tree := Node3D.new()
	props.add_child(tree)
	tree.position = pos
	# Preserve the original trunk collider and replace only its visible art.
	var trunk := _box(tree, Vector3(0, height * 0.26, 0), Vector3(0.24, height * 0.52, 0.24), bark_mat)
	(trunk.get_node("MeshInstance3D") as MeshInstance3D).hide()
	var visual := SNOW_PINE.instantiate() as Node3D
	tree.add_child(visual)
	visual.scale = Vector3.ONE * (height / 3.0)
	_shade_forest_meshes(visual)

func _build_forest() -> void:
	snow_mat = _material(Color(0.63, 0.73, 0.82))
	bark_mat = _material(Color(0.16, 0.10, 0.075))
	leaves_mat = _material(Color(0.08, 0.19, 0.16))
	wood_mat = _material(Color(0.28, 0.19, 0.13))
	roof_mat = _material(Color(0.54, 0.66, 0.73))
	dark_mat = _material(Color(0.028, 0.035, 0.042))
	warm_mat = _material(Color(0.55, 0.39, 0.19))
	# El suelo nuevo comienza exactamente donde termina el claro (z = -6).
	var forest_ground := _box(props, Vector3(0, -0.1, -23), Vector3(12, 0.2, 34), snow_mat)
	_shade_forest_meshes(forest_ground)
	# Limites invisibles: conservar las colisiones originales sin paredes visibles.
	for side in [-1, 1]:
		_boundary(props, Vector3(side * 4.0, 0.95, -6.0), Vector3(4.6, 1.9, 0.50), snow_mat)
		_boundary(props, Vector3(side * 5.85, 0.95, -17), Vector3(0.3, 1.9, 46), snow_mat)
		_boundary(props, Vector3(side * 5.85, 0.95, 3), Vector3(0.3, 1.9, 18), snow_mat)
	_boundary(props, Vector3(0, 0.95, 11.85), Vector3(12, 1.9, 0.3), snow_mat)
	_boundary(props, Vector3(0, 0.95, -39.85), Vector3(12, 1.9, 0.3), snow_mat)
	gate = _boundary(props, Vector3(0, 0.95, -6), Vector3(3.55, 1.9, 0.45), dark_mat) as StaticBody3D
	gate.name = "ForestGate"
	gate_shape = gate.get_node("CollisionShape3D") as CollisionShape3D
	exit_gate = _boundary(props, Vector3(0, 0.95, -29.5), Vector3(12, 1.9, 0.25), dark_mat) as StaticBody3D
	# Forma un camino de unos 3 m, con árboles decorativos más allá.
	var rng := RandomNumberGenerator.new()
	rng.seed = 518
	for i in range(13):
		for side in [-1, 1]:
			_tree(Vector3(side * rng.randf_range(2.15, 3.0), 0, -7.5 - i * 1.7), rng.randf_range(2.4, 3.4))
			_tree(Vector3(side * rng.randf_range(4.0, 5.2), 0, -8.0 - i * 1.7), rng.randf_range(2.8, 4.0))
	# Silueta baja y ambigua, sin colisión ni IA.
	shadow = Node3D.new()
	props.add_child(shadow)
	_box(shadow, Vector3(0, 0.48, 0), Vector3(0.30, 0.65, 0.20), dark_mat, false)
	_box(shadow, Vector3(0, 0.91, 0), Vector3(0.30, 0.27, 0.25), dark_mat, false)
	shadow.hide()
	# Maqueta de la cabaña, no el interior del nivel 2.
	cabin = Node3D.new()
	props.add_child(cabin)
	cabin.position = Vector3(0, 0, -36.0)
	_box(cabin, Vector3(0, 1.15, 0), Vector3(4.0, 2.3, 3.0), wood_mat)
	var left_roof := _box(cabin, Vector3(-1.03, 2.55, 0), Vector3(2.38, 0.22, 3.55), roof_mat, false)
	left_roof.rotation_degrees.z = 26.0
	var right_roof := _box(cabin, Vector3(1.03, 2.55, 0), Vector3(2.38, 0.22, 3.55), roof_mat, false)
	right_roof.rotation_degrees.z = -26.0
	_box(cabin, Vector3(0, 0.94, 1.52), Vector3(0.88, 1.88, 0.08), dark_mat, false)
	_box(cabin, Vector3(1.26, 1.28, 1.53), Vector3(0.65, 0.70, 0.08), warm_mat, false)
	_box(cabin, Vector3(1.26, 1.28, 1.58), Vector3(0.05, 0.70, 0.025), dark_mat, false)
	_box(cabin, Vector3(1.26, 1.28, 1.58), Vector3(0.65, 0.05, 0.025), dark_mat, false)
	cabin_lamp = OmniLight3D.new()
	cabin.add_child(cabin_lamp)
	cabin_lamp.position = Vector3(0, 2.05, 2.15)
	cabin_lamp.light_color = Color(0.78, 0.84, 1.0)
	cabin_lamp.light_energy = 0.0
	cabin_lamp.omni_range = 6.5
	cabin.hide()
