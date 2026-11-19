extends Node3D
## Standalone arena test. The finale is intentionally not decided here.
signal combat_finished(victory: bool)
signal retry_requested
# When embedded, use the already existing player and clearing.
var embedded_player: CharacterBody3D
var santa_spawn: Vector3 = Vector3(0, 0, -4.5)
const RETRO_FX = preload("res://scenes/components/retro_effects.tscn")
const RUDOLPH = preload("res://scripts/levels/rudolph_combat.gd")
const HEAD_BREAK = preload("res://assets/audio/snow_head_break.wav")
const SNOW_PUFF = preload("res://scripts/components/snow_puff.gd")
var snowman_target: Node3D
var fallen_rudolph: Node3D
var rudolph: RUDOLPH
var snowman_broken: bool = false
const Projectile = preload("res://scripts/components/snowball_projectile.gd")
const Pickup = preload("res://scripts/components/pickup.gd")
const THROW_SOUND = preload("res://assets/audio/snowball_throw.wav")
const HIT_SOUND = preload("res://assets/audio/snowball_hit.wav")
const SNOWBALL_ID: StringName = &"combat_snowball"
const SANTA_HP := 5
const PLAYER_HP := 3
@export var play_intro := true
@export var santa_throw_interval: float = 2.5
@export var santa_windup: float = 0.8
@export var santa_projectile_speed: float = 7.0
@export var player_projectile_speed: float = 12.0
@export var santa_walk_speed: float = 1.55
@export var santa_dodge_speed: float = 4.0
@export var santa_dodge_duration: float = 0.36
@export var santa_dodge_cooldown: float = 2.6
var dodge_left: float = 0.0
var dodge_ready_in: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var dodge_recovery: float = 0.0
var strafe_clock: float = 0.0
var strafe_sign: float = 1.0
var stride: float = 0.0
# Visual-only articulation. The CharacterBody3D and its collider never sway.
var torso_pivot: Node3D
var free_arm: Node3D
var leg_pivots: Array[Node3D] = []
var gait_weight: float = 0.0
var gait_direction: Vector3 = Vector3.ZERO
var idle_time: float = 0.0
var throw_follow: float = 0.0
var hit_pose_time: float = 0.0
var hit_direction: Vector3 = Vector3.ZERO
const HIP_HEIGHT := 0.55
const FOLLOW_TIME := 0.38
const HIT_POSE_TIME := 0.34
var santa_rng := RandomNumberGenerator.new()
var rudolph_approach: Vector3 = Vector3.BACK
@onready var player = embedded_player if is_instance_valid(embedded_player) else $Player
@onready var camera: Camera3D = player.get_node("Head/Camera3D")
@onready var head: Node3D = player.get_node("Head")
@onready var hud: CanvasLayer = player.get_node("HUD")
@onready var arena: Node3D = $Arena
@onready var shots: Node3D = $Projectiles
var santa: CharacterBody3D
var model: Node3D
var arm: Node3D
var santa_ball: MeshInstance3D
var santa_hits := 0
var player_hits := 0
var active := false
var finished := false
var retry_pending: bool = false
var attack_clock := 1.0
var winding := false
var form_requested := false
var throw_requested := false
var overlay: CanvasLayer
var stats: Control
var santa_label: Label
var player_label: Label
var ammo_label: Label
var result_label: Label
var restart_btn: Button
var flash: ColorRect
var spanish: Translation
var duel_hands: Node3D
const SANTA_ART = preload("res://scenes/art/characters/santa.tscn")
const HAND = preload("res://scenes/art/player/elf_hand.tscn")
var hands_tween: Tween
var snow: StandardMaterial3D
var red: StandardMaterial3D
var dark: StandardMaterial3D
var cream: StandardMaterial3D
var bark: StandardMaterial3D
var pine: StandardMaterial3D

