extends CharacterBody3D

signal held_item_changed(item: Node3D)

const FIST_ATTACK = preload("res://scripts/player/fist_attack.gd")
var fist_attack: Node3D
const CARRY_HANDS = preload("res://scripts/player/carry_hands.gd")

@export var speed: float = 3.0
@export var sprint_speed: float = 5.0
@export var jump_velocity: float = 3.5
@export var mouse_sensitivity: float = 0.0025

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var hold_point: Marker3D = $Head/Camera3D/HoldPoint

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var controls_enabled: bool = true
# Combat sets this only while collecting snow for the rifle.
var combat_reload_active: bool = false
var held_item: Node3D = null
var pickup_parent: Node3D = null
var pickup_transform: Transform3D = Transform3D.IDENTITY
var drop_requested: bool = false
# Assigned only in the level 1 clearing; other levels and combat are unchanged.
var exploration_snowballs: Node3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interaction_ray.add_exception(self)
	fist_attack = FIST_ATTACK.new()
	fist_attack.name = "FistAttack"
	fist_attack.set("player", self)
	$Head/Camera3D.add_child(fist_attack)
	var carry_view := CARRY_HANDS.new()
	carry_view.name = "CarryHands"
	carry_view.player = self
	hold_point.add_child(carry_view)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			if is_instance_valid(exploration_snowballs) and bool(exploration_snowballs.call("try_throw")):
				get_viewport().set_input_as_handled()
				return
			if GameState.phase == GameState.Phase.DESCENT:
				fist_attack.call("request_punch")
				get_viewport().set_input_as_handled()
				return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	if event.is_action_pressed("interact"):
		try_interact()
	if InputMap.has_action("drop_item"):
		if event.is_action_pressed("drop_item"):
			drop_requested = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		drop_requested = true


func _physics_process(delta: float) -> void:
	var can_move: bool = controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		if can_move and InputMap.has_action("jump") and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	var input_dir := Vector2.ZERO
	var current_speed: float = speed
	if can_move:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if not combat_reload_active and InputMap.has_action("sprint") and Input.is_action_pressed("sprint"):
			current_speed = sprint_speed
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	move_and_slide()
	if drop_requested:
		drop_requested = false
		if can_move:
			drop_held_item()


func try_interact() -> void:
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return
	var target: Object = interaction_ray.get_collider()
	if not is_instance_valid(target):
		return
	if target.has_method("interact_with_player"):
		target.call("interact_with_player", self)
	elif target.has_method("interact"):
		# Compatibilidad con el contrato anterior sin argumentos.
		target.call("interact")
	elif is_instance_valid(exploration_snowballs):
		exploration_snowballs.call("try_form_from_ground", target)


func try_pickup(item: Node3D) -> bool:
	if is_instance_valid(held_item) or not is_instance_valid(item):
		return false
	if not item.has_method("set_carried") or not item.has_method("set_placed"):
		return false
	pickup_parent = item.get_parent() as Node3D
	pickup_transform = item.transform
	item.call("set_carried")
	item.reparent(hold_point, false)
	item.transform = Transform3D.IDENTITY
	held_item = item
	held_item_changed.emit(held_item)
	return true


func try_place(required_id: StringName, point: Node3D) -> bool:
	if not is_instance_valid(held_item):
		return false
	if held_item.get("item_id") != required_id:
		return false
	var item := held_item
	item.reparent(point, false)
	item.transform = Transform3D.IDENTITY
	item.call("set_placed")
	pickup_parent = null
	held_item = null
	held_item_changed.emit(null)
	return true


func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	if not value:
		velocity.x = 0.0
		velocity.z = 0.0


# Q deja la pieza delante del duende, sobre una superficie válida.
# Se conserva StaticBody3D: no hay caída ni rodamiento físicos todavía.
func drop_held_item() -> void:
	if not is_instance_valid(held_item) or not is_instance_valid(pickup_parent):
		return
	var item := held_item as StaticBody3D
	if not is_instance_valid(item) or not item.has_method("set_returned"):
		return
	var shape_node := item.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return

	# Recuperar la orientación original de la pieza, no la inclinación de la cámara.
	var drop_basis: Basis = pickup_parent.global_transform.basis * pickup_transform.basis
	var shape_offset := Transform3D(drop_basis, Vector3.ZERO) * shape_node.transform
	var bounds: AABB = shape_offset * shape_node.shape.get_debug_mesh().get_aabb()
	var extent: float = maxf(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.z), absf(bounds.end.z)))
	var distance: float = maxf(0.75, 0.25 + extent + 0.12)
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space := get_world_3d().direct_space_state
	var mask: int = collision_mask | interaction_ray.collision_mask
	var exclude_rids: Array[RID] = [get_rid(), item.get_rid()]

	# Buscar suelo y comprobar que no se atraviesan muros ni se solapan cuerpos.
	var offsets: Array[float] = [0.0, 0.2, 0.4]
	for extra in offsets:
		var ahead: Vector3 = global_position + forward * (distance + extra)
		var floor_query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.45, ahead - Vector3.UP * 1.5, mask, exclude_rids)
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty():
			continue
		var floor_normal: Vector3 = floor_hit["normal"]
		if floor_normal.y < 0.7:
			continue
		var floor_position: Vector3 = floor_hit["position"]
		var drop_position: Vector3 = floor_position - Vector3.UP * bounds.position.y + Vector3.UP * 0.025
		var drop_transform := Transform3D(drop_basis, drop_position)

		var path_end: Vector3 = drop_position + bounds.get_center()
		var path_start := Vector3(global_position.x, path_end.y, global_position.z)
		var path_query := PhysicsRayQueryParameters3D.create(path_start, path_end, mask, exclude_rids)
		if not space.intersect_ray(path_query).is_empty():
			continue

		var overlap := PhysicsShapeQueryParameters3D.new()
		overlap.shape = shape_node.shape
		overlap.transform = drop_transform * shape_node.transform
		overlap.collision_mask = mask
		overlap.exclude = [item.get_rid()]
		if not space.intersect_shape(overlap, 1).is_empty():
			continue

		item.reparent(pickup_parent, false)
		item.global_transform = drop_transform
		item.call("set_returned")
		held_item = null
		pickup_parent = null
		held_item_changed.emit(null)
		return
	# Si no hay espacio seguro, conservar la pieza en las manos.
