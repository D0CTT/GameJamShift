
extends CharacterBody3D

# MOVIMIENTO
@export var speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025

# ASPIRADORA
@export var suction_duration: float = 2.0
@export var recharge_duration: float = 2.5
@export var mistake_extra_recharge: float = 3.0
@onready var vacuum_bar: ProgressBar = $VacuumHUD/SuctionBar

# REFERENCIAS
@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var vacuum_label: Label = $VacuumHUD/StatusLabel

# FISICAS
var gravity: float = float(
	ProjectSettings.get_setting("physics/3d/default_gravity")
)

# ESTADO DE LA ASPIRADORA
var suction_target: Object = null
var suction_progress: float = 0.0
var recharge_remaining: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interaction_ray.add_exception(self)
	vacuum_bar.value = 0.0
	vacuum_bar.hide()


func _unhandled_input(event: InputEvent) -> void:
	# Mirar con el raton
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)

			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(
				head.rotation.x,
				deg_to_rad(-85.0),
				deg_to_rad(85.0)
			)

	# Liberar el raton
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Recuperar el control del raton
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Inspeccionar con E
	if event.is_action_pressed("interact"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			try_interact()


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Movimiento WASD
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	var direction: Vector3 = (
		transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()

	# Actualizar la aspiradora
	update_vacuum(delta)


func try_interact() -> void:
	interaction_ray.force_raycast_update()

	if interaction_ray.is_colliding():
		var target: Object = interaction_ray.get_collider()

		if target != null and target.has_method("interact"):
			target.call("interact")



func reset_suction() -> void:
	suction_target = null
	suction_progress = 0.0

	vacuum_bar.value = 0.0
	vacuum_bar.hide()





func update_vacuum(delta: float) -> void:
	# RECARGA
	if recharge_remaining > 0.0:
		recharge_remaining = maxf(
			recharge_remaining - delta,
			0.0
		)

		reset_suction()
		vacuum_label.text = "RECARGANDO: %.1f s" % recharge_remaining
		return

	# COMPROBAR SI ESTAMOS ASPIRANDO
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		reset_suction()
		vacuum_label.text = ""
		return

	if not Input.is_action_pressed("use_vacuum"):
		reset_suction()
		vacuum_label.text = ""
		return

	interaction_ray.force_raycast_update()

	if not interaction_ray.is_colliding():
		reset_suction()
		vacuum_label.text = ""
		return

	var target: Object = interaction_ray.get_collider()

	if not is_instance_valid(target):
		reset_suction()
		vacuum_label.text = ""
		return

	if not target.has_method("vacuum_up"):
		reset_suction()
		vacuum_label.text = "NO ABSORBIBLE"
		return

	# CAMBIO DE OBJETIVO
	if target != suction_target:
		suction_target = target
		suction_progress = 0.0

	# PROGRESO DE ABSORCION
	suction_progress += delta

	var required_time: float = maxf(suction_duration, 0.1)

	var percentage: float = clampf(
		suction_progress / required_time * 100.0,
		0.0,
		100.0
	)

	vacuum_bar.value = percentage
	vacuum_bar.show()

	vacuum_label.text = "ABSORBIENDO"

	# ABSORCION COMPLETADA
	if suction_progress >= required_time:
		target.call("vacuum_up")

		reset_suction()
		recharge_remaining = recharge_duration

		vacuum_label.text = "RECARGANDO: %.1f s" % recharge_remaining
