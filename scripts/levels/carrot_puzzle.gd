extends Node3D
## A reusable snowball puzzle for the clearing only. Combat keeps its own input.
const PICKUP = preload("res://scripts/components/pickup.gd")
const PROJECTILE = preload("res://scripts/components/snowball_projectile.gd")
const SNOW_PUFF = preload("res://scripts/components/snow_puff.gd")
const THROW_SOUND = preload("res://assets/audio/snowball_throw.wav")
const HIT_SOUND = preload("res://assets/audio/snowball_hit.wav")
const BALL_ID: StringName = &"exploration_snowball"

var player: CharacterBody3D
var carrot: StaticBody3D
var ground: StaticBody3D
var target_tree: Node3D
var original_shape: Shape3D
var original_shape_transform: Transform3D
var landing: Vector3
var released := false
var falling := false
var hint: Label

func _ready() -> void:
	# All clearing children have entered the tree before this component is added.
	var clearing := get_parent()
	player = clearing.get_node("Player") as CharacterBody3D
	carrot = clearing.get_node("Carrot") as StaticBody3D
	ground = clearing.get_node("Ground") as StaticBody3D
	target_tree = clearing.get_node("BranchTrees/Tree1") as Node3D
	player.set("exploration_snowballs", self)
	# Tree1 faces the open clearing. The broad end is embedded in the foliage.
	carrot.global_position = target_tree.to_global(Vector3(-0.55, 2.25, 0.0))
	carrot.rotation_degrees = Vector3(0, -90, 0)
	landing = target_tree.to_global(Vector3(-1.0, 0.069, 0.0))
	carrot.set("available", false)
	var shape_node := carrot.get_node("CollisionShape3D") as CollisionShape3D
	original_shape = shape_node.shape
	original_shape_transform = shape_node.transform
	# Slightly forgiving target while it is stuck; restore the original pickup size.
	var target_shape := SphereShape3D.new()
	target_shape.radius = 0.18
	shape_node.shape = target_shape
	shape_node.transform = Transform3D.IDENTITY
	_build_hint()

func _can_use() -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if GameState.phase != GameState.Phase.ASCENT or not bool(player.get("controls_enabled")):
		return false
	var p := ground.to_local(player.global_position)
	return absf(p.x) < 5.9 and absf(p.z) < 9.0

# Called only after the player's ray hits the ground, not a pickup or a build slot.
func try_form_from_ground(target: Object) -> void:
	if not _can_use() or released or falling or target != ground or not player.is_on_floor():
		return
	if is_instance_valid(player.get("held_item")):
		return
	var item := StaticBody3D.new()
	item.name = "ExplorationSnowball"
	item.set_script(PICKUP)
	item.set("item_id", BALL_ID)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.10
	col.shape = shape
	item.add_child(col)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.94, 0.98, 1.0)
	material.roughness = 1.0
	mesh.material = material
	visual.mesh = mesh
	item.add_child(visual)
	add_child(item)
	if not bool(player.call("try_pickup", item)):
		item.queue_free()

func try_throw() -> bool:
	if not _can_use():
		return false
	var item := player.get("held_item") as Node3D
	if not is_instance_valid(item) or item.get("item_id") != BALL_ID:
		return false
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var direction := -camera.global_transform.basis.z.normalized()
	var start := camera.global_position + direction * 0.06
	player.set("held_item", null)
	player.set("pickup_parent", null)
	player.set("drop_requested", false)
	item.hide()
	item.queue_free()
	player.emit_signal("held_item_changed", null)
	var shot := PROJECTILE.new()
	add_child(shot)
	shot.setup(start, direction * 12.0, player, true)
	shot.impacted.connect(_on_snowball_impact)
	_play_sound(start, THROW_SOUND)
	return true

func _on_snowball_impact(collider: Object, at: Vector3, _damaging: bool) -> void:
	SNOW_PUFF.spawn(self, to_local(at), 16)
	_play_sound(at, HIT_SOUND)
	if collider == carrot and not released and not falling and GameState.phase == GameState.Phase.ASCENT:
		falling = true
		_release_carrot.call_deferred()

func _release_carrot() -> void:
	# A hit knocks the carrot out of the tree. No rigid-body drift or lost item.
	carrot.collision_layer = 0
	carrot.collision_mask = 0
	var shape_node := carrot.get_node("CollisionShape3D") as CollisionShape3D
	shape_node.shape = original_shape
	shape_node.transform = original_shape_transform
	var start := carrot.global_position
	var pop := create_tween().set_parallel(true)
	pop.tween_property(carrot, "global_position", start + Vector3(-0.28, 0.10, 0), 0.15).set_trans(Tween.TRANS_SINE)
	pop.tween_property(carrot, "rotation:z", 0.55, 0.15)
	await pop.finished
	var fall := create_tween().set_parallel(true)
	fall.tween_property(carrot, "global_position", landing, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(carrot, "rotation", Vector3.ZERO, 0.62).set_trans(Tween.TRANS_SINE)
	await fall.finished
	SNOW_PUFF.spawn(self, to_local(landing), 18)
	_play_sound(landing, HIT_SOUND)
	carrot.call("set_returned")
	released = true
	falling = false

func _play_sound(at: Vector3, stream: AudioStream) -> void:
	var audio := AudioStreamPlayer3D.new()
	add_child(audio)
	audio.global_position = at
	audio.stream = stream
	audio.unit_size = 2.0
	audio.max_distance = 16.0
	audio.volume_db = -7.0
	audio.finished.connect(audio.queue_free)
	audio.play()

func _build_hint() -> void:
	hint = Label.new()
	hint.name = "CarrotPuzzleHint"
	player.get_node("HUD").add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -80.0
	hint.offset_bottom = -54.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(hint):
		return
	if not _can_use() or released or falling or player.global_position.distance_to(target_tree.global_position) > 4.5:
		hint.hide()
		return
	var held := player.get("held_item") as Node3D
	var spanish: bool = LanguageManager.current_locale == "es"
	if is_instance_valid(held):
		if held.get("item_id") != BALL_ID:
			hint.hide()
			return
		hint.text = "Apunta a la zanahoria y lanza con clic izquierdo" if spanish else "Aim at the carrot and left click to throw"
	else:
		hint.text = "Mira a la nieve y pulsa E para formar una bola" if spanish else "Look at the snow and press E to make a snowball"
	hint.show()
