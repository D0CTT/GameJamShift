
extends Node

# TIPOS DE CAMBIAFORMAS
enum Behavior {
	GO_TO_BUTTON,
	WANDER
}

@export var behavior: Behavior = Behavior.GO_TO_BUTTON

# DESTINOS
@export var call_point: Marker3D
@export var roam_points: Array[Marker3D] = []

# MOVIMIENTO
@export var move_speed: float = 0.8
@export var min_wait: float = 3.0
@export var max_wait: float = 7.0
@export var min_player_distance: float = 1.5
@export var reach_distance: float = 0.65

# TAMANO APROXIMADO DEL OBJETO
@export var visual_half_size: Vector3 = Vector3(0.35, 0.35, 0.35)

# REFERENCIAS
@onready var body: AnimatableBody3D = (
	get_parent() as AnimatableBody3D
)

@onready var nav: NavigationAgent3D = (
	get_node_or_null("../NavigationAgent3D") as NavigationAgent3D
)

var move_timer: Timer
var is_moving: bool = false
var current_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	if body == null or nav == null:
		push_error("Falta AnimatableBody3D o NavigationAgent3D")
		set_physics_process(false)
		return

	nav.path_desired_distance = 0.35
	nav.target_desired_distance = 0.45
	nav.avoidance_enabled = false

	move_timer = Timer.new()
	move_timer.one_shot = true
	add_child(move_timer)

	move_timer.timeout.connect(_try_start_moving)
	schedule_next_move()


func schedule_next_move() -> void:
	var minimum: float = maxf(min_wait, 0.1)
	var maximum: float = maxf(max_wait, minimum)

	move_timer.start(randf_range(minimum, maximum))


func mission_is_finished() -> bool:
	var controller: Node = get_tree().get_first_node_in_group(
        "mission_controller"
	)

	if controller == null:
		return false

	return controller.get("mission_finished") == true


func _try_start_moving() -> void:
	schedule_next_move()

	if is_moving or mission_is_finished():
		return

	if not body.is_in_group("shapeshifter"):
		return

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return

	if camera.global_position.distance_to(
		body.global_position
	) < min_player_distance:
		return

	if is_visible_to_player(body.global_position, camera):
		return

	# ELEGIR DESTINO SEGUN EL COMPORTAMIENTO
	if behavior == Behavior.GO_TO_BUTTON:
		if call_point == null:
			return

		current_target = call_point.global_position

	else:
		var candidates: Array[Marker3D] = []

		for spot in roam_points:
			if not is_instance_valid(spot):
				continue

			if spot.global_position.distance_to(
				body.global_position
			) < 1.0:
				continue

			candidates.append(spot)

		if candidates.is_empty():
			return

		var chosen: Marker3D = candidates.pick_random()
		current_target = chosen.global_position

	nav.target_position = current_target
	is_moving = true


func _physics_process(delta: float) -> void:
	if not is_moving:
		return

	if mission_is_finished():
		is_moving = false
		return

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return

	# DETENERSE SI EL JUGADOR LO DESCUBRE
	if is_visible_to_player(body.global_position, camera):
		is_moving = false
		return

	if camera.global_position.distance_to(
		body.global_position
	) < min_player_distance:
		is_moving = false
		return

	# ESPERAR A QUE LA NAVEGACION ESTE LISTA
	if NavigationServer3D.map_get_iteration_id(
		nav.get_navigation_map()
	) == 0:
		return

	if nav.is_navigation_finished():
		finish_movement()
		return

	# OBTENER EL SIGUIENTE PUNTO DE LA RUTA
	var next_point: Vector3 = nav.get_next_path_position()

	if nav.is_navigation_finished():
		finish_movement()
		return

	# MANTENER LA ALTURA ACTUAL DEL OBJETO
	next_point.y = body.global_position.y

	var next_position: Vector3 = body.global_position.move_toward(
		next_point,
		move_speed * delta
	)

	# NO ENTRAR EN EL CAMPO VISUAL
	if is_visible_to_player(next_position, camera):
		is_moving = false
		return

	body.global_position = next_position


func finish_movement() -> void:
	is_moving = false

	if behavior != Behavior.GO_TO_BUTTON:
		return

	if call_point == null:
		return

	# DISTANCIA HORIZONTAL AL BOTON
	var difference: Vector3 = (
		body.global_position - call_point.global_position
	)
	difference.y = 0.0

	if difference.length() > reach_distance:
		return

	# AUTORIZAR LA LLEGADA
	var button: Node = call_point.get_parent()

	if button.has_method("press_by_shapeshifter"):
		button.call("press_by_shapeshifter")


func is_visible_to_player(
	world_position: Vector3,
	camera: Camera3D
) -> bool:

	var e: Vector3 = visual_half_size

	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(e.x, 0, 0),
		Vector3(-e.x, 0, 0),
		Vector3(0, e.y, 0),
		Vector3(0, -e.y, 0),
		Vector3(0, 0, e.z),
		Vector3(0, 0, -e.z)
	]

	for offset in offsets:
		var point: Vector3 = world_position + offset

		# FUERA DEL CAMPO VISUAL
		if not camera.is_position_in_frustum(point):
			continue

		# COMPROBAR SI UNA PARED OCULTA EL OBJETO
		var query: PhysicsRayQueryParameters3D = (
			PhysicsRayQueryParameters3D.create(
				camera.global_position,
				point
			)
		)

		# IGNORAR LA COLISION DEL PROPIO JUGADOR
		var player_body: CollisionObject3D = (
			camera.get_parent().get_parent() as CollisionObject3D
		)

		if player_body != null:
			query.exclude = [player_body.get_rid()]

		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(
			query
		)

		# OBJETO VISIBLE O SIN OBSTACULOS DELANTE
		if hit.is_empty() or hit.get("collider") == body:
			return true

	return false
