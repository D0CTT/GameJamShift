
extends Node

# OBJETIVO
@export var call_point: Marker3D

# MOVIMIENTO
@export var move_speed: float = 0.8
@export var min_wait: float = 4.0
@export var max_wait: float = 8.0
@export var min_player_distance: float = 2.5
@export var press_distance: float = 0.25

# TAMANO APROXIMADO DEL OBJETO
@export var visual_half_size: Vector3 = Vector3(0.4, 0.4, 0.4)

# REFERENCIAS
@onready var object_body: AnimatableBody3D = (
	get_parent() as AnimatableBody3D
)

var move_timer: Timer
var is_moving: bool = false


func _ready() -> void:
	if object_body == null:
		push_error("SneakMover necesita un AnimatableBody3D")
		set_physics_process(false)
		return

	if call_point == null:
		push_error("Asigna el PressPoint del boton")
		set_physics_process(false)
		return

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

	return bool(controller.get("mission_finished"))


func _try_start_moving() -> void:
	schedule_next_move()

	if is_moving:
		return

	if mission_is_finished():
		return

	if not object_body.is_in_group("shapeshifter"):
		return

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return

	# No empezar si el jugador lo esta viendo
	if is_on_screen(object_body.global_position, camera):
		return

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

	# Congelarse si el jugador lo descubre
	if is_on_screen(object_body.global_position, camera):
		is_moving = false
		return

	# Evitar moverse cerca del jugador
	if camera.global_position.distance_to(
		object_body.global_position
	) < min_player_distance:
		is_moving = false
		return

	# Comprobar si llego al boton
	var distance_to_button: float = (
		object_body.global_position.distance_to(
			call_point.global_position
		)
	)

	if distance_to_button <= press_distance:
		press_button()
		return

	# Avanzar lentamente hacia el boton
	var next_position: Vector3 = (
		object_body.global_position.move_toward(
			call_point.global_position,
			move_speed * delta
		)
	)

	# No avanzar dentro de la vista del jugador
	if is_on_screen(next_position, camera):
		is_moving = false
		return

	object_body.global_position = next_position


func press_button() -> void:
	is_moving = false

	var button: Node = call_point.get_parent()

	if button.has_method("press_by_shapeshifter"):
		button.call("press_by_shapeshifter")


func is_on_screen(
	world_position: Vector3,
	camera: Camera3D
) -> bool:

	var e: Vector3 = visual_half_size

	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(-e.x, -e.y, -e.z),
		Vector3(-e.x, -e.y, e.z),
		Vector3(-e.x, e.y, -e.z),
		Vector3(-e.x, e.y, e.z),
		Vector3(e.x, -e.y, -e.z),
		Vector3(e.x, -e.y, e.z),
		Vector3(e.x, e.y, -e.z),
		Vector3(e.x, e.y, e.z)
	]

	for offset in offsets:
		if camera.is_position_in_frustum(
			world_position + offset
		):
			return true

	return false
