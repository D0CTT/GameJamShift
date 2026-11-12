
extends Node

# PUNTOS A LOS QUE PUEDE DESPLAZARSE
@export var hiding_spots: Array[Marker3D] = []

# TIEMPO ENTRE INTENTOS DE MOVIMIENTO
@export_range(1.0, 30.0, 0.5) var min_wait: float = 4.0
@export_range(1.0, 30.0, 0.5) var max_wait: float = 8.0

# DISTANCIA MINIMA RESPECTO AL JUGADOR
@export var min_player_distance: float = 2.5

# MITAD DEL TAMANO APROXIMADO DEL OBJETO
@export var visual_half_size: Vector3 = Vector3(0.4, 0.4, 0.4)

# REFERENCIAS
@onready var object_body: StaticBody3D = get_parent() as StaticBody3D

# VELOCIDAD DE DESPLAZAMIENTO
@export var move_speed: float = 0.8

# ESTADO DEL MOVIMIENTO
var is_moving: bool = false
var target_position: Vector3 = Vector3.ZERO

var move_timer: Timer


func _ready() -> void:
	if object_body == null:
		push_error("SneakMover necesita un StaticBody3D como padre.")
		return

	# Crear temporizador
	move_timer = Timer.new()
	move_timer.one_shot = true
	add_child(move_timer)

	move_timer.timeout.connect(_try_move)
	schedule_next_move()


func schedule_next_move() -> void:
	var minimum: float = maxf(min_wait, 0.1)
	var maximum: float = maxf(max_wait, minimum)

	move_timer.start(randf_range(minimum, maximum))


func _try_move() -> void:
	# Programar el siguiente intento
	
	# No elegir otro destino mientras se esta moviendo
	if is_moving:
		return

	schedule_next_move()

	# Solo funcionan los cambiaformas
	if not is_instance_valid(object_body):
		return

	if not object_body.is_in_group("shapeshifter"):
		return

	# No moverse si la mision ha terminado
	for controller in get_tree().get_nodes_in_group("mission_controller"):
		if bool(controller.get("mission_finished")):
			return

	# Obtener la camara activa
	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return

	# Evitar moverse demasiado cerca del jugador
	if camera.global_position.distance_to(
		object_body.global_position
	) < min_player_distance:
		return

	# No moverse mientras el jugador pueda verlo
	if is_on_screen(object_body.global_position, camera):
		return

	# Buscar destinos validos
	var possible_spots: Array[Marker3D] = []

	for spot in hiding_spots:
		if not is_instance_valid(spot):
			continue

		var destination: Vector3 = spot.global_position

		# Evitar la posicion actual
		if destination.distance_to(object_body.global_position) < 0.5:
			continue

		# Evitar destinos demasiado cercanos al jugador
		if destination.distance_to(
			camera.global_position
		) < min_player_distance:
			continue

		# No aparecer delante de la camara
		if is_on_screen(destination, camera):
			continue

		possible_spots.append(spot)

	if possible_spots.is_empty():
		return

	# Elegir un escondite aleatorio
	var chosen: Marker3D = possible_spots.pick_random()


	# Guardar el destino sin teletransportarse
	target_position = chosen.global_position
	is_moving = true



func is_on_screen(
	world_position: Vector3,
	camera: Camera3D
) -> bool:

	var e: Vector3 = visual_half_size

	# Comprobar centro y esquinas del objeto
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

func _physics_process(delta: float) -> void:
	if not is_moving:
		return

	if not is_instance_valid(object_body):
		is_moving = false
		return

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		is_moving = false
		return

	# Detenerse si el jugador puede verlo
	if is_on_screen(object_body.global_position, camera):
		is_moving = false
		return

	# No avanzar hacia un destino visible
	if is_on_screen(target_position, camera):
		is_moving = false
		return

	# Detenerse si el jugador se acerca demasiado
	var distance_to_player: float = (
		camera.global_position.distance_to(
			object_body.global_position
		)
	)

	if distance_to_player < min_player_distance:
		is_moving = false
		return

	# Avanzar poco a poco hacia el destino
	var next_position: Vector3 = (
		object_body.global_position.move_toward(
			target_position,
			move_speed * delta
		)
	)

	# Evitar entrar en el campo de vision
	if is_on_screen(next_position, camera):
		is_moving = false
		return

	object_body.global_position = next_position

	# Comprobar si llego al escondite
	if object_body.global_position.distance_to(
		target_position
	) < 0.03:
		is_moving = false
