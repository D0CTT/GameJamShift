
extends CharacterBody3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
# CONFIGURACION DEL JUGADOR
@export var speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025

# REFERENCIAS
@onready var head: Node3D = $Head

# FISICAS
var gravity: float = float(
	ProjectSettings.get_setting("physics/3d/default_gravity")
)


func _ready() -> void:
	# Capturamos el raton al comenzar
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interaction_ray.add_exception(self)


func _unhandled_input(event: InputEvent) -> void:
	# Movimiento de camara con el raton
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)

			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(
				head.rotation.x,
				deg_to_rad(-85.0),
				deg_to_rad(85.0)
			)

	# ESC libera el raton
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Clic izquierdo vuelve a capturar el raton
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Interactuar con la E
	if event.is_action_pressed("interact"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			try_interact()


func try_interact() -> void:
	interaction_ray.force_raycast_update()

	if interaction_ray.is_colliding():
		var target: Object = interaction_ray.get_collider()

		if target != null and target.has_method("interact"):
			target.call("interact")

func _physics_process(delta: float) -> void:
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Leer las teclas WASD
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	# Transformar movimiento a la direccion del jugador
	var direction: Vector3 = (
		transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	# Aplicar velocidad horizontal
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	# Mover y gestionar colisiones
	move_and_slide()
