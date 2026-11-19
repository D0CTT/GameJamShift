extends RefCounted

static func spawn(parent: Node3D, at: Vector3, count: int = 20, downward: bool = false) -> void:
	var puff := CPUParticles3D.new()
	puff.emitting = false
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = count
	puff.lifetime = 0.65 if not downward else 1.0
	puff.local_coords = false
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.12 if not downward else 0.24
	puff.direction = Vector3.DOWN if downward else Vector3.UP
	puff.spread = 55.0 if downward else 80.0
	puff.initial_velocity_min = 0.15
	puff.initial_velocity_max = 0.8 if downward else 1.15
	puff.gravity = Vector3(0, -3.0, 0)
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.92, 1.0)
	material.roughness = 1.0
	var flake := SphereMesh.new()
	flake.radius = 0.015
	flake.height = 0.03
	flake.radial_segments = 5
	flake.rings = 3
	flake.material = material
	puff.mesh = flake
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(puff)
	puff.position = at
	puff.finished.connect(puff.queue_free)
	puff.emitting = true
