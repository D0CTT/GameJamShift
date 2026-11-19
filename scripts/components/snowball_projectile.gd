extends Node3D
## A swept projectile, shared by Santa and the elf.
signal impacted(collider: Object, at: Vector3, damaging: bool)
var velocity := Vector3.ZERO
var gravity: float = 2.4
var lifetime: float = 5.0
var owner_rid: RID
var damaging := true
var spent := false

func setup(start: Vector3, initial_velocity: Vector3, shooter: CollisionObject3D, can_damage: bool) -> void:
	global_position = start
	velocity = initial_velocity
	owner_rid = shooter.get_rid()
	damaging = can_damage

func _ready() -> void:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	mesh.radial_segments = 10
	mesh.rings = 5
	ball.mesh = mesh
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.94, 0.98, 1.0)
	ball.material_override = snow
	add_child(ball)

func _physics_process(delta: float) -> void:
	if spent:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var start := global_position
	var end := start + velocity * delta + Vector3.DOWN * gravity * delta * delta * 0.5
	velocity.y -= gravity * delta
	# A segment test prevents fast snowballs from tunnelling through cover.
	var query := PhysicsRayQueryParameters3D.create(start, end, 1, [owner_rid])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		spent = true
		global_position = result["position"]
		impacted.emit(result["collider"], global_position, damaging)
		queue_free()
	else:
		global_position = end
