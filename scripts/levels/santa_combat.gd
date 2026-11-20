extends Node3D
## Standalone/embedded boss fight and provisional ending cinematics.
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
const RUDOLPH_HP := 12
const RIFLE_ID: StringName = &"combat_snow_rifle"
const AIR = preload("res://scripts/levels/rudolph_air.gd")
var air: AIR
const LASER_CHARGE = preload("res://assets/audio/boss/laser_charge.wav")
const LASER_FIRE = preload("res://assets/audio/boss/laser_fire.wav")
const HEAVY_IMPACT = preload("res://assets/audio/boss/heavy_impact.wav")
const RIFLE_FIRE = preload("res://assets/audio/boss/rifle_fire.wav")
const ASCENSION = preload("res://assets/audio/boss/ascension.wav")
const ELF_LAUGH = preload("res://assets/audio/boss/elf_evil_laugh.wav")
const SANTA_HO_HO = preload("res://assets/audio/boss/santa_ho_ho.wav")
@export_range(2.0, 20.0, 0.5) var santa_laugh_min_interval: float = 5.0
@export_range(2.0, 30.0, 0.5) var santa_laugh_max_interval: float = 9.0
var santa_voice: AudioStreamPlayer3D
var santa_laugh_clock: float = 0.0
const BOSS_MUSIC = preload("res://scripts/levels/boss_music.gd")
var boss_music: BOSS_MUSIC
var camera_base_offset: Vector2 = Vector2.ZERO
var shake_strength: float = 0.0
var shake_clock: float = 0.0
var shake_duration: float = 0.0
var rise_origin: Vector3
var rise_destination: Vector3
var transition_light: OmniLight3D
var phase_two: bool = false
var rudolph_hits: int = 0
var rifle: StaticBody3D
var santa_rifle: Node3D
var rifle_clock: float = 0.0
@export_range(1, 30, 1) var rifle_magazine: int = 6
@export_range(0.2, 5.0, 0.1) var rifle_reload_duration: float = 1.6
var rifle_ammo: int = 0
var reload_remaining: float = 0.0
var reload_bar: ProgressBar
var snow_ground: StaticBody3D
const RELOAD_SOUND = preload("res://assets/audio/ambience/snow_step_02.wav")
var boss_bar: ProgressBar
var warning_label: Label
var control_label: Label
@export var play_intro := true
@export var santa_throw_interval: float = 1.55
@export var santa_windup: float = 0.65
@export var santa_projectile_speed: float = 13.0
@export_range(0.10, 0.50, 0.01) var santa_burst_spacing: float = 0.18
@export_range(0.6, 3.0, 0.05) var giant_windup: float = 1.40
@export_range(0.4, 2.0, 0.05) var giant_flight_time: float = 0.85
@export_range(0.8, 3.5, 0.1) var giant_radius: float = 2.0
@export_range(0.4, 3.0, 0.05) var giant_recovery: float = 1.65
const GIANT_BALL_RADIUS: float = 0.43
enum SantaAttack { WAIT, BURST, GIANT_WINDUP, GIANT_FLIGHT, GIANT_RECOVERY, MELEE_WINDUP, MELEE_RECOVERY }
var breakables: Dictionary = {}
var melee_cooldown: float = 0.0
var melee_target: Vector3 = Vector3.ZERO
var enraged: bool = false
const STORM_SNOW = preload("res://scenes/art/level_01/snowfall.tscn")
var storm: CPUParticles3D
var storm_env: Environment
var old_fog_enabled: bool = false
var old_fog_density: float = 0.0
var old_fog_color: Color
var santa_attack: int = SantaAttack.WAIT
var next_giant: bool = false
var burst_remaining: int = 0
var giant_ball: MeshInstance3D
var giant_marker: Node3D
var giant_target: Vector3 = Vector3.ZERO
var giant_launch: Vector3 = Vector3.ZERO
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
# Brief protection against repeated ordinary hits, never against lethal attacks.
var damage_grace: float = 0.0
const DAMAGE_GRACE: float = 0.45
var active := false
var finished := false
var retry_pending: bool = false
var ending_ready: bool = false
var ending_victory: bool = false
var ending_camera_saved: bool = false
var ending_camera_position: Vector3
var ending_camera_rotation: Vector3
var ending_shade: ColorRect
var ending_panel: CenterContainer
var ending_subtitle: Label
var menu_btn: Button
const MENU_SCENE := "res://main_menu.tscn"
var ending_menu_path: String = ""
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
	boss_music = BOSS_MUSIC.new()
	boss_music.name = "BossMusic"
	add_child(boss_music)
	GameState.phase = GameState.Phase.COMBAT
	camera_base_offset = Vector2(camera.h_offset, camera.v_offset)
	if get_tree().get_first_node_in_group("makeshift_retro_fx") == null:
		add_child(RETRO_FX.instantiate())
	_register_translation()
	santa_rng.randomize()
	_build_arena()
	_register_world_cover()
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
	if is_instance_valid(camera):
		camera.h_offset = camera_base_offset.x
		camera.v_offset = camera_base_offset.y
		if ending_camera_saved:
			camera.position = ending_camera_position
			camera.rotation = ending_camera_rotation
	_restore_cover()
	_stop_storm()
	# Release the sprint lock even if the arena is removed during reload.
	if is_instance_valid(player):
		player.set("combat_reload_active", false)
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
	var messages := {"DEFEAT SANTA":"DERROTA A SANTA", "Rudolph: avoid contact":"Rudolph: evita el contacto", "Santa: %d / 5":"Santa: %d / 5", "Elf: %d / 3":"Elfo: %d / 3", "E - Make snowball   |   Left click - Throw   |   Q - Drop":"E - Formar bola   |   Clic izq. - Lanzar   |   Q - Soltar", "Snowball ready":"Bola preparada", "Hands empty":"Manos libres", "VICTORY":"VICTORIA", "GAME OVER":"FIN DE LA PARTIDA", "Retry (R)":"Reintentar (R)", "DEFEAT RUDOLPH":"DERROTA A RUDOLPH", "Rudolph: %d / 12":"Rudolph: %d / 12", "Pick up Santa’s rifle":"Recoge el rifle de Santa", "Snow rifle ready":"Rifle de nieve preparado", "Avoid the laser and dive":"Esquiva el láser y los picados", "E - Pick up rifle   |   Left click - Fire":"E - Recoger rifle   |   Clic izq. - Disparar", "Ammo: %d / %d":"Munición: %d / %d", "Reloading snow... %d%%":"Recargando nieve... %d%%", "E looking at snow - Reload   |   Left click - Fire":"E mirando a la nieve - Recargar   |   Clic izq. - Disparar", "Empty! Look at snow and press E":"¡Sin munición! Mira a la nieve y pulsa E", "Look at snow to reload":"Mira a la nieve para recargar", "Santa: giant snowball! Leave the circle!":"¡Bola gigante de Santa! ¡Sal del círculo!"}
	messages.merge({"Santa is enraged!":"¡Santa está enfurecido!", "Santa: rifle strike!":"¡Santa: golpe de culata!", "Rudolph: sweeping laser! Take cover!":"¡Láser de barrido! ¡Busca cobertura!", "Rudolph: jump over the shockwave!":"¡Salta la onda expansiva!", "Rudolph: aim at the glowing nose!":"¡Apunta a la nariz luminosa!", "Rudolph: dive! Leave the circle!":"¡Picado! ¡Sal del círculo!", "Rudolph interrupted!":"¡Rudolph interrumpido!"})
	messages.merge({"Replay fight (R)":"Repetir combate (R)", "Main menu":"Menú principal", "CHRISTMAS IS OVER":"LA NAVIDAD HA TERMINADO", "Try again":"Inténtalo de nuevo"})
	messages.merge({"Rudolph: charge incoming!":"¡Rudolph prepara una embestida!", "Rudolph: dodge sideways!":"¡Rudolph: esquiva hacia un lado!"})
	for key in messages:
		spanish.add_message(StringName(key), StringName(messages[key]))
	TranslationServer.add_translation(spanish)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(santa_label):
		_update_hud()
		if ending_ready:
			_update_ending_text()

