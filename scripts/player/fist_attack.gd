extends Node3D
## First-person melee, active only during the descent.
const CONTACT_TIME: float = 0.13
const SWING_TIME: float = 0.36
@export_range(0.5, 1.5, 0.05) var punch_range: float = 1.25

var player: CharacterBody3D
var fists: Array[Node3D] = []
var rest: Array[Vector3] = [Vector3(-0.24, -0.25, -0.48), Vector3(0.24, -0.25, -0.48)]
const HAND = preload("res://scenes/art/player/elf_hand.tscn")
var elapsed: float = -1.0
var hand_index: int = 0
var contact_done: bool = false

func _ready() -> void:
	for i in range(2):
		var fist := HAND.instantiate() as Node3D
		fist.name = "LeftFist" if i == 0 else "RightFist"
		add_child(fist)
		fist.position = rest[i]
		fist.call("configure", i == 1, GameState.skin_color, 1.0)
		fists.append(fist)
	hide()

func _can_attack() -> bool:
	return is_instance_valid(player) and GameState.phase == GameState.Phase.DESCENT and bool(player.get("controls_enabled")) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_instance_valid(player.get("held_item"))

func request_punch() -> void:
	if not _can_attack() or elapsed >= 0.0:
		return
	elapsed = 0.0
	contact_done = false

func _physics_process(delta: float) -> void:
	visible = _can_attack()
	if not visible:
		_reset_swing()
		return
	for fist in fists:
		fist.call("set_skin", GameState.skin_color)
	if elapsed < 0.0:
		return
	elapsed += delta
	# The fist extends to the centre of the view, then returns to guard.
	var extension: float
	if elapsed < CONTACT_TIME:
		extension = smoothstep(0.0, CONTACT_TIME, elapsed)
	else:
		extension = 1.0 - smoothstep(CONTACT_TIME, SWING_TIME, elapsed)
	var side: float = -1.0 if hand_index == 0 else 1.0
	fists[hand_index].position = rest[hand_index].lerp(Vector3(side * 0.035, -0.07, -0.86), extension)
	if not contact_done and elapsed >= CONTACT_TIME:
		contact_done = true
		_hit_target()
	if elapsed >= SWING_TIME:
		_reset_swing()
		hand_index = 1 - hand_index

func _reset_swing() -> void:
	elapsed = -1.0
	contact_done = false
	for i in range(fists.size()):
		fists[i].position = rest[i]

func _hit_target() -> void:
	# Unlike the visual X-ray, this physics ray stops at the first solid body.
	var camera := get_parent() as Camera3D
	var ray := player.get_node("Head/Camera3D/InteractionRay") as RayCast3D
	var origin: Vector3 = camera.global_position
	var end: Vector3 = origin - camera.global_transform.basis.z.normalized() * punch_range
	var query := PhysicsRayQueryParameters3D.create(origin, end, ray.collision_mask, [player.get_rid()])
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target: Object = hit.get("collider")
	if is_instance_valid(target) and target.has_method("punch_with_player"):
		target.call("punch_with_player", player)