func _ready() -> void:
	GameState.phase = GameState.Phase.COMBAT
	if get_tree().get_first_node_in_group("makeshift_retro_fx") == null:
		add_child(RETRO_FX.instantiate())
	_register_translation()
	santa_rng.randomize()
	_build_arena()
	_build_santa()
	_build_rudolph()
	var facing: Vector3 = player.global_position
	facing.y = santa.global_position.y
	santa.look_at(facing, Vector3.UP, true)
	_build_duel_hands()
	_build_hud()
	player.held_item_changed.connect(_on_item_changed)
	player.call("set_controls_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.hide()
	stats.hide()
	if play_intro:
		_run_duel.call_deferred()
	else:
		# Keep retry immediate, with Santa in view.
		var gaze := santa.global_position + Vector3.UP * 1.6 - camera.global_position
		player.rotation.y = atan2(-gaze.x, -gaze.z)
		head.rotation.x = atan2(gaze.y, Vector2(gaze.x, gaze.z).length())
		_start_fight()

func _exit_tree() -> void:
	if is_instance_valid(embedded_player):
		if embedded_player.is_connected("held_item_changed", _on_item_changed):
			embedded_player.disconnect("held_item_changed", _on_item_changed)
		if is_instance_valid(duel_hands):
			duel_hands.hide()
			duel_hands.queue_free()
	if is_instance_valid(spanish):
		TranslationServer.remove_translation(spanish)

func _register_translation() -> void:
	spanish = Translation.new()
	spanish.locale = "es"
	var messages := {"DEFEAT SANTA":"DERROTA A SANTA", "Rudolph: avoid contact":"Rudolph: evita el contacto", "Santa: %d / 5":"Santa: %d / 5", "Elf: %d / 3":"Elfo: %d / 3", "E - Make snowball   |   Left click - Throw   |   Q - Drop":"E - Formar bola   |   Clic izq. - Lanzar   |   Q - Soltar", "Snowball ready":"Bola preparada", "Hands empty":"Manos libres", "VICTORY":"VICTORIA", "GAME OVER":"FIN DE LA PARTIDA", "Retry (R)":"Reintentar (R)"}
	for key in messages:
		spanish.add_message(StringName(key), StringName(messages[key]))
	TranslationServer.add_translation(spanish)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(santa_label):
		_update_hud()
		if finished:
			result_label.text = "VICTORY" if santa_hits >= SANTA_HP else "GAME OVER"

func _input(event: InputEvent) -> void:
	if finished and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_request_retry()
		return
	if not active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("interact"):
		form_requested = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		throw_requested = true
		get_viewport().set_input_as_handled()

func _request_retry() -> void:
	if retry_pending:
		return
	retry_pending = true
	if is_instance_valid(embedded_player):
		call_deferred("_emit_retry")
	else:
		get_tree().call_deferred("reload_current_scene")

func _emit_retry() -> void:
	retry_requested.emit()

func _physics_process(delta: float) -> void:
	if not active:
		return
	if form_requested:
		form_requested = false
		_form_ball()
	if throw_requested:
		throw_requested = false
		_throw_player()
	# Santa faces the small elf, then telegraphs each shot.
	var target: Vector3 = player.global_position
	target.y = santa.global_position.y
	if santa.global_position.distance_to(target) > 0.1:
		santa.look_at(target, Vector3.UP, true)
	var before: Vector3 = santa.global_position
	var pause_attack := _move_santa(delta)
	if not pause_attack:
		attack_clock -= delta
		if attack_clock <= 0.0:
			if not winding:
				winding = true
				attack_clock = maxf(0.2, santa_windup)
				santa_ball.show()
			else:
				winding = false
				attack_clock = maxf(0.2, santa_throw_interval - santa_windup)
				_throw_santa(true)
	_update_santa_pose(delta, santa.global_position - before)

# Move only with swept body collision; pause the throw clock during a dodge.
func _move_santa(delta: float) -> bool:
	dodge_ready_in = maxf(0.0, dodge_ready_in - delta)
	if dodge_left <= 0.0 and dodge_recovery <= 0.0 and dodge_ready_in <= 0.0:
		_try_dodge()
	if dodge_left > 0.0:
		var step := dodge_direction * santa_dodge_speed * minf(delta, dodge_left)
		dodge_left = maxf(0.0, dodge_left - delta)
		if not _santa_step(step):
			dodge_left = 0.0
		if dodge_left <= 0.0:
			dodge_recovery = 0.38
		return true
	if dodge_recovery > 0.0:
		dodge_recovery = maxf(0.0, dodge_recovery - delta)
		return true
	# Plant the feet during preparation and the first part of the follow-through.
	# The normal throw clock continues during the follow-through.
	if winding or attack_clock < 0.25 or throw_follow > 0.16:
		return false
	var toward: Vector3 = player.global_position - santa.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		return false
	var distance := toward.length()
	toward = toward.normalized()
	strafe_clock -= delta
	if strafe_clock <= 0.0:
		strafe_clock = santa_rng.randf_range(0.8, 1.65)
		if santa_rng.randf() < 0.55:
			strafe_sign *= -1.0
	var side := toward.cross(Vector3.UP).normalized() * strafe_sign
	var radial := 0.0
	if distance < 2.5:
		radial = -0.8
	elif distance > 6.2:
		radial = 0.7
	var desired := (side + toward * radial).normalized()
	for direction in [desired, -side, toward * -1.0]:
		var move_dir: Vector3 = direction
		var step := move_dir * santa_walk_speed * delta
		if _santa_step(step):
			return false
	return false

func _try_dodge() -> void:
	# Check actual incoming player snowballs, not mouse aim or button presses.
	for child in shots.get_children():
		var shot := child as Projectile
		if shot == null or shot.spent or not shot.damaging or shot.owner_rid != player.get_rid():
			continue
		var v := shot.velocity
		v.y = 0.0
		if v.length_squared() < 0.1:
			continue
		var to_santa := santa.global_position - shot.global_position
		to_santa.y = 0.0
		var time_to_cross := to_santa.dot(v) / v.length_squared()
		if time_to_cross < 0.17 or time_to_cross > 0.58:
			continue
		var miss := to_santa - v * time_to_cross
		if miss.length() > 0.60:
			continue
		var height := shot.global_position.y + shot.velocity.y * time_to_cross - 0.5 * shot.gravity * time_to_cross * time_to_cross
		if height < santa.global_position.y - 0.05 or height > santa.global_position.y + 1.95:
			continue
		var side := v.normalized().cross(Vector3.UP).normalized()
		if miss.dot(side) < 0.0:
			side = -side
		for candidate in [side, -side]:
			var move_dir: Vector3 = candidate
			var motion := move_dir * santa_dodge_speed * santa_dodge_duration
			if _santa_path_clear(motion):
				dodge_direction = move_dir
				dodge_left = santa_dodge_duration
				dodge_ready_in = santa_dodge_cooldown
				return
		# A wall or cover blocks both escape routes: no forced teleport.
		return

func _santa_path_clear(motion: Vector3) -> bool:
	var end := santa.global_position + motion
	if is_instance_valid(embedded_player):
		if absf(end.x) > 4.9 or end.z < -4.7 or end.z > 10.7:
			return false
	elif absf(end.x) > 10.0 or absf(end.z) > 10.0:
		return false
	return not santa.test_move(santa.global_transform, motion)

func _santa_step(motion: Vector3) -> bool:
	if not _santa_path_clear(motion):
		return false
	return santa.move_and_collide(motion) == null

func _build_santa_pose_rig() -> void:
	# Reparent the original rigid meshes at runtime. Preserve their world poses.
	# The seated Santa in the crash and the reusable art scene are untouched.
	var parts := model.get_children()
	torso_pivot = Node3D.new()
	torso_pivot.name = "AnimatedTorso"
	model.add_child(torso_pivot)
	torso_pivot.position.y = HIP_HEIGHT
	for i in range(2):
		var leg := Node3D.new()
		leg.name = "AnimatedLeg%d" % i
		model.add_child(leg)
		leg.position = Vector3(-0.19 if i == 0 else 0.19, HIP_HEIGHT, 0)
		leg_pivots.append(leg)
	for child in parts:
		if not child is Node3D:
			continue
		var n := child as Node3D
		var is_leg := false
		for i in range(2):
			if String(n.name) in ["Leg%d" % i, "Boot%d" % i, "BootCuff%d" % i]:
				n.reparent(leg_pivots[i], true)
				is_leg = true
				break
		if not is_leg:
			n.reparent(torso_pivot, true)

func _update_santa_pose(delta: float, displacement: Vector3) -> void:
	# Steps follow actual movement; no walking on the spot against cover.
	idle_time += delta
	var local_motion: Vector3 = santa.global_transform.basis.inverse() * displacement
	local_motion.y = 0.0
	var distance := local_motion.length()
	var moving := distance > 0.0005
	var dodging := dodge_left > 0.0 or (dodge_recovery > 0.0 and moving)
	var blend := 1.0 - exp(-delta * 13.0)
	var move_weight := clampf(distance / maxf(delta * santa_walk_speed, 0.001), 0.0, 1.0)
	gait_weight = lerpf(gait_weight, move_weight, blend)
	if moving:
		gait_direction = gait_direction.lerp(local_motion.normalized(), blend)
		stride = fmod(stride + distance * TAU / (0.96 if dodging else 0.72), TAU)
	var wave := sin(stride) * gait_weight
	for i in range(leg_pivots.size()):
		var leg := leg_pivots[i]
		var phase := stride + float(i) * PI
		var step := sin(phase) * gait_weight
		var lift := maxf(cos(phase), 0.0) * gait_weight * (0.10 if dodging else 0.055)
		var leg_x := -0.19 if i == 0 else 0.19
		var spread := 0.065 if dodging else 0.0
		var foot_target := Vector3(leg_x + signf(leg_x) * spread, HIP_HEIGHT + lift, 0.0)
		foot_target += gait_direction * step * (0.095 if dodging else 0.045)
		leg.position = leg.position.lerp(foot_target, blend)
		var leg_rot := Vector3(-gait_direction.z * step * 0.32, 0.0, gait_direction.x * step * 0.27)
		leg.rotation = leg.rotation.lerp(leg_rot, blend)

	var lean := Vector3(gait_direction.z * gait_weight * 0.09, wave * 0.045, -gait_direction.x * gait_weight * 0.12)
	var torso_y := HIP_HEIGHT + absf(wave) * 0.019 + sin(idle_time * 2.1) * 0.006
	var right_pose := Vector3(wave * 0.27, 0, 0.08)
	var left_pose := Vector3(-wave * 0.27, 0, -0.21)
	if dodging or dodge_recovery > 0.0:
		var direction: Vector3 = santa.global_transform.basis.inverse() * dodge_direction
		var weight := 1.0 if dodging else clampf(dodge_recovery / 0.38, 0.0, 1.0)
		lean.x += direction.z * weight * 0.20
		lean.z -= direction.x * weight * 0.27
		torso_y -= 0.065 * weight
		left_pose = Vector3(-0.4, 0.0, -0.46 * weight - 0.21)
		right_pose = Vector3(-0.30, 0.0, 0.44 * weight + 0.08)
	if winding:
		# First bring the ball up, then cock the throwing arm and swing forward.
		var progress := clampf(1.0 - attack_clock / maxf(0.2, santa_windup), 0.0, 1.0)
		if progress < 0.30:
			var t := smoothstep(0.0, 0.30, progress)
			right_pose = Vector3(lerpf(0.0, -0.85, t), 0.0, 0.0)
			left_pose = Vector3(-0.80 * t, 0.0, 0.12 * t - 0.21)
			torso_y -= 0.04 * t
		elif progress < 0.72:
			var t := smoothstep(0.30, 0.72, progress)
			right_pose = Vector3(lerpf(-0.85, 0.80, t), 0.0, 0.16 * t)
			left_pose = Vector3(-0.8 + t * 0.30, 0.0, -0.21 - 0.17 * t)
			lean.y -= 0.16 * t
		else:
			var t := smoothstep(0.72, 1.0, progress)
			right_pose = Vector3(lerpf(0.80, -1.38, t), 0.0, 0.16 * (1.0 - t))
			left_pose = Vector3(-0.50 + 0.25 * t, 0.0, -0.38 + t * 0.17)
			lean.x += 0.13 * t
			lean.y += lerpf(-0.16, 0.12, t)
	elif throw_follow > 0.0:
		var elapsed := FOLLOW_TIME - throw_follow
		if elapsed < 0.12:
			right_pose = Vector3(lerpf(-1.38, -1.92, smoothstep(0.0, 0.12, elapsed)), 0.0, 0.0)
		else:
			right_pose = Vector3(lerpf(-1.92, 0.0, smoothstep(0.12, FOLLOW_TIME, elapsed)), 0.0, 0.08)
		lean.x += 0.16 * (throw_follow / FOLLOW_TIME)
		lean.y += 0.12 * (throw_follow / FOLLOW_TIME)
	if hit_pose_time > 0.0:
		var progress := 1.0 - hit_pose_time / HIT_POSE_TIME
		var pulse := sin(progress * PI) * (1.0 - 0.3 * progress)
		lean.x += hit_direction.z * pulse * 0.26
		lean.z -= hit_direction.x * pulse * 0.26
		left_pose.x -= pulse * 0.30
		torso_y -= pulse * 0.045
	torso_pivot.position.y = lerpf(torso_pivot.position.y, torso_y, blend)
	torso_pivot.rotation = torso_pivot.rotation.lerp(lean, blend)
	# The throwing arm must reach its release angle even with a short windup.
	var arm_blend := 1.0 - exp(-delta * (28.0 if winding or throw_follow > 0.0 else 13.0))
	arm.rotation = arm.rotation.lerp(right_pose, arm_blend)
	free_arm.rotation = free_arm.rotation.lerp(left_pose, blend)
	throw_follow = maxf(0.0, throw_follow - delta)
	hit_pose_time = maxf(0.0, hit_pose_time - delta)

func _form_ball() -> void:
	if is_instance_valid(player.held_item):
		return
	# Prefer a previously dropped snowball if the player is looking at one.
	var ray: RayCast3D = player.interaction_ray
	ray.force_raycast_update()
	if ray.is_colliding():
		var hit = ray.get_collider()
		if is_instance_valid(hit) and hit.has_method("set_carried") and hit.get("item_id") == SNOWBALL_ID:
			player.call("try_interact")
			return
	if not player.is_on_floor():
		return
	var item := StaticBody3D.new()
	item.set_script(Pickup)
	item.set("item_id", SNOWBALL_ID)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.10
	col.shape = shape
	item.add_child(col)
	_sphere(item, Vector3.ZERO, 0.10, snow)
	arena.add_child(item)
	item.global_position = player.global_position + Vector3.UP * 0.1
	if not player.call("try_pickup", item):
		item.queue_free()

func _throw_player() -> void:
	var item = player.held_item
	if not is_instance_valid(item) or item.get("item_id") != SNOWBALL_ID:
		return
	var direction := -camera.global_transform.basis.z.normalized()
	player.held_item = null
	player.pickup_parent = null
	item.queue_free()
	player.held_item_changed.emit(null)
	_animate_throw()
	_spawn_shot(camera.global_position + direction * 0.06, direction * player_projectile_speed, player, true)

func _throw_santa(damage: bool) -> void:
	# Release from the animated hand, not from the body centre.
	if damage:
		arm.rotation = Vector3(-1.38, 0.0, 0.0)
		throw_follow = FOLLOW_TIME
	var start := santa_ball.global_position
	var target: Vector3 = player.global_position + Vector3.UP * 0.55
	var diff := target - start
	var duration := diff.length() / maxf(1.0, santa_projectile_speed)
	var initial := diff / maxf(duration, 0.05) + Vector3.UP * (1.2 * duration)
	santa_ball.hide()
	if not damage:
		var follow := create_tween()
		follow.tween_property(arm, "rotation:x", -1.85, 0.12)
		follow.tween_property(arm, "rotation:x", 0.0, 0.26)
	_spawn_shot(start, initial, santa, damage)

func _spawn_shot(start: Vector3, initial: Vector3, shooter: CollisionObject3D, damage: bool) -> void:
	var shot := Projectile.new()
	shots.add_child(shot)
	shot.setup(start, initial, shooter, damage)
	shot.impacted.connect(_on_impact.bind(shooter))
	_sound(start, THROW_SOUND)

func _on_impact(collider: Object, at: Vector3, damaging: bool, shooter: CollisionObject3D) -> void:
	_snow_burst(at)
	_sound(at, HIT_SOUND)
	if not active or not damaging or finished:
		return
	if collider == santa and shooter == player:
		santa_hits += 1
		get_tree().call_group("makeshift_retro_fx", "pulse", 0.55, false)
		if santa_hits >= SANTA_HP:
			_finish(true)
		else:
			var away: Vector3 = santa.global_position - player.global_position
			away.y = 0.0
			hit_direction = santa.global_transform.basis.inverse() * away.normalized()
			hit_pose_time = HIT_POSE_TIME
	elif collider == player and shooter == santa:
		player_hits += 1
		var fx := get_tree().get_first_node_in_group("makeshift_retro_fx")
		if is_instance_valid(fx) and bool(fx.get("effects_enabled")) and bool(fx.get("event_effects")):
			fx.call("pulse", 0.85, true)
		else:
			flash.color.a = 0.45
			create_tween().tween_property(flash, "color:a", 0.0, 0.40)
		if player_hits >= PLAYER_HP:
			_finish(false)
	_update_hud()

func _run_duel() -> void:
	# Both characters look at one another, prepare, and exchange a scripted shot.
	var gaze := santa.global_position + Vector3.UP * 1.6 - camera.global_position
	player.rotation.y = atan2(-gaze.x, -gaze.z)
	head.rotation.x = atan2(gaze.y, Vector2(gaze.x, gaze.z).length())
	await get_tree().create_timer(1.0, false).timeout
	await _rudolph_reveal()
	await _look_at(santa.global_position + Vector3.UP * 1.6, 0.55)
	var form := create_tween().set_parallel(true)
	form.tween_property(head, "rotation:x", -0.55, 0.48)
	form.tween_property(torso_pivot, "position:y", HIP_HEIGHT - 0.07, 0.48)
	form.tween_property(torso_pivot, "rotation:x", 0.22, 0.48)
	form.tween_property(arm, "rotation:x", -0.72, 0.48)
	form.tween_property(free_arm, "rotation:x", -0.72, 0.48)
	await form.finished
	var visual := _sphere(player.hold_point, Vector3.ZERO, 0.10, snow)
	duel_hands.show()
	santa_ball.show()
	await get_tree().create_timer(0.35, false).timeout
	var raise := create_tween().set_parallel(true)
	raise.tween_property(head, "rotation:x", atan2(gaze.y, Vector2(gaze.x, gaze.z).length()), 0.50)
	raise.tween_property(torso_pivot, "position:y", HIP_HEIGHT, 0.50)
	raise.tween_property(torso_pivot, "rotation:x", 0.0, 0.50)
	raise.tween_property(arm, "rotation:x", -1.25, 0.50)
	raise.tween_property(free_arm, "rotation:x", 0.0, 0.50)
	await raise.finished
	await get_tree().create_timer(0.35, false).timeout
	visual.queue_free()
	_animate_throw()
	var start := camera.global_position
	var dest := santa.global_position + Vector3.UP * 1.25
	var flight := (dest - start).length() / player_projectile_speed
	_spawn_shot(start, (dest - start) / flight + Vector3.UP * 1.2 * flight, player, false)
	_throw_santa(false)
	await get_tree().create_timer(1.30, false).timeout
	for shot in shots.get_children():
		shot.queue_free()
	_start_fight()

func _start_fight() -> void:
	# On retry the snowman stays broken; no duplicate debris or cutscene.
	if is_instance_valid(fallen_rudolph):
		fallen_rudolph.hide()
	rudolph.show()
	rudolph.start_fight()
	active = true
	player.call("set_controls_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show()
	stats.show()
	_update_hud()

func _finish(victory: bool) -> void:
	if finished:
		return
	active = false
	finished = true
	if is_instance_valid(rudolph):
		rudolph.stop_fight()
	winding = false
	form_requested = false
	throw_requested = false
	santa_ball.hide()
	if is_instance_valid(hands_tween):
		hands_tween.kill()
	duel_hands.hide()
	for shot in shots.get_children():
		shot.set_physics_process(false)
		shot.queue_free()
	player.call("set_controls_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if victory:
		create_tween().tween_property(model, "rotation:z", -PI * 0.48, 0.55)
	result_label.text = "VICTORY" if victory else "GAME OVER"
	result_label.show()
	restart_btn.show()
	combat_finished.emit(victory)

func _on_item_changed(_item: Node3D) -> void:
	if is_instance_valid(hands_tween):
		hands_tween.kill()
	duel_hands.position = Vector3.ZERO
	duel_hands.visible = is_instance_valid(player.held_item)
	if duel_hands.visible:
		duel_hands.position.y = -0.22
		hands_tween = create_tween()
		hands_tween.tween_property(duel_hands, "position:y", 0.0, 0.18)
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(santa_label):
		return
	santa_label.text = tr("Santa: %d / 5") % (SANTA_HP - santa_hits)
	player_label.text = tr("Elf: %d / 3") % (PLAYER_HP - player_hits)
	ammo_label.text = "Snowball ready" if is_instance_valid(player.held_item) else "Hands empty"

func _label(parent: Control, value: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	parent.add_child(l)
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_hud() -> void:
	var objective: Label = player.get_node("HUD/Objective")
	objective.text = "DEFEAT SANTA"
	objective.add_theme_color_override("font_color", Color.WHITE)
	overlay = CanvasLayer.new()
	overlay.layer = 5
	add_child(overlay)
	flash = ColorRect.new()
	overlay.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.75, 0.04, 0.04, 0.0)
	stats = Control.new()
	overlay.add_child(stats)
	stats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	stats.add_child(top)
	top.position = Vector2(24, 62)
	santa_label = _label(top, "", 24, Color(1,0.68,0.64))
	player_label = _label(top, "", 22)
	ammo_label = _label(top, "", 18, Color(0.8,0.95,1))
	_label(top, "Rudolph: avoid contact", 18, Color(1,0.65,0.52))
	var bottom := Label.new()
	stats.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -70
	bottom.offset_bottom = -42
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_theme_color_override("font_shadow_color", Color.BLACK)
	bottom.add_theme_constant_override("shadow_offset_x", 2)
	bottom.text = "E - Make snowball   |   Left click - Throw   |   Q - Drop"
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	stats.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	center.add_child(column)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_label = _label(column, "", 54)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_btn = Button.new()
	column.add_child(restart_btn)
	restart_btn.text = "Retry (R)"
	restart_btn.pressed.connect(_request_retry)
	result_label.hide()
	restart_btn.hide()

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _mesh(parent: Node3D, pos: Vector3, geometry: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = geometry
	mi.material_override = material
	parent.add_child(mi)
	mi.position = pos
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, material: Material, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 9
	s.rings = 5
	var mi := _mesh(parent, pos, s, material)
	mi.scale = stretch
	return mi

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = dimensions
	return _mesh(parent, pos, b, material)

func _solid(pos: Vector3, dimensions: Vector3, material: Material, visible_mesh: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	arena.add_child(body)
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	col.shape = shape
	body.add_child(col)
	if visible_mesh:
		_box(body, Vector3.ZERO, dimensions, material)
	return body

func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 7
	return _mesh(parent, pos, m, material)

func _build_arena() -> void:
	snow = _mat(Color(0.82, 0.89, 0.95))
	red = _mat(Color(0.62, 0.055, 0.055))
	dark = _mat(Color(0.065, 0.055, 0.05))
	cream = _mat(Color(0.95, 0.90, 0.78))
	bark = _mat(Color(0.28, 0.15, 0.09))
	pine = _mat(Color(0.09, 0.24, 0.18))
	if is_instance_valid(embedded_player):
		# Existing snow, walls, snowman and sleigh remain. Add only two cover rocks.
		for p in [Vector3(3.6, 0.43, 2.8), Vector3(-4.55, 0.48, -1.7)]:
			var rock := _solid(p, Vector3(1.15, 0.90, 1.10), dark, false)
			_sphere(rock, Vector3.ZERO, 0.61, _mat(Color(0.40, 0.46, 0.52)), Vector3(1.0, 0.78, 0.95))
		return
	_solid(Vector3(0,-0.2,0), Vector3(24,0.4,24), snow)
	for side in [-1, 1]:
		_solid(Vector3(side*12, 3, 0), Vector3(0.5,6,24), dark, false)
		_solid(Vector3(0, 3, side*12), Vector3(24,6,0.5), dark, false)
	if not is_instance_valid(snowman_target):
		snowman_target = Node3D.new()
		snowman_target.name = "TestSnowman"
		arena.add_child(snowman_target)
		snowman_target.position = Vector3(0, 0, -0.55)
		_sphere(snowman_target, Vector3(0, 0.32, 0), 0.32, snow)
		_sphere(snowman_target, Vector3(0, 0.78, 0), 0.23, snow)
	# Cover is offset from the starting duel sightline.
	for p in [Vector3(-2.7,0.55,0.0),Vector3(3.0,0.50,-0.7),Vector3(-4.0,0.55,-5.0),Vector3(4.2,0.50,4.0)]:
		var cover := _solid(p, Vector3(1.35,1.1,1.25), _mat(Color(0.36,0.42,0.46)), false)
		_sphere(cover, Vector3.ZERO, 0.70, _mat(Color(0.40,0.46,0.52)), Vector3(1.0,0.85,0.95))
	# Crashed sleigh, usable as cover.
	var sleigh := _solid(Vector3(-5.6,0.52,3.8), Vector3(2.8,1.05,1.3), red)
	_box(sleigh, Vector3(0,0.58,0),Vector3(2.85,0.12,1.39),cream)
	for side in [-1,1]:
		_box(sleigh, Vector3(0,-0.39,side*0.62), Vector3(3.1,0.15,0.12),bark)
	for side in [-1,1]:
		for i in range(7):
			var p := Vector3(side*(9.4 + 0.35*sin(i*2.0)), 0.0, -9+3*i)
			var trunk := _solid(p+Vector3.UP*1.2,Vector3(0.38,2.4,0.38),bark)
			for j in range(3):
				_cone(trunk,Vector3(0,0.25+j*0.65,0),1.15-j*0.24,1.5,pine)
	for i in range(7):
		var p := Vector3(-9+3*i,0,-10)
		var trunk := _solid(p+Vector3.UP*1.2,Vector3(0.38,2.4,0.38),bark)
		_cone(trunk,Vector3(0,0.7,0),1.25,2.7,pine)

func _build_duel_hands() -> void:
	duel_hands = Node3D.new()
	duel_hands.name = "DuelHands"
	player.hold_point.add_child(duel_hands)
	for i in range(2):
		var hand := HAND.instantiate() as Node3D
		duel_hands.add_child(hand)
		var side := -1.0 if i == 0 else 1.0
		hand.position = Vector3(side * 0.13, -0.09, 0.10)
		hand.rotation = Vector3(-0.25, side * 0.30, -side * 0.12)
		hand.call("configure", i == 1, &"green", 0.65)
	duel_hands.hide()

func _animate_throw() -> void:
	if is_instance_valid(hands_tween):
		hands_tween.kill()
	duel_hands.position = Vector3.ZERO
	duel_hands.show()
	hands_tween = create_tween()
	hands_tween.tween_property(duel_hands, "position", Vector3(0.0, 0.10, -0.14), 0.10)
	hands_tween.tween_property(duel_hands, "position", Vector3(0.0, -0.34, 0.10), 0.16)
	hands_tween.tween_callback(_finish_throw_pose)

func _finish_throw_pose() -> void:
	duel_hands.position = Vector3.ZERO
	duel_hands.visible = is_instance_valid(player.held_item)

func _build_santa() -> void:
	santa = CharacterBody3D.new()
	santa.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	arena.add_child(santa)
	santa.name = "Santa"
	santa.position = santa_spawn + Vector3.UP * 0.035
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.85
	collider.shape = shape
	collider.position.y = 0.925
	santa.add_child(collider)
	model = SANTA_ART.instantiate() as Node3D
	santa.add_child(model)
	arm = model.get_node("ThrowArm") as Node3D
	free_arm = model.get_node("LeftArm") as Node3D
	_build_santa_pose_rig()
	santa_ball = _sphere(arm,Vector3(0,-0.48,0.12),0.10,snow)
	santa_ball.hide()

func _snow_burst(at: Vector3) -> void:
	for i in range(7):
		var chip := _sphere(arena,Vector3.ZERO,0.034,snow)
		chip.global_position = at
		var end := at + Vector3(cos(i*2.3)*0.35,0.15+0.1*sin(i),sin(i*2.3)*0.35)
		var t := create_tween().set_parallel(true)
		t.tween_property(chip,"global_position",end,0.22)
		t.tween_property(chip,"scale",Vector3.ZERO,0.22)
		t.chain().tween_callback(chip.queue_free)

func _sound(at: Vector3, stream: AudioStream) -> void:
	var audio := AudioStreamPlayer3D.new()
	arena.add_child(audio)
	audio.global_position = at
	audio.stream = stream
	audio.unit_size = 3.0
	audio.max_distance = 25.0
	audio.finished.connect(audio.queue_free)
	audio.play()


func _build_rudolph() -> void:
	rudolph = RUDOLPH.new()
	rudolph.name = "RudolphEnemy"
	rudolph.player = player
	rudolph.player_touched.connect(_rudolph_hit)
	arena.add_child(rudolph)
	# The fallen model is already gone when the elf returns. Never show it standing up.
	if is_instance_valid(fallen_rudolph):
		fallen_rudolph.hide()
	rudolph.global_position = Vector3(2.4, 0.0, 0.5) if is_instance_valid(embedded_player) else Vector3(4.4, 0.0, 1.6)
	if play_intro and is_instance_valid(snowman_target):
		# Present in the clearing from the very first frame of the duel.
		rudolph_approach = snowman_target.global_position - player.global_position
		rudolph_approach.y = 0.0
		if rudolph_approach.length_squared() < 0.001:
			rudolph_approach = Vector3.BACK
		rudolph_approach = rudolph_approach.normalized()
		rudolph.global_position = snowman_target.global_position + rudolph_approach * 2.35
		rudolph.global_position.y = 0.0
		rudolph.face(snowman_target.global_position)
	else:
		rudolph.face(player.global_position)

func _rudolph_hit() -> void:
	if not active or finished:
		return
	player_hits = PLAYER_HP
	get_tree().call_group("makeshift_retro_fx", "pulse", 1.0, true)
	flash.color.a = 0.5
	create_tween().tween_property(flash, "color:a", 0.0, 0.45)
	_update_hud()
	_finish(false)

func _look_at(point: Vector3, duration: float) -> void:
	var gaze := point - camera.global_position
	var yaw := atan2(-gaze.x, -gaze.z)
	var pitch := atan2(gaze.y, Vector2(gaze.x, gaze.z).length())
	var turn := create_tween().set_parallel(true)
	turn.tween_property(player, "rotation:y", player.rotation.y + wrapf(yaw - player.rotation.y, -PI, PI), duration).set_trans(Tween.TRANS_SINE)
	turn.tween_property(head, "rotation:x", clampf(pitch, -1.35, 1.35), duration).set_trans(Tween.TRANS_SINE)
	await turn.finished

func _rudolph_reveal() -> void:
	if not is_instance_valid(snowman_target):
		return
	# Never hide, show, or reposition Rudolph here. He runs from where he
	# has been standing since _build_rudolph, behind the actual snowman.
	var target := snowman_target.global_position
	var impact := target + rudolph_approach * 0.85
	impact.y = 0.0
	var stop := target - rudolph_approach * 0.95
	stop.y = 0.0
	rudolph.face(target)
	await _look_at(target + Vector3.UP * 0.65, 0.20)
	rudolph.cinematic_running = true
	var rush := create_tween()
	rush.tween_property(rudolph, "global_position", impact, 0.29).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await rush.finished
	_smash_snowman()
	var follow := create_tween()
	follow.tween_property(rudolph, "global_position", stop, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await follow.finished
	rudolph.cinematic_running = false
	rudolph._reset_pose()
	rudolph.face(player.global_position)
	await _look_at(rudolph.global_position + Vector3.UP * 1.05, 0.26)
	await get_tree().create_timer(0.28, false).timeout

func _smash_snowman() -> void:
	if snowman_broken or not is_instance_valid(snowman_target):
		return
	snowman_broken = true
	var at := snowman_target.global_position
	_disable_snowman_collisions(snowman_target)
	snowman_target.hide()
	# Put debris outside the hidden snowman subtree, persistent in the clearing.
	var debris := Node3D.new()
	debris.name = "RudolphSnowmanDebris"
	snowman_target.get_parent().add_child(debris)
	debris.global_position = at
	_sound(at + Vector3.UP * 0.4, HEAD_BREAK)
	SNOW_PUFF.spawn(debris, Vector3(0, 0.46, 0), 70)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8451
	for i in range(24):
		var a := float(i) * TAU / 24.0 + rng.randf_range(-0.12, 0.12)
		var offset := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.28, 1.0)
		var radius := rng.randf_range(0.055, 0.14)
		var chip := _sphere(debris, Vector3(0, rng.randf_range(0.25, 0.95), 0), radius, snow)
		var landing := offset + Vector3.UP * radius * 0.55
		var t := chip.create_tween()
		t.tween_property(chip, "position", offset * 0.52 + Vector3.UP * rng.randf_range(0.35, 0.95), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(chip, "position", landing, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.parallel().tween_property(chip, "scale:y", 0.58, 0.32)

func _disable_snowman_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.set_deferred("collision_layer", 0)
		node.set_deferred("collision_mask", 0)
	for child in node.get_children():
		_disable_snowman_collisions(child)