func _input(event: InputEvent) -> void:
	if ending_ready and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
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
	if retry_pending or not ending_ready:
		return
	retry_pending = true
	if is_instance_valid(embedded_player):
		call_deferred("_emit_retry")
	else:
		get_tree().call_deferred("reload_current_scene")

func _emit_retry() -> void:
	retry_requested.emit()

# Camera-only offset: never change the player collider or mouse angles.
func _process(delta: float) -> void:
	if shake_clock <= 0.0:
		return
	shake_clock = maxf(0.0, shake_clock - delta)
	var weight: float = shake_strength * (shake_clock / maxf(shake_duration, 0.01))
	var time: float = shake_clock * 73.0
	camera.h_offset = camera_base_offset.x + sin(time * 1.35) * weight
	camera.v_offset = camera_base_offset.y + cos(time * 0.87) * weight * 0.65

func _shake(at: Vector3, strength: float, duration: float) -> void:
	var attenuation: float = clampf(1.0 - camera.global_position.distance_to(at) / 18.0, 0.15, 1.0)
	shake_strength = maxf(shake_strength * shake_clock / maxf(shake_duration, 0.01), strength * attenuation)
	shake_duration = duration
	shake_clock = duration

func _physics_process(delta: float) -> void:
	if not active:
		return
	damage_grace = maxf(0.0, damage_grace - delta)
	rifle_clock = maxf(0.0, rifle_clock - delta)
	if form_requested:
		form_requested = false
		if phase_two:
			if is_instance_valid(rifle) and player.held_item == rifle:
				_start_reload()
			else:
				_collect_rifle()
		else:
			_form_ball()
	if throw_requested:
		throw_requested = false
		if phase_two:
			_fire_rifle()
		else:
			_throw_player()
	if phase_two:
		_update_reload(delta)
		_update_hud()
		return
	_tick_santa_voice(delta)
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	# Santa faces the small elf, then telegraphs each shot.
	var target: Vector3 = giant_target if santa_attack == SantaAttack.GIANT_WINDUP else player.global_position
	if santa_attack == SantaAttack.MELEE_WINDUP:
		target = melee_target
	target.y = santa.global_position.y
	if santa.global_position.distance_to(target) > 0.1:
		santa.look_at(target, Vector3.UP, true)
	var before: Vector3 = santa.global_position
	var pause_attack := _move_santa(delta)
	if not pause_attack:
		_tick_santa_attack(delta)
	if active:
		_update_santa_pose(delta, santa.global_position - before)
		_update_hud()

# The first attack is a burst. Alternate burst and giant lob, without timers
# that could continue firing after Santa dies or the fight is restarted.
func _tick_santa_attack(delta: float) -> void:
	attack_clock -= delta
	match santa_attack:
		SantaAttack.WAIT:
			# Do not start a new attack while Rudolph is telegraphing or charging.
			if is_instance_valid(rudolph) and rudolph.state != RUDOLPH.State.REST:
				attack_clock = maxf(attack_clock, 0.35)
				return
			if melee_cooldown <= 0.0 and santa.global_position.distance_to(player.global_position) < 1.35:
				melee_target = player.global_position
				santa_attack = SantaAttack.MELEE_WINDUP
				attack_clock = 0.60
				melee_cooldown = 4.0
				_update_hud()
				return
			if attack_clock > 0.0:
				return
			if next_giant:
				_begin_giant()
			else:
				santa_attack = SantaAttack.BURST
				burst_remaining = 3
				winding = true
				attack_clock = maxf(0.2, santa_windup * (0.75 if enraged else 1.0))
		SantaAttack.BURST:
			if attack_clock > 0.0:
				return
			_throw_santa(true)
			burst_remaining -= 1
			if burst_remaining > 0:
				attack_clock = santa_burst_spacing * (0.80 if enraged else 1.0)
			else:
				winding = false
				santa_attack = SantaAttack.WAIT
				next_giant = true
				attack_clock = maxf(0.4, santa_throw_interval * (0.65 if enraged else 1.0))
		SantaAttack.GIANT_WINDUP:
			var progress := clampf(1.0 - attack_clock / giant_windup, 0.0, 1.0)
			giant_ball.global_position = santa.to_global(Vector3(0, lerpf(0.98, 1.88, smoothstep(0.0, 1.0, progress)), lerpf(0.87, 0.64, progress)))
			giant_ball.scale = Vector3.ONE * lerpf(0.35, 1.0, progress)
			if attack_clock <= 0.0:
				giant_launch = giant_ball.global_position
				santa_attack = SantaAttack.GIANT_FLIGHT
				attack_clock = giant_flight_time
				_sound(giant_launch, THROW_SOUND)
		SantaAttack.GIANT_FLIGHT:
			var progress := clampf(1.0 - attack_clock / giant_flight_time, 0.0, 1.0)
			giant_ball.global_position = giant_launch.lerp(giant_target + Vector3.UP * GIANT_BALL_RADIUS, progress) + Vector3.UP * (sin(progress * PI) * 1.55)
			giant_ball.rotate_x(delta * 5.0)
			if attack_clock <= 0.0:
				_impact_giant()
		SantaAttack.GIANT_RECOVERY:
			if attack_clock <= 0.0:
				santa_attack = SantaAttack.WAIT
				next_giant = false
				attack_clock = 0.25 if enraged else 0.35
		SantaAttack.MELEE_WINDUP:
			if attack_clock <= 0.0:
				_resolve_melee()
				if not active:
					return
				santa_attack = SantaAttack.MELEE_RECOVERY
				attack_clock = 0.75
				_update_hud()
		SantaAttack.MELEE_RECOVERY:
			if attack_clock <= 0.0:
				santa_attack = SantaAttack.WAIT
				attack_clock = 0.35
				_update_hud()

