extends Node3D

const SNOW_PUFF = preload("res://scripts/components/snow_puff.gd")
const HEAD_BREAK_AUDIO = preload("res://assets/audio/snow_head_break.wav")

@export_range(-30.0, 3.0, 1.0) var head_break_volume_db: float = -4.0

signal snowman_completed
signal battery_revealed(battery_item: Node3D)

@onready var slots: Array[StaticBody3D] = [$BaseSlot, $TorsoSlot, $HeadSlot, $CarrotSlot, $LeftBranchSlot, $RightBranchSlot, $ScarfSlot]
@onready var battery: StaticBody3D = get_node_or_null("Battery") as StaticBody3D
@onready var placement_sound: AudioStreamPlayer3D = get_node_or_null("PlacementSound") as AudioStreamPlayer3D
@onready var celebration_sound: AudioStreamPlayer3D = get_node_or_null("CelebrationSound") as AudioStreamPlayer3D
var stage: int = 0
var complete: bool = false

func _ready() -> void:
	for slot in slots:
		slot.connect("piece_placed", _on_piece_placed)
		set_slot_active(slot, false)
	set_slot_active(slots[0], true)
	# Los hijos ya ejecutaron _ready: Pickup conserva sus capas originales.
	if is_instance_valid(battery):
		battery.hide()
		battery.call("set_carried")

func set_slot_active(slot: StaticBody3D, active: bool) -> void:
	slot.get_node("Preview").visible = active
	slot.collision_layer = 1 if active else 0
	slot.collision_mask = 0

func _on_piece_placed(_item_id: StringName) -> void:
	if complete:
		return
	set_slot_active(slots[stage], false)
	stage += 1
	var placed_point := slots[stage - 1].get_node("PlacementPoint") as Node3D
	if stage <= slots.size():
		SNOW_PUFF.spawn(self, to_local(placed_point.global_position), 14)
	if stage == slots.size():
		complete = true
		print("¡Muñeco de nieve completo!")
		if is_instance_valid(celebration_sound):
			celebration_sound.play()
		snowman_completed.emit()
		if is_instance_valid(battery):
			_play_head_fall()
	else:
		if is_instance_valid(placement_sound):
			placement_sound.play()
		set_slot_active(slots[stage], true)

func _play_head_fall() -> void:
	# Pausa deliberada después de la celebración.
	await get_tree().create_timer(2.0, false).timeout
	var head_point: Node3D = slots[2].get_node("PlacementPoint") as Node3D
	var carrot_point: Node3D = slots[3].get_node("PlacementPoint") as Node3D
	if head_point.get_child_count() == 0 or carrot_point.get_child_count() == 0:
		return
	var head_item: StaticBody3D = head_point.get_child(0) as StaticBody3D
	var carrot: StaticBody3D = carrot_point.get_child(0) as StaticBody3D
	if not is_instance_valid(head_item) or not is_instance_valid(carrot):
		return
	# La nariz acompaña a la cabeza. No se simula una caída física.
	head_item.collision_layer = 0
	head_item.collision_mask = 0
	carrot.collision_layer = 0
	carrot.collision_mask = 0
	head_item.reparent(self, true)
	carrot.reparent(head_item, true)
	var start: Vector3 = head_item.position
	var tilt := create_tween()
	tilt.tween_property(head_item, "rotation:z", -0.40, 0.45).set_trans(Tween.TRANS_SINE)
	tilt.parallel().tween_property(head_item, "position:x", start.x + 0.14, 0.45)
	await tilt.finished
	var fall := create_tween()
	fall.tween_property(head_item, "position", Vector3(0.88, 0.16, 0.0), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(head_item, "rotation:z", -1.35, 0.48)
	await fall.finished
	# El impacto rompe la cabeza y descubre su contenido, sin lanzar la pila.
	var impact: Vector3 = head_item.position
	_play_head_break(impact)
	carrot.reparent(self, true)
	head_item.hide()
	head_item.queue_free()
	SNOW_PUFF.spawn(self, Vector3(impact.x, 0.075, impact.z), 44)
	_scatter_head_fragments(impact)
	var carrot_start: Vector3 = carrot.position
	var carrot_end := Vector3(1.25, 0.065, -0.31)
	var carrot_tween := create_tween().set_parallel(true)
	carrot_tween.tween_method(_fragment_arc.bind(carrot, carrot_start, carrot_end, 0.12), 0.0, 1.0, 0.38)
	carrot_tween.tween_property(carrot, "rotation", Vector3(0, 0.65, 0), 0.38)
	# Una sola batería, en posición de reposo y recogible como antes.
	battery.position = Vector3(impact.x, 0.105, impact.z)
	battery.rotation = Vector3.ZERO
	battery.show()
	battery.call("set_returned")
	battery_revealed.emit(battery)
	print("¡La cabeza se ha roto y ha revelado una batería!")

func _scatter_head_fragments(impact: Vector3) -> void:
	var debris := Node3D.new()
	debris.name = "BrokenHeadSnow"
	add_child(debris)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.91, 0.95, 1.0)
	material.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 182
	# Fragmentos sólidos solo visualmente: no bloquean la pila ni el camino.
	for i in range(12):
		var fragment := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var radius: float = rng.randf_range(0.023, 0.055)
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 5
		mesh.rings = 3
		mesh.material = material
		fragment.mesh = mesh
		fragment.name = "SnowChunk%d" % i
		debris.add_child(fragment)
		var angle: float = TAU * float(i) / 12.0 + rng.randf_range(-0.18, 0.18)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var start: Vector3 = impact + direction * rng.randf_range(0.025, 0.09)
		var finish: Vector3 = impact + direction * rng.randf_range(0.23, 0.46)
		# Mantener una separación alrededor de la batería.
		finish.y = radius * 0.61 + 0.004
		fragment.position = start
		var final_scale := Vector3(rng.randf_range(0.85, 1.25), 0.61, rng.randf_range(0.8, 1.2))
		var duration: float = rng.randf_range(0.28, 0.46)
		var flight := create_tween().set_parallel(true)
		flight.tween_method(_fragment_arc.bind(fragment, start, finish, rng.randf_range(0.07, 0.19)), 0.0, 1.0, duration)
		flight.tween_property(fragment, "rotation:y", rng.randf_range(-PI, PI), duration)
		flight.tween_property(fragment, "scale", final_scale, duration)

func _fragment_arc(progress: float, piece: Node3D, start: Vector3, finish: Vector3, arc_height: float) -> void:
	if not is_instance_valid(piece):
		return
	piece.position = start.lerp(finish, progress) + Vector3.UP * (4.0 * arc_height * progress * (1.0 - progress))

func _play_head_break(impact: Vector3) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.name = "HeadBreakSound"
	sound.stream = HEAD_BREAK_AUDIO
	sound.volume_db = head_break_volume_db
	sound.unit_size = 2.5
	sound.max_distance = 14.0
	sound.position = impact
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
