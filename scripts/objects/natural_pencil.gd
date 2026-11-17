
extends RigidBody3D

@export_range(0.0, 1.0, 0.05) var fall_chance: float = 0.65
@export var min_fall_time: float = 8.0
@export var max_fall_time: float = 25.0

var has_fallen: bool = false


func _ready() -> void:
	# Mantener el lapiz inmovil al comenzar
	freeze = true

	# No todos los lapices se caeran
	if randf() > fall_chance:
		return

	var timer: Timer = Timer.new()
	timer.one_shot = true
	add_child(timer)

	timer.timeout.connect(_fall)
	timer.start(
		randf_range(
			min_fall_time,
			maxf(max_fall_time, min_fall_time)
		)
	)


func _fall() -> void:
	if has_fallen:
		return

	has_fallen = true

	# Activar la fisica
	freeze = false
	sleeping = false

	# Pequeño impulso hacia el borde
	var impulse: Vector3 = Vector3(
		randf_range(-0.08, 0.08),
		0.02,
		randf_range(-0.18, -0.10)
	)

	apply_central_impulse(impulse)


func interact() -> void:
	print("Inspeccionando un lapiz")


func vacuum_up() -> void:
	# Siempre es un objeto inocente
	get_tree().call_group(
		"mission_controller",
        "register_innocent_absorption"
	)

	queue_free()