func _resolve_melee() -> void:
	var start: Vector3 = santa.global_position + Vector3.UP * 0.65
	var end: Vector3 = player.global_position + Vector3.UP * 0.5
	var offset: Vector3 = end - start
	var facing: Vector3 = melee_target - santa.global_position
	facing.y = 0.0
	var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
	_sound(start, THROW_SOUND)
	if flat.length() > 1.45 or facing.normalized().dot(flat.normalized()) < 0.6:
		return
	var query := PhysicsRayQueryParameters3D.create(start, end, 1, [santa.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") == player:
		_sound(end, HIT_SOUND)
		_dive_damage(true)

func _begin_giant() -> void:
	santa_attack = SantaAttack.GIANT_WINDUP
	winding = false
	throw_follow = 0.0
	attack_clock = giant_windup
	# The aim is locked once. The warning stays in exactly the impact area.
	giant_target = player.global_position
	giant_target.y = 0.0
	giant_ball = _sphere(arena, Vector3.ZERO, GIANT_BALL_RADIUS, snow)
	giant_ball.global_position = santa.to_global(Vector3(0, 0.98, 0.87))
	giant_ball.scale = Vector3.ONE * 0.35
	# Put the rifle on Santa's back while both hands prepare the giant ball.
	santa_rifle.position = Vector3(0.0, 0.45, -0.52)
	santa_rifle.rotation = Vector3(0.0, 0.0, -0.35)
	giant_marker = Node3D.new()
	giant_marker.name = "GiantSnowballWarning"
	arena.add_child(giant_marker)
	giant_marker.global_position = giant_target + Vector3.UP * 0.045
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = giant_radius - 0.075
	ring_mesh.outer_radius = giant_radius
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 6
	var red_glow := StandardMaterial3D.new()
	red_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red_glow.albedo_color = Color(1.0, 0.10, 0.12)
	var outline := _mesh(giant_marker, Vector3.ZERO, ring_mesh, red_glow)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disk_mesh := CylinderMesh.new()
	disk_mesh.top_radius = giant_radius - 0.06
	disk_mesh.bottom_radius = giant_radius - 0.06
	disk_mesh.height = 0.008
	disk_mesh.radial_segments = 48
	var disk_mat := StandardMaterial3D.new()
	disk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disk_mat.albedo_color = Color(0.92, 0.04, 0.06, 0.20)
	var disk := _mesh(giant_marker, Vector3(0, -0.008, 0), disk_mesh, disk_mat)
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sound(santa.global_position + Vector3.UP, RELOAD_SOUND)
	_update_hud()

func _impact_giant() -> void:
	# Resolve once, at the marked location. A lob is not blocked by ordinary
	# low cover; neither cover nor jumping negates this horizontal blast area.
	_clear_giant()
	santa_attack = SantaAttack.GIANT_RECOVERY
	attack_clock = giant_recovery * (0.75 if enraged else 1.0)
	_sound(giant_target, HEAVY_IMPACT)
	_shake(giant_target, 0.045, 0.42)
	_damage_cover_area(giant_target, giant_radius, 2)
	_impact_mark(giant_target, giant_radius)
	SNOW_PUFF.spawn(arena, arena.to_local(giant_target + Vector3.UP * 0.12), 90)
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var chip := _sphere(arena, Vector3.ZERO, 0.075, snow)
		chip.global_position = giant_target + Vector3.UP * 0.27
		var end := giant_target + radial * giant_radius * santa_rng.randf_range(0.45, 0.95) + Vector3.UP * 0.08
		var scatter := create_tween()
		scatter.tween_property(chip, "global_position", end + Vector3.UP * 0.45, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		scatter.tween_property(chip, "global_position", end, 0.23).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		scatter.parallel().tween_property(chip, "scale", Vector3.ZERO, 0.23)
		scatter.tween_callback(chip.queue_free)
	var gap: Vector3 = player.global_position - giant_target
	if Vector2(gap.x, gap.z).length() <= giant_radius:
		player_hits = PLAYER_HP
		get_tree().call_group("makeshift_retro_fx", "pulse", 1.0, true)
		_update_hud()
		_finish(false)
	else:
		_update_hud()

func _clear_giant() -> void:
	if is_instance_valid(giant_ball):
		giant_ball.hide()
		giant_ball.queue_free()
	giant_ball = null
	if is_instance_valid(giant_marker):
		giant_marker.hide()
		giant_marker.queue_free()
	giant_marker = null
	if is_instance_valid(santa_rifle):
		santa_rifle.position = Vector3(0.0, 0.43, 0.47)
		santa_rifle.rotation = Vector3(0.0, PI, 0.0)

func _cancel_santa_attack() -> void:
	_clear_giant()
	santa_attack = SantaAttack.WAIT
	burst_remaining = 0
	winding = false

# Move only with swept body collision; pause the throw clock during a dodge.
func _move_santa(delta: float) -> bool:
	dodge_ready_in = maxf(0.0, dodge_ready_in - delta)
	# Telegraph, launch and recovery deliberately plant Santa's feet.
	if santa_attack >= SantaAttack.GIANT_WINDUP:
		return false
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
		var step := move_dir * santa_walk_speed * (1.32 if enraged else 1.0) * delta
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
				dodge_ready_in = santa_dodge_cooldown * (0.72 if enraged else 1.0)
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
	# Hold the rifle with both hands; retain gait, dodge and impact body poses.
	if santa_attack == SantaAttack.GIANT_WINDUP:
		var lift := smoothstep(0.0, 1.0, clampf(1.0 - attack_clock / giant_windup, 0.0, 1.0))
		arm.rotation = arm.rotation.lerp(Vector3(lerpf(-0.85, -2.36, lift), 0.0, -0.25), arm_blend)
		free_arm.rotation = free_arm.rotation.lerp(Vector3(lerpf(-0.85, -2.36, lift), 0.0, 0.25), arm_blend)
	elif santa_attack == SantaAttack.MELEE_WINDUP:
		arm.rotation = arm.rotation.lerp(Vector3(-0.85, 0.0, 0.85), arm_blend)
		free_arm.rotation = free_arm.rotation.lerp(Vector3(-0.85, 0.0, 0.35), arm_blend)
		santa_rifle.rotation.z = lerpf(santa_rifle.rotation.z, 0.7, blend)
	elif santa_attack == SantaAttack.MELEE_RECOVERY:
		arm.rotation = arm.rotation.lerp(Vector3(-1.50, 0.0, -0.45), arm_blend)
		santa_rifle.rotation.z = lerpf(santa_rifle.rotation.z, -0.4, blend)
	elif santa_attack == SantaAttack.GIANT_FLIGHT:
		arm.rotation = arm.rotation.lerp(Vector3(-1.50, 0.0, -0.15), arm_blend)
		free_arm.rotation = free_arm.rotation.lerp(Vector3(-1.50, 0.0, 0.15), arm_blend)
	else:
		if santa_attack < SantaAttack.GIANT_WINDUP:
			santa_rifle.rotation.z = lerpf(santa_rifle.rotation.z, 0.0, blend)
		arm.rotation = arm.rotation.lerp(Vector3(-1.16 + (0.12 if throw_follow > 0.0 else 0.0), 0.0, 0.18), arm_blend)
		free_arm.rotation = free_arm.rotation.lerp(Vector3(-1.05, 0.0, -0.27), blend)
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
	throw_follow = FOLLOW_TIME
	var start: Vector3 = (santa_rifle.get_node("Muzzle") as Node3D).global_position
	var target: Vector3 = player.global_position + Vector3.UP * 0.55
	if damage:
		var lead: Vector3 = player.velocity
		lead.y = 0.0
		lead = lead.limit_length(5.0)
		target += lead * minf(start.distance_to(target) / santa_projectile_speed, 0.45) * (0.8 if enraged else 0.45)
	var diff := target - start
	var duration := diff.length() / maxf(1.0, santa_projectile_speed)
	var initial := diff / maxf(duration, 0.05) + Vector3.UP * (1.2 * duration)
	_spawn_shot(start, initial, santa, damage)

func _spawn_shot(start: Vector3, initial: Vector3, shooter: CollisionObject3D, damage: bool) -> void:
	var shot := Projectile.new()
	shots.add_child(shot)
	shot.setup(start, initial, shooter, damage)
	shot.impacted.connect(_on_impact.bind(shooter))
	_sound(start, RIFLE_FIRE if shooter == santa or (phase_two and shooter == player) else THROW_SOUND)

func _on_impact(collider: Object, at: Vector3, damaging: bool, shooter: CollisionObject3D) -> void:
	_snow_burst(at)
	_sound(at, HIT_SOUND)
	if not active or not damaging or finished:
		return
	if phase_two and collider == rudolph and shooter == player:
		var bonus: bool = is_instance_valid(air) and air.hit_weak_point(at)
		rudolph_hits += 2 if bonus else 1
		if is_instance_valid(air):
			if rudolph_hits >= 9 and not air.enraged:
				air.enraged = true
				boss_music.intensify()
				_start_storm.call_deferred()
		get_tree().call_group("makeshift_retro_fx", "pulse", 0.45, false)
		if rudolph_hits >= RUDOLPH_HP:
			_finish(true)
	elif not phase_two and collider == santa and shooter == player:
		if santa_hits >= SANTA_HP:
			return
		santa_hits += 1
		if santa_hits == 3:
			enraged = true
			boss_music.intensify()
			_sound(santa.global_position + Vector3.UP, preload("res://assets/audio/forest_sleigh_bell.wav"))
		get_tree().call_group("makeshift_retro_fx", "pulse", 0.55, false)
		if santa_hits >= SANTA_HP:
			active = false
			_begin_phase_two.call_deferred()
		else:
			var away: Vector3 = santa.global_position - player.global_position
			away.y = 0.0
			hit_direction = santa.global_transform.basis.inverse() * away.normalized()
			hit_pose_time = HIT_POSE_TIME
	elif not phase_two and collider == player and shooter == santa:
		if damage_grace > 0.0:
			return
		damage_grace = DAMAGE_GRACE
		player_hits += 1
		var fx := get_tree().get_first_node_in_group("makeshift_retro_fx")
		if is_instance_valid(fx) and bool(fx.get("effects_enabled")) and bool(fx.get("event_effects")):
			fx.call("pulse", 0.85, true)
		else:
			flash.color.a = 0.45
			create_tween().tween_property(flash, "color:a", 0.0, 0.40)
		if player_hits >= PLAYER_HP:
			_finish(false)
	# Ordinary rifle shots stop at cover without destroying it.
	# Giant impacts, charges, dives and lasers still damage registered cover.
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
	form.tween_property(arm, "rotation:x", -1.16, 0.48)
	form.tween_property(free_arm, "rotation:x", -1.05, 0.48)
	await form.finished
	var visual := _sphere(player.hold_point, Vector3.ZERO, 0.10, snow)
	duel_hands.show()
	await get_tree().create_timer(0.35, false).timeout
	var raise := create_tween().set_parallel(true)
	raise.tween_property(head, "rotation:x", atan2(gaze.y, Vector2(gaze.x, gaze.z).length()), 0.50)
	raise.tween_property(torso_pivot, "position:y", HIP_HEIGHT, 0.50)
	raise.tween_property(torso_pivot, "rotation:x", 0.0, 0.50)
	raise.tween_property(arm, "rotation:x", -1.25, 0.50)
	raise.tween_property(free_arm, "rotation:x", -1.05, 0.50)
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
	boss_music.play_phase(1)
	santa_laugh_clock = santa_rng.randf_range(2.5, 4.0)
	active = true
	player.call("set_controls_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show()
	stats.show()
	_update_hud()

func _finish(victory: bool) -> void:
	if finished:
		return
	# Latch the result before stopping emitters: no late hit can change it.
	finished = true
	ending_victory = victory
	active = false
	_stop_santa_voice()
	boss_music.fade_out(0.45)
	_cancel_santa_attack()
	_cancel_reload()
	_stop_storm()
	if is_instance_valid(air):
		air.halt()
	if is_instance_valid(rudolph):
		rudolph.stop_fight()
	winding = false
	form_requested = false
	throw_requested = false
	santa_ball.hide()
	if is_instance_valid(hands_tween):
		hands_tween.kill()
	for shot in shots.get_children():
		shot.set_physics_process(false)
		shot.queue_free()
	player.call("set_controls_enabled", false)
	player.set("drop_requested", false)
	stats.hide()
	hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ending_camera_position = camera.position
	ending_camera_rotation = camera.rotation
	ending_camera_saved = true
	_run_ending.call_deferred()

func _run_ending() -> void:
	# Defer cinematic setup out of projectile/physics callbacks.
	if ending_victory:
		await _victory_scene()
	else:
		await _defeat_scene()
	var fade := create_tween()
	fade.tween_property(ending_shade, "color:a", 1.0, 1.05).set_trans(Tween.TRANS_SINE)
	await fade.finished
	if ending_victory:
		await _play_final_laugh()
	_update_ending_text()
	ending_panel.show()
	ending_ready = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ending_victory and menu_btn.visible:
		menu_btn.grab_focus()
	else:
		restart_btn.grab_focus()
	combat_finished.emit(ending_victory)

func _play_final_laugh() -> void:
	# A dry, centered voice with baked reverb: audible regardless of camera angle.
	# Keep the screen fully black and the results hidden until it has finished.
	await get_tree().create_timer(0.22, false).timeout
	var voice := AudioStreamPlayer.new()
	voice.name = "EndingElfLaugh"
	voice.stream = ELF_LAUGH
	voice.volume_db = -2.0
	if AudioServer.get_bus_index("SFX") >= 0:
		voice.bus = &"SFX"
	add_child(voice)
	voice.play()
	await voice.finished
	voice.queue_free()
	await get_tree().create_timer(0.35, false).timeout

func _lower_ending_weapon(duration: float) -> void:
	var lower := create_tween().set_parallel(true)
	if is_instance_valid(player.held_item):
		lower.tween_property(player.held_item, "position:y", -0.65, duration)
	if is_instance_valid(duel_hands):
		lower.tween_property(duel_hands, "position:y", -0.65, duration)
	await lower.finished
	if is_instance_valid(player.held_item):
		player.held_item.hide()
	duel_hands.hide()

func _victory_scene() -> void:
	# Keep the original clearing and the accumulated destruction in view.
	rudolph.collision_layer = 0
	rudolph.collision_mask = 0
	await _look_at(rudolph.global_position + Vector3.UP * 0.65, 0.26)
	var drop_start: Vector3 = rudolph.global_position
	var impact: Vector3 = drop_start
	impact.y = minf(drop_start.y, 0.22)
	var fall := create_tween()
	fall.tween_method(_track_final_fall.bind(drop_start, impact), 0.0, 1.0, 0.74).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	_sound(impact, HEAVY_IMPACT)
	_shake(impact, 0.045, 0.38)
	SNOW_PUFF.spawn(arena, arena.to_local(impact), 75)
	_impact_mark(impact, 0.8)
	var settle := create_tween().set_parallel(true)
	settle.tween_property(rudolph, "rotation:z", 1.40, 0.32)
	settle.tween_property(rudolph.nose, "emission_energy_multiplier", 0.0, 0.65)
	await settle.finished
	await _lower_ending_weapon(0.38)
	# Before the fade, the elf turns to look at fallen Santa, enjoying what he has done.
	if is_instance_valid(santa):
		var fallen_target: Vector3 = torso_pivot.global_position if is_instance_valid(torso_pivot) else santa.global_position + Vector3.UP * 0.35
		await _look_at(fallen_target, 0.42)
		await get_tree().create_timer(0.42, false).timeout
	# Cut the extended clearing inspection: Santa glance, silence, fade, then the elf's terrible laugh.
	await get_tree().create_timer(0.18, false).timeout

func _track_final_fall(progress: float, start: Vector3, destination: Vector3) -> void:
	rudolph.global_position = start.lerp(destination, progress)
	rudolph.rotation.z = lerpf(0.0, 0.78, progress)
	var gaze: Vector3 = rudolph.global_position + Vector3.UP * 0.65 - camera.global_position
	var yaw: float = atan2(-gaze.x, -gaze.z)
	player.rotation.y += wrapf(yaw - player.rotation.y, -PI, PI) * 0.26
	head.rotation.x = lerpf(head.rotation.x, clampf(atan2(gaze.y, Vector2(gaze.x, gaze.z).length()), -1.35, 1.35), 0.26)

func _defeat_scene() -> void:
	# First-person collapse without changing the real player capsule.
	var fall := create_tween().set_parallel(true)
	fall.tween_property(camera, "position:y", ending_camera_position.y - 0.32, 0.57).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(camera, "rotation:z", ending_camera_rotation.z + 0.65, 0.57).set_trans(Tween.TRANS_SINE)
	fall.tween_property(head, "rotation:x", -0.42, 0.57).set_trans(Tween.TRANS_SINE)
	await fall.finished
	_sound(player.global_position, HEAVY_IMPACT)
	_shake(player.global_position, 0.028, 0.22)
	await _lower_ending_weapon(0.20)
	await get_tree().create_timer(0.55, false).timeout

func _update_ending_text() -> void:
	result_label.text = "MAKE SHIT CHRISTMAS" if ending_victory else "GAME OVER"
	ending_subtitle.text = "CHRISTMAS IS OVER" if ending_victory else "Try again"
	restart_btn.text = "Replay fight (R)" if ending_victory else "Retry (R)"

func _return_to_menu() -> void:
	if not ending_ready or retry_pending or ending_menu_path.is_empty():
		return
	retry_pending = true
	call_deferred("_load_main_menu")

func _load_main_menu() -> void:
	var result: Error = get_tree().change_scene_to_file(ending_menu_path)
	if result == OK:
		GameState.reset_run()
	else:
		retry_pending = false
		push_warning("Unable to open main menu: " + error_string(result))

func _on_item_changed(_item: Node3D) -> void:
	if reload_remaining > 0.0 and _item != rifle:
		_cancel_reload()
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
	santa_label.text = tr("Rudolph: %d / 12") % maxi(0, RUDOLPH_HP - rudolph_hits) if phase_two else tr("Santa: %d / 5") % maxi(0, SANTA_HP - santa_hits)
	if phase_two:
		boss_bar.value = maxi(0, RUDOLPH_HP - rudolph_hits)
		warning_label.text = air.warning_text() if is_instance_valid(air) else "Avoid the laser and dive"
		var holding: bool = is_instance_valid(rifle) and player.held_item == rifle
		control_label.text = "E looking at snow - Reload   |   Left click - Fire" if holding else "E - Pick up rifle   |   Left click - Fire"
		if not holding:
			ammo_label.text = "Pick up Santa’s rifle"
		elif reload_remaining > 0.0:
			var percent: int = roundi(100.0 * (1.0 - reload_remaining / rifle_reload_duration))
			ammo_label.text = tr("Reloading snow... %d%%") % percent
		elif rifle_ammo == 0:
			ammo_label.text = tr("Ammo: %d / %d") % [rifle_ammo, rifle_magazine] + " | " + tr("Empty! Look at snow and press E")
		else:
			ammo_label.text = tr("Ammo: %d / %d") % [rifle_ammo, rifle_magazine]
		if is_instance_valid(reload_bar):
			reload_bar.visible = reload_remaining > 0.0 and holding
			reload_bar.value = 100.0 * (1.0 - reload_remaining / rifle_reload_duration)
	player_label.text = tr("Elf: %d / 3") % (PLAYER_HP - player_hits)
	if not phase_two:
		ammo_label.text = "Snowball ready" if is_instance_valid(player.held_item) else "Hands empty"
		if santa_attack in [SantaAttack.GIANT_WINDUP, SantaAttack.GIANT_FLIGHT]:
			warning_label.text = "Santa: giant snowball! Leave the circle!"
		elif santa_attack == SantaAttack.MELEE_WINDUP:
			warning_label.text = "Santa: rifle strike!"
		elif is_instance_valid(rudolph) and rudolph.state == RUDOLPH.State.AIM:
			warning_label.text = tr("Rudolph: charge incoming!")
		elif is_instance_valid(rudolph) and rudolph.state == RUDOLPH.State.CHARGE:
			warning_label.text = tr("Rudolph: dodge sideways!")
		else:
			warning_label.text = "Santa is enraged!" if enraged else "Rudolph: avoid contact"

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
	warning_label = _label(top, "Rudolph: avoid contact", 18, Color(1,0.65,0.52))
	boss_bar = ProgressBar.new()
	top.add_child(boss_bar)
	boss_bar.custom_minimum_size = Vector2(260, 16)
	boss_bar.max_value = RUDOLPH_HP
	boss_bar.value = RUDOLPH_HP
	boss_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.70, 0.08, 0.12)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_bar.hide()
	reload_bar = ProgressBar.new()
	top.add_child(reload_bar)
	reload_bar.custom_minimum_size = Vector2(200, 12)
	reload_bar.max_value = 100
	reload_bar.show_percentage = false
	reload_bar.hide()
	var bottom := Label.new()
	control_label = bottom
	stats.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -70
	bottom.offset_bottom = -42
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_theme_color_override("font_shadow_color", Color.BLACK)
	bottom.add_theme_constant_override("shadow_offset_x", 2)
	bottom.text = "E - Make snowball   |   Left click - Throw   |   Q - Drop"
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_shade = ColorRect.new()
	overlay.add_child(ending_shade)
	ending_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_shade.color = Color(0.0, 0.0, 0.0, 0.0)
	ending_panel = CenterContainer.new()
	overlay.add_child(ending_panel)
	ending_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	ending_panel.add_child(column)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	result_label = _label(column, "", 42, Color(0.93, 0.25, 0.28))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_subtitle = _label(column, "", 19, Color(0.76, 0.78, 0.82))
	ending_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_btn = Button.new()
	column.add_child(restart_btn)
	restart_btn.text = "Retry (R)"
	restart_btn.custom_minimum_size.y = 42
	restart_btn.pressed.connect(_request_retry)
	menu_btn = Button.new()
	column.add_child(menu_btn)
	menu_btn.text = "Main menu"
	menu_btn.custom_minimum_size.y = 42
	menu_btn.pressed.connect(_return_to_menu)
	for path in [MENU_SCENE, "res://scenes/ui/main_menu.tscn"]:
		if ResourceLoader.exists(path):
			ending_menu_path = path
			break
	menu_btn.visible = not ending_menu_path.is_empty()
	ending_panel.hide()

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
		snow_ground = player.get_parent().get_node_or_null("Ground") as StaticBody3D
		# Existing snow, walls, snowman and sleigh remain. Add only two cover rocks.
		for p in [Vector3(3.6, 0.43, 2.8), Vector3(-4.55, 0.48, -1.7)]:
			var rock := _solid(p, Vector3(1.15, 0.90, 1.10), dark, false)
			_sphere(rock, Vector3.ZERO, 0.61, _mat(Color(0.40, 0.46, 0.52)), Vector3(1.0, 0.78, 0.95))
			_register_cover(rock, 5, false, false)
		return
	snow_ground = _solid(Vector3(0,-0.2,0), Vector3(24,0.4,24), snow)
	snow_ground.name = "CombatSnowGround"
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
		_register_cover(cover, 5, false, false)
	# Crashed sleigh, usable as cover.
	var sleigh := _solid(Vector3(-5.6,0.52,3.8), Vector3(2.8,1.05,1.3), red)
	_register_cover(sleigh, 4, false, false)
	_box(sleigh, Vector3(0,0.58,0),Vector3(2.85,0.12,1.39),cream)
	for side in [-1,1]:
		_box(sleigh, Vector3(0,-0.39,side*0.62), Vector3(3.1,0.15,0.12),bark)
	for side in [-1,1]:
		for i in range(7):
			var p := Vector3(side*(9.4 + 0.35*sin(i*2.0)), 0.0, -9+3*i)
			var trunk := _solid(p+Vector3.UP*1.2,Vector3(0.38,2.4,0.38),bark)
			_register_cover(trunk, 2, false, true)
			for j in range(3):
				_cone(trunk,Vector3(0,0.25+j*0.65,0),1.15-j*0.24,1.5,pine)
	for i in range(7):
		var p := Vector3(-9+3*i,0,-10)
		var trunk := _solid(p+Vector3.UP*1.2,Vector3(0.38,2.4,0.38),bark)
		_cone(trunk,Vector3(0,0.7,0),1.25,2.7,pine)
		_register_cover(trunk, 2, false, true)

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
	santa_rifle = _make_rifle(torso_pivot)
	santa_rifle.position = Vector3(0.0, 0.43, 0.47)
	santa_rifle.rotation.y = PI
	arm.rotation.x = -1.16
	free_arm.rotation.x = -1.05
	santa_voice = AudioStreamPlayer3D.new()
	santa_voice.name = "SantaVoice"
	santa.add_child(santa_voice)
	santa_voice.position = Vector3(0.0, 1.5, 0.0)
	santa_voice.stream = SANTA_HO_HO
	santa_voice.unit_size = 5.0
	santa_voice.max_distance = 30.0
	santa_voice.volume_db = 1.0
	if AudioServer.get_bus_index("SFX") >= 0:
		santa_voice.bus = &"SFX"

func _tick_santa_voice(delta: float) -> void:
	if not active or phase_two or finished or santa_hits >= SANTA_HP:
		return
	if not is_instance_valid(santa_voice):
		return
	santa_laugh_clock = maxf(0.0, santa_laugh_clock - delta)
	if santa_laugh_clock > 0.0 or santa_voice.playing:
		return
	santa_voice.pitch_scale = santa_rng.randf_range(0.95, 1.04)
	santa_voice.play()
	santa_laugh_clock = santa_rng.randf_range(santa_laugh_min_interval, maxf(santa_laugh_min_interval, santa_laugh_max_interval))

func _stop_santa_voice() -> void:
	if is_instance_valid(santa_voice):
		santa_voice.stop()

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
	rudolph.cover_hit.connect(_charge_cover_hit)
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


# A toy-like snow launcher with a frosted reservoir and candy-red trim.
func _make_rifle(parent: Node3D) -> Node3D:
	var gun := Node3D.new()
	parent.add_child(gun)
	var blue := _mat(Color(0.19, 0.34, 0.46))
	_box(gun, Vector3(0, 0, 0.03), Vector3(0.17, 0.16, 0.40), blue)
	_box(gun, Vector3(0, -0.035, 0.29), Vector3(0.15, 0.12, 0.22), red)
	_box(gun, Vector3(0, -0.10, 0.08), Vector3(0.085, 0.18, 0.10), dark)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.062
	tube.bottom_radius = 0.075
	tube.height = 0.30
	var barrel := _mesh(gun, Vector3(0, 0.015, -0.28), tube, dark)
	barrel.rotation.x = PI * 0.5
	_sphere(gun, Vector3(0, 0.015, -0.43), 0.080, red, Vector3(1, 1, 0.38))
	var reservoir := _sphere(gun, Vector3(0, 0.13, 0.03), 0.12, snow, Vector3(0.8, 1.0, 1.3))
	reservoir.name = "Reservoir"
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	gun.add_child(muzzle)
	muzzle.position = Vector3(0, 0.015, -0.49)
	return gun

func _begin_phase_two() -> void:
	if phase_two or finished:
		return
	boss_music.fade_out(0.28)
	_stop_santa_voice()
	_cancel_santa_attack()
	active = false
	form_requested = false
	throw_requested = false
	player.call("set_controls_enabled", false)
	hud.hide()
	stats.hide()
	phase_two = true
	damage_grace = 0.0
	rifle_ammo = rifle_magazine
	winding = false
	for shot in shots.get_children():
		shot.set_physics_process(false)
		shot.queue_free()
	rudolph.stop_fight()
	santa.collision_layer = 0
	santa.collision_mask = 0
	# Freeze the first phase before any cinematic movement or effects.
	await _look_at(santa.global_position + Vector3.UP * 1.10, 0.38)
	var release_at: Vector3 = santa_rifle.global_position
	santa_rifle.hide()
	var fall := create_tween()
	fall.tween_property(torso_pivot, "rotation:x", 0.38, 0.24).set_trans(Tween.TRANS_QUAD)
	fall.parallel().tween_property(torso_pivot, "position:y", HIP_HEIGHT - 0.18, 0.24)
	for leg in leg_pivots:
		fall.parallel().tween_property(leg, "rotation:x", -0.38, 0.24)
	fall.tween_property(model, "rotation:z", -1.45, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(model, "position:y", 0.35, 0.48)
	if is_instance_valid(player.held_item) and player.held_item.get("item_id") == SNOWBALL_ID:
		player.held_item.queue_free()
		player.held_item = null
		player.pickup_parent = null
		player.held_item_changed.emit(null)
	rifle = StaticBody3D.new()
	rifle.name = "DroppedSnowRifle"
	rifle.set_script(Pickup)
	rifle.set("item_id", RIFLE_ID)
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.32, 0.34, 0.95)
	collider.shape = shape
	rifle.add_child(collider)
	arena.add_child(rifle)
	var toward: Vector3 = player.global_position - santa.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		toward = Vector3.FORWARD
	var drop: Vector3 = santa.global_position + toward.normalized() * 0.70
	drop.y = 0.20
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [santa.get_rid(), player.get_rid(), rifle.get_rid()]
	for offset in [toward.normalized(), toward.normalized().rotated(Vector3.UP, 1.57), toward.normalized().rotated(Vector3.UP, -1.57), -toward.normalized(), Vector3.ZERO]:
		var direction: Vector3 = offset
		var candidate := santa.global_position + direction * 0.78
		candidate.y = 0.20
		query.transform = Transform3D(Basis.IDENTITY, candidate)
		if space.intersect_shape(query, 1).is_empty():
			drop = candidate
			break
	rifle.global_position = drop
	var art := _make_rifle(rifle)
	art.name = "RifleArt"
	art.scale = Vector3.ONE * 0.9
	art.global_position = release_at
	var drop_anim := create_tween()
	drop_anim.tween_property(art, "position", Vector3.ZERO, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop_anim.parallel().tween_property(art, "rotation:z", 0.0, 0.55)
	await fall.finished
	_sound(santa.global_position, HEAVY_IMPACT)
	_shake(santa.global_position, 0.024, 0.28)
	SNOW_PUFF.spawn(arena, arena.to_local(santa.global_position + Vector3.UP * 0.1), 32)
	await get_tree().create_timer(0.65, false).timeout
	var objective := player.get_node("HUD/Objective") as Label
	objective.text = "DEFEAT RUDOLPH"
	air = AIR.new()
	air.deer = rudolph
	air.player = player
	air.laser_hit.connect(_rudolph_hit)
	air.dive_hit.connect(_dive_damage.bind(false))
	air.warning_sound.connect(_air_warning)
	air.laser_fired.connect(_laser_sound)
	air.impact_sound.connect(_air_impact)
	air.cover_hit.connect(_laser_cover_hit)
	arena.add_child(air)
	await _rudolph_transformation()
	air.begin_after_intro()
	boss_music.play_phase(2)
	boss_bar.show()
	active = true
	player.call("set_controls_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show()
	stats.show()
	_update_hud()

func _rudolph_transformation() -> void:
	air.prepare_intro()
	rudolph.face(player.global_position)
	await _look_at(rudolph.global_position + Vector3.UP * 1.15, 0.65)
	transition_light = OmniLight3D.new()
	rudolph.add_child(transition_light)
	transition_light.light_color = Color(1.0, 0.06, 0.08)
	transition_light.omni_range = 4.0
	transition_light.light_energy = 0.0
	transition_light.global_position = air.nose.global_position
	_sound(rudolph.global_position, ASCENSION)
	var charge := create_tween().set_parallel(true)
	charge.tween_property(transition_light, "light_energy", 2.5, 0.80)
	charge.tween_method(air.set_intro_glow, 1.0, 6.0, 0.80)
	await charge.finished
	rise_origin = rudolph.global_position
	rise_destination = rise_origin
	rise_destination.y = AIR.ALTITUDE
	# If the deer stopped close to the elf, drift away while climbing to keep
	# the full body in frame rather than forcing a near-vertical camera angle.
	var away: Vector3 = rise_origin - player.global_position
	away.y = 0.0
	if away.length() < 2.4:
		if away.length_squared() < 0.01:
			away = Vector3.FORWARD
		rise_destination += away.normalized() * 1.6
	SNOW_PUFF.spawn(arena, arena.to_local(rise_origin + Vector3.UP * 0.15), 90)
	rudolph.cinematic_running = true
	rudolph.flight_pose = 1.0
	var rise := create_tween()
	rise.tween_method(_track_rudolph_rise, 0.0, 1.0, 1.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await rise.finished
	# Lock onto the elf BEFORE the scripted dodge. Never select a tree.
	var aim: Vector3 = player.global_position + Vector3.UP * 0.53
	rudolph.face(aim)
	await get_tree().physics_frame
	var origin: Vector3 = air.nose.global_position
	# Extend the shot through the old torso position to the snow behind it.
	var beam_direction: Vector3 = (aim - origin).normalized()
	var impact: Vector3 = aim
	if beam_direction.y < -0.01:
		impact = aim + beam_direction * (aim.y / -beam_direction.y)
	await _look_at(origin, 0.24)
	_sound(origin, LASER_CHARGE)
	air.preview_beam(impact, false)
	await get_tree().create_timer(0.62, false).timeout
	# The elf slips sideways, favoring the rifle's direction. The beam stays
	# on the old position even though the camera/player are now moving.
	await get_tree().physics_frame
	var dodge: Vector3 = _choose_intro_dodge(origin)
	var side: Vector3 = dodge - player.global_position
	var roll: float = clampf(side.dot(camera.global_transform.basis.x), -1.0, 1.0) * -0.12
	var lean := create_tween()
	lean.tween_property(camera, "rotation:z", roll, 0.12)
	await _cinematic_step_to(dodge, 5.6)
	air.preview_beam(impact, true)
	_laser_sound(origin)
	_shake(player.global_position, 0.055, 0.38)
	_sound(impact, HEAVY_IMPACT)
	SNOW_PUFF.spawn(arena, arena.to_local(impact), 65)
	_impact_mark(impact, 0.48)
	await get_tree().create_timer(0.19, false).timeout
	air.end_preview()
	transition_light.queue_free()
	var straighten := create_tween()
	straighten.tween_property(camera, "rotation:z", 0.0, 0.18)
	await _look_at(rifle.global_position, 0.27)
	await _cinematic_retrieve_rifle()
	await _look_at(rudolph.global_position + Vector3.UP * 1.0, 0.45)
	await get_tree().create_timer(0.15, false).timeout

func _track_rudolph_rise(progress: float) -> void:
	rudolph.global_position = rise_origin.lerp(rise_destination, progress)
	var gaze: Vector3 = rudolph.global_position + Vector3.UP * 1.05 - camera.global_position
	var yaw: float = atan2(-gaze.x, -gaze.z)
	player.rotation.y += wrapf(yaw - player.rotation.y, -PI, PI) * 0.22
	head.rotation.x = lerpf(head.rotation.x, clampf(atan2(gaze.y, Vector2(gaze.x, gaze.z).length()), -1.35, 1.35), 0.22)

# Test the real player capsule from any candidate position. The movement
# itself also uses move_and_collide, never a transform teleport.
func _intro_path_clear(from: Vector3, destination: Vector3) -> bool:
	var motion: Vector3 = destination - from
	motion.y = 0.0
	if is_instance_valid(embedded_player):
		if absf(destination.x) > 5.0 or destination.z < -5.0 or destination.z > 11.0:
			return false
	elif absf(destination.x) > 11.0 or absf(destination.z) > 11.0:
		return false
	var pose: Transform3D = player.global_transform
	pose.origin = from
	return not player.test_move(pose, motion, null, 0.001, false)

func _choose_intro_dodge(origin: Vector3) -> Vector3:
	var start: Vector3 = player.global_position
	var toward: Vector3 = rifle.global_position - start
	toward.y = 0.0
	var beam: Vector3 = start - origin
	beam.y = 0.0
	if beam.length_squared() < 0.01:
		beam = Vector3.FORWARD
	var side: Vector3 = beam.normalized().cross(Vector3.UP)
	if side.dot(toward) < 0.0:
		side = -side
	for distance in [1.15, 0.85, 0.60]:
		for direction in [side, (side + toward.normalized() * 0.55).normalized(), -side, (-side + toward.normalized() * 0.55).normalized()]:
			var move_dir: Vector3 = direction
			var candidate: Vector3 = start + move_dir * float(distance)
			if _intro_path_clear(start, candidate):
				return candidate
	# A tight corner can block the full dodge. Try a short retreat.
	for direction in [toward.normalized(), beam.normalized(), -beam.normalized()]:
		var move_dir: Vector3 = direction
		var candidate: Vector3 = start + move_dir * 0.45
		if _intro_path_clear(start, candidate):
			return candidate
	return start

func _cinematic_step_to(destination: Vector3, speed: float) -> void:
	# A frame-by-frame physics move allows gravity and prevents clipping.
	var remaining: int = 360
	while is_instance_valid(player) and remaining > 0:
		remaining -= 1
		await get_tree().physics_frame
		var gap: Vector3 = destination - player.global_position
		gap.y = 0.0
		if gap.length() < 0.025:
			return
		var step: Vector3 = gap.limit_length(speed * get_physics_process_delta_time())
		if player.move_and_collide(step, false, 0.001) != null:
			return

func _intro_rifle_goal(from: Vector3, weapon: Vector3) -> Vector3:
	var toward: Vector3 = weapon - from
	toward.y = 0.0
	if toward.length() <= 0.88:
		return from
	return weapon - toward.normalized() * 0.82

func _intro_rifle_route() -> Array[Vector3]:
	var start: Vector3 = player.global_position
	var weapon: Vector3 = rifle.global_position
	weapon.y = start.y
	var goal: Vector3 = _intro_rifle_goal(start, weapon)
	var route: Array[Vector3] = []
	if _intro_path_clear(start, goal):
		route.append(goal)
		return route
	# Search an implicit grid only if the direct route is blocked. Each edge
	# uses the capsule test; diagonal edges cannot cut through obstacles.
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	var parents: Dictionary = {Vector2i.ZERO: Vector2i.ZERO}
	var best: Vector2i = Vector2i.ZERO
	var best_distance: float = start.distance_to(weapon)
	var found: bool = false
	var cursor: int = 0
	var spacing: float = 0.65
	var offsets: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]
	while cursor < pending.size() and cursor < 650:
		var cell: Vector2i = pending[cursor]
		cursor += 1
		var point: Vector3 = start + Vector3(cell.x, 0, cell.y) * spacing
		var distance: float = point.distance_to(weapon)
		if distance < best_distance:
			best = cell
			best_distance = distance
		var finish: Vector3 = _intro_rifle_goal(point, weapon)
		if _intro_path_clear(point, finish):
			best = cell
			goal = finish
			found = true
			break
		for offset in offsets:
			var next: Vector2i = cell + offset
			if parents.has(next):
				continue
			var destination: Vector3 = start + Vector3(next.x, 0, next.y) * spacing
			if not _intro_path_clear(point, destination):
				continue
			parents[next] = cell
			pending.append(next)
	var backtrack: Vector2i = best
	while backtrack != Vector2i.ZERO:
		route.push_front(start + Vector3(backtrack.x, 0, backtrack.y) * spacing)
		backtrack = parents[backtrack]
	if found:
		route.append(goal)
	return route

func _cinematic_retrieve_rifle() -> void:
	await get_tree().physics_frame
	var route: Array[Vector3] = _intro_rifle_route()
	for point in route:
		await _cinematic_step_to(point, 4.4)
	await _look_at(rifle.global_position, 0.22)
	# Use the normal pickup contract (parent, collision, held-item signal).
	# If cover makes the last meter inaccessible, still equip at the closest
	# reachable point instead of trapping the player in the cutscene.
	if bool(player.call("try_pickup", rifle)):
		rifle_ammo = rifle_magazine
		_update_reservoir()
		var art := rifle.get_node("RifleArt") as Node3D
		art.position.y = -0.25
		var lift := create_tween()
		lift.tween_property(art, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_sound(player.global_position, RELOAD_SOUND)
		await lift.finished
	else:
		push_warning("Cinematic rifle pickup failed; manual pickup remains available.")

func _collect_rifle() -> void:
	if not is_instance_valid(rifle) or is_instance_valid(player.held_item):
		return
	var ray: RayCast3D = player.interaction_ray
	ray.force_raycast_update()
	if ray.is_colliding() and ray.get_collider() == rifle:
		player.call("try_interact")

func _fire_rifle() -> void:
	if not is_instance_valid(rifle) or player.held_item != rifle or rifle_clock > 0.0 or reload_remaining > 0.0:
		return
	if rifle_ammo <= 0:
		return
	rifle_ammo -= 1
	_update_reservoir()
	_update_hud()
	rifle_clock = 0.27
	var direction := -camera.global_transform.basis.z.normalized()
	# Shoot along the crosshair, not along the offset viewmodel.
	_spawn_shot(camera.global_position + direction * 0.10, direction * 24.0, player, true)
	var shot := shots.get_child(shots.get_child_count() - 1) as Projectile
	shot.gravity = 0.65
	var art := rifle.get_node("RifleArt") as Node3D
	art.position.z = 0.0
	_shake(camera.global_position, 0.006, 0.12)
	var recoil := create_tween()
	recoil.tween_property(art, "position:z", 0.08, 0.055)
	recoil.tween_property(art, "position:z", 0.0, 0.12)

# E starts a full magazine refill only when the crosshair hits snow.
# Movement remains enabled; the player controller suppresses sprint alone.
func _start_reload() -> void:
	if reload_remaining > 0.0 or rifle_ammo >= rifle_magazine or not player.is_on_floor():
		return
	var ray: RayCast3D = player.interaction_ray
	ray.force_raycast_update()
	if not ray.is_colliding():
		ammo_label.text = "Look at snow to reload"
		return
	var ground_hit: Object = ray.get_collider()
	var snowy: bool = is_instance_valid(snow_ground) and ground_hit == snow_ground
	if ground_hit is StaticBody3D:
		var ground_body := ground_hit as StaticBody3D
		# The actual snowdrifts are the only other permitted surface.
		snowy = snowy or (str(ground_body.name).begins_with("Drift") and str(ground_body.get_parent().name) == "SnowDrifts")
	if not snowy or ray.get_collision_normal().y < 0.55:
		ammo_label.text = "Look at snow to reload"
		return
	reload_remaining = rifle_reload_duration
	player.set("combat_reload_active", true)
	if is_instance_valid(hands_tween):
		hands_tween.kill()
	_sound(ray.get_collision_point(), RELOAD_SOUND)
	_update_hud()

func _update_reload(delta: float) -> void:
	if reload_remaining <= 0.0:
		return
	if not is_instance_valid(rifle) or player.held_item != rifle or not player.is_on_floor() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_cancel_reload()
		return
	var art := rifle.get_node("RifleArt") as Node3D
	var progress: float = 1.0 - reload_remaining / rifle_reload_duration
	# Lower the weapon and hands, then return them smoothly to the firing pose.
	var dip: float = sin(progress * PI) * 0.20
	art.position.y = -dip
	duel_hands.position.y = -dip
	reload_remaining = maxf(0.0, reload_remaining - delta)
	if reload_remaining <= 0.0:
		rifle_ammo = rifle_magazine
		_cancel_reload()
		_update_reservoir()
	else:
		_update_hud()

func _cancel_reload() -> void:
	reload_remaining = 0.0
	if is_instance_valid(player):
		player.set("combat_reload_active", false)
	if is_instance_valid(rifle):
		var art := rifle.get_node_or_null("RifleArt") as Node3D
		if is_instance_valid(art):
			art.position.y = 0.0
	if is_instance_valid(duel_hands):
		duel_hands.position.y = 0.0
	_update_hud()

func _update_reservoir() -> void:
	if is_instance_valid(rifle):
		var reservoir := rifle.get_node_or_null("RifleArt/Reservoir") as Node3D
		if is_instance_valid(reservoir):
			reservoir.visible = rifle_ammo > 0
			reservoir.scale.y = maxf(0.10, float(rifle_ammo) / float(rifle_magazine))

func _dive_damage(melee: bool = false) -> void:
	if not active or finished or (not phase_two and not melee) or damage_grace > 0.0:
		return
	damage_grace = DAMAGE_GRACE
	player_hits += 1
	get_tree().call_group("makeshift_retro_fx", "pulse", 0.8, true)
	_update_hud()
	if player_hits >= PLAYER_HP:
		_finish(false)

func _air_warning(at: Vector3) -> void:
	_sound(at, LASER_CHARGE if is_instance_valid(air) and air.stage == AIR.Stage.AIM else preload("res://assets/audio/forest_sleigh_bell.wav"))

func _laser_sound(at: Vector3) -> void:
	_sound(at, LASER_FIRE)
	_shake(at, 0.012, 0.20)

func _air_impact(at: Vector3) -> void:
	_sound(at, HEAVY_IMPACT)
	_shake(at, 0.055, 0.42)
	SNOW_PUFF.spawn(arena, arena.to_local(at + Vector3.UP * 0.12), 55)
	_damage_cover_area(at, 1.8, 2)
	_impact_mark(at, 1.6)


# Only explicit cover is destructible; never the floor, boundaries or quest items.
func _register_cover(body: StaticBody3D, hp: int, persistent: bool, tree: bool) -> void:
	if not is_instance_valid(body) or breakables.has(body):
		return
	breakables[body] = {"hp": hp, "persistent": persistent, "tree": tree, "transform": body.transform, "layer": body.collision_layer, "mask": body.collision_mask, "visible": body.visible, "tween": null}

func _register_world_cover() -> void:
	if not is_instance_valid(embedded_player):
		return
	var clearing: Node = player.get_parent()
	var sleigh := clearing.get_node_or_null("Sleigh") as StaticBody3D
	if is_instance_valid(sleigh):
		_register_cover(sleigh, 4, true, false)
	var trees := clearing.get_node_or_null("BranchTrees")
	if is_instance_valid(trees):
		for child in trees.get_children():
			if child is StaticBody3D:
				_register_cover(child, 2, true, true)

func _charge_cover_hit(body: Object) -> void:
	if active and not phase_two:
		_damage_cover(body, 2)

func _laser_cover_hit(body: Object) -> void:
	if active and phase_two:
		_damage_cover(body, 2)

func _damage_cover_area(at: Vector3, radius: float, damage: int) -> void:
	for object in breakables.keys():
		var body := object as StaticBody3D
		if not is_instance_valid(body):
			continue
		var gap: Vector3 = body.global_position - at
		if Vector2(gap.x, gap.z).length() <= radius + 0.45:
			_damage_cover(body, damage)

func _damage_cover(object: Object, damage: int) -> void:
	if not is_instance_valid(object) or not breakables.has(object):
		return
	var body := object as StaticBody3D
	var data: Dictionary = breakables[body]
	if int(data["hp"]) <= 0:
		return
	data["hp"] = maxi(0, int(data["hp"]) - damage)
	var at: Vector3 = body.global_position
	_sound(at, HEAD_BREAK if int(data["hp"]) == 0 else HIT_SOUND)
	_snow_burst(at + Vector3.UP * 0.4)
	if int(data["hp"]) > 0:
		return
	body.set_deferred("collision_layer", 0)
	body.set_deferred("collision_mask", 0)
	var away: Vector3 = at - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	away = away.normalized()
	var fall := create_tween().set_parallel(true)
	data["tween"] = fall
	if bool(data["tree"]):
		fall.tween_property(body, "rotation", body.rotation + Vector3(away.z * 1.42, 0.0, -away.x * 1.42), 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		fall.tween_property(body, "position:y", body.position.y - 0.25, 0.35)
		fall.chain().tween_callback(body.hide)
	SNOW_PUFF.spawn(arena, arena.to_local(at + Vector3.UP * 0.2), 40)
	for i in range(9):
		var chunk := _box(arena, Vector3.ZERO, Vector3(0.10, 0.12, 0.16), bark if bool(data["tree"]) else dark)
		chunk.global_position = at + Vector3.UP * 0.45
		var end := at + Vector3(cos(i * 2.4), 0.07, sin(i * 2.4)) * 0.85
		var t := create_tween()
		t.tween_property(chunk, "global_position", end + Vector3.UP * 0.5, 0.20)
		t.tween_property(chunk, "global_position", end, 0.28)

func _restore_cover() -> void:
	for object in breakables.keys():
		if not is_instance_valid(object):
			continue
		var data: Dictionary = breakables[object]
		if not bool(data["persistent"]) or int(data["hp"]) > 0:
			continue
		var body := object as StaticBody3D
		var tween := data["tween"] as Tween
		if is_instance_valid(tween):
			tween.kill()
		body.transform = data["transform"]
		body.visible = bool(data["visible"])
		body.collision_layer = int(data["layer"])
		body.collision_mask = int(data["mask"])

func _impact_mark(at: Vector3, radius: float) -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = radius * 0.8
	disk.bottom_radius = radius * 0.8
	disk.height = 0.009
	disk.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.25, 0.33, 0.42, 0.28)
	var mark := _mesh(arena, Vector3.ZERO, disk, material)
	mark.global_position = at + Vector3.UP * 0.02
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _start_storm() -> void:
	if not active or finished or not phase_two or is_instance_valid(storm):
		return
	storm = STORM_SNOW.instantiate() as CPUParticles3D
	storm.set("target_path", player.get_path())
	storm.amount = 540
	storm.lifetime = 3.0
	storm.preprocess = 1.0
	storm.direction = Vector3(1.0, -0.35, 0.18).normalized()
	storm.spread = 23.0
	storm.initial_velocity_min = 2.3
	storm.initial_velocity_max = 3.8
	storm.gravity = Vector3(0.35, -0.2, 0.0)
	arena.add_child(storm)
	storm_env = get_world_3d().environment
	if is_instance_valid(storm_env):
		old_fog_enabled = storm_env.fog_enabled
		old_fog_density = storm_env.fog_density
		old_fog_color = storm_env.fog_light_color
		storm_env.fog_enabled = true
		storm_env.fog_density = maxf(0.095, old_fog_density if old_fog_enabled else 0.0)
		storm_env.fog_light_color = Color(0.39, 0.47, 0.59)
	_sound(player.global_position, preload("res://assets/audio/forest_sleigh_bell.wav"))

func _stop_storm() -> void:
	if is_instance_valid(storm):
		storm.set("snow_enabled", false)
		storm.emitting = false
		storm.hide()
		storm.queue_free()
		storm = null
	if is_instance_valid(storm_env):
		storm_env.fog_enabled = old_fog_enabled
		storm_env.fog_density = old_fog_density
		storm_env.fog_light_color = old_fog_color
		storm_env = null
