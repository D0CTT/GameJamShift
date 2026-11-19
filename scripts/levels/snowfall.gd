extends CPUParticles3D
## Efecto visual local: sigue al jugador sin modificar la fisica ni el inventario.
@export var target_path: NodePath
@export var snow_enabled: bool = true
@export_range(1.0, 6.0, 0.1) var follow_height: float = 3.8
var target: Node3D

func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	_update_position()
	emitting = snow_enabled and is_instance_valid(target)

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		emitting = false
		return
	_update_position()
	if emitting != snow_enabled:
		emitting = snow_enabled

func _update_position() -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * follow_height
