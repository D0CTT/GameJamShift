
extends Node

@export var detection_area: Area3D
@export_range(0.0, 1.0, 0.05) var movement_chance: float = 0.6
@export var movement_distance: float = 0.25
@export var movement_duration: float = 0.8

@onready var chair: AnimatableBody3D = (
	get_parent() as AnimatableBody3D
)

var already_moved: bool = false


func _ready() -> void:
	if chair == null or detection_area == null:
		push_warning("Falta configurar NaturalMotion")
		return

	detection_area.body_entered.connect(_on_body_entered)


func _on_body_entered(other: Node3D) -> void:
	if already_moved:
		return

	if not other is CharacterBody3D:
		return

	already_moved = true

	if randf() > movement_chance:
		return

	# Alejar ligeramente la silla del jugador
	var direction: Vector3 = (
		chair.global_position - other.global_position
	)

	direction.y = 0.0

	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT

	direction = direction.normalized()

	var destination: Vector3 = (
		chair.global_position
		+ direction * movement_distance
	)

	# Movimiento suave
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_property(
		chair,
		"global_position",
		destination,
		movement_duration
	)
