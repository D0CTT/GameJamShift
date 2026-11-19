extends Node3D
## Standalone arena test. The finale is intentionally not decided here.
signal combat_finished(victory: bool)
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
@onready var player = $Player
@onready var camera: Camera3D = $Player/Head/Camera3D
@onready var head: Node3D = $Player/Head
@onready var hud: CanvasLayer = $Player/HUD
@onready var arena: Node3D = $Arena
@onready var shots: Node3D = $Projectiles
var santa: StaticBody3D
var model: Node3D
var arm: Node3D
var santa_ball: MeshInstance3D
var santa_hits := 0
var player_hits := 0
var active := false
var finished := false
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
var snow: StandardMaterial3D
var red: StandardMaterial3D
var dark: StandardMaterial3D
var cream: StandardMaterial3D
var bark: StandardMaterial3D
var pine: StandardMaterial3D

func _ready() -> void:
	_register_translation()
	_build_arena()
	_build_santa()
	_build_duel_hands()
	_build_hud()
	player.held_item_changed.connect(_on_item_changed)
	player.call("set_controls_enabled", false)
	hud.hide()
	stats.hide()
	if play_intro:
		_run_duel.call_deferred()
	else:
		_start_fight()

func _exit_tree() -> void:
	if is_instance_valid(spanish):
		TranslationServer.remove_translation(spanish)

func _register_translation() -> void:
	spanish = Translation.new()
	spanish.locale = "es"
	var messages := {"DEFEAT SANTA":"DERROTA A SANTA", "Santa: %d / 5":"Santa: %d / 5", "Elf: %d / 3":"Elfo: %d / 3", "E - Make snowball   |   Left click - Throw   |   Q - Drop":"E - Formar bola   |   Clic izq. - Lanzar   |   Q - Soltar", "Snowball ready":"Bola preparada", "Hands empty":"Manos libres", "VICTORY":"VICTORIA", "GAME OVER":"FIN DE LA PARTIDA", "Retry (R)":"Reintentar (R)"}
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
		get_tree().call_deferred("reload_current_scene")
		return
	if not active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("interact"):
		form_requested = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		throw_requested = true
		get_viewport().set_input_as_handled()

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
	attack_clock -= delta
	if attack_clock <= 0.0:
		if not winding:
			winding = true
			attack_clock = maxf(0.2, santa_windup)
			santa_ball.show()
			create_tween().tween_property(arm, "rotation:x", -1.25, minf(0.4, attack_clock))
		else:
			winding = false
			attack_clock = maxf(0.2, santa_throw_interval - santa_windup)
			_throw_santa(true)

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
	_spawn_shot(camera.global_position + direction * 0.06, direction * player_projectile_speed, player, true)

func _throw_santa(damage: bool) -> void:
	var start := santa_ball.global_position
	var target: Vector3 = player.global_position + Vector3.UP * 0.55
	var diff := target - start
	var duration := diff.length() / maxf(1.0, santa_projectile_speed)
	var initial := diff / maxf(duration, 0.05) + Vector3.UP * (1.2 * duration)
	santa_ball.hide()
	create_tween().tween_property(arm, "rotation:x", 0.0, 0.22)
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
		if santa_hits >= SANTA_HP:
			_finish(true)
		else:
			var t := create_tween()
			t.tween_property(model, "rotation:z", 0.09, 0.10)
			t.tween_property(model, "rotation:z", 0.0, 0.20)
	elif collider == player and shooter == santa:
		player_hits += 1
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
	var form := create_tween().set_parallel(true)
	form.tween_property(head, "rotation:x", -0.55, 0.48)
	form.tween_property(model, "position:y", -0.26, 0.48)
	form.tween_property(arm, "rotation:x", -0.55, 0.48)
	await form.finished
	var visual := _sphere(player.hold_point, Vector3.ZERO, 0.10, snow)
	duel_hands.show()
	santa_ball.show()
	await get_tree().create_timer(0.35, false).timeout
	var raise := create_tween().set_parallel(true)
	raise.tween_property(head, "rotation:x", atan2(gaze.y, Vector2(gaze.x, gaze.z).length()), 0.50)
	raise.tween_property(model, "position:y", 0.0, 0.50)
	raise.tween_property(arm, "rotation:x", -1.25, 0.50)
	await raise.finished
	await get_tree().create_timer(0.35, false).timeout
	visual.queue_free()
	duel_hands.hide()
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
	winding = false
	form_requested = false
	throw_requested = false
	santa_ball.hide()
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
	duel_hands.visible = is_instance_valid(player.held_item)
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
	restart_btn.pressed.connect(func(): get_tree().call_deferred("reload_current_scene"))
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
	_solid(Vector3(0,-0.2,0), Vector3(24,0.4,24), snow)
	for side in [-1, 1]:
		_solid(Vector3(side*12, 3, 0), Vector3(0.5,6,24), dark, false)
		_solid(Vector3(0, 3, side*12), Vector3(24,6,0.5), dark, false)
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
	player.hold_point.add_child(duel_hands)
	var skin := _mat(Color(0.26,0.50,0.19))
	for side in [-1,1]:
		_sphere(duel_hands,Vector3(side*0.09,-0.065,0.055),0.060,skin,Vector3(0.85,0.75,1.15))
		_box(duel_hands,Vector3(side*0.11,-0.13,0.14),Vector3(0.12,0.19,0.21),red).rotation.x = -0.48
	duel_hands.hide()

func _build_santa() -> void:
	santa = StaticBody3D.new()
	arena.add_child(santa)
	santa.name = "Santa"
	santa.position = Vector3(0,0,-4.5)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.85
	collider.shape = shape
	collider.position.y = 0.925
	santa.add_child(collider)
	model = Node3D.new()
	santa.add_child(model)
	_sphere(model,Vector3(0,0.94,0),0.40,red,Vector3(1.0,1.13,0.78))
	_box(model,Vector3(0,0.79,0.015),Vector3(0.95,0.13,0.63),dark)
	_box(model,Vector3(0,0.79,0.345),Vector3(0.19,0.15,0.045),_mat(Color(0.92,0.65,0.16)))
	_box(model,Vector3(0,1.01,0.31),Vector3(0.07,0.36,0.05),cream)
	for side in [-1,1]:
		_box(model,Vector3(side*0.18,0.33,0),Vector3(0.25,0.52,0.27),red)
		_box(model,Vector3(side*0.18,0.12,0.07),Vector3(0.31,0.22,0.39),dark)
	var skin := _mat(Color(0.85,0.58,0.43))
	_sphere(model,Vector3(0,1.49,0),0.25,skin)
	_sphere(model,Vector3(0,1.36,0.16),0.22,cream,Vector3(1.0,1.05,0.6))
	_sphere(model,Vector3(0,1.51,0.25),0.06,skin)
	for side in [-1,1]:
		_sphere(model,Vector3(side*0.09,1.57,0.22),0.022,dark)
	_box(model,Vector3(0,1.69,0),Vector3(0.49,0.095,0.41),cream)
	_cone(model,Vector3(0,1.84,0),0.235,0.30,red)
	_sphere(model,Vector3(0,1.99,0),0.065,cream)
	_box(model,Vector3(-0.45,1.03,0),Vector3(0.19,0.48,0.20),red).rotation.z = -0.25
	arm = Node3D.new()
	model.add_child(arm)
	arm.position = Vector3(0.40,1.23,0)
	_box(arm,Vector3(0,-0.21,0),Vector3(0.20,0.44,0.20),red)
	_sphere(arm,Vector3(0,-0.45,0),0.10,dark)
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
