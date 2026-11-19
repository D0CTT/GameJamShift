extends Node3D
## Audio local al nivel. No modifica Player, GameState ni los gestores de escenas.
@export var target_path: NodePath
@export var forest_path: NodePath
@export var sound_enabled: bool = true
@export_range(-40.0, 0.0, 1.0) var wind_db: float = -19.0
@export_range(-40.0, 0.0, 1.0) var footsteps_db: float = -15.0
@export_range(-40.0, 0.0, 1.0) var breathing_db: float = -24.0
@export_range(-40.0, 0.0, 1.0) var branches_db: float = -17.0
@export var branches_enabled: bool = true
@export_range(2.0, 30.0, 0.5) var branch_interval_min: float = 7.0
@export_range(2.0, 40.0, 0.5) var branch_interval_max: float = 14.0
@export_range(0.2, 1.5, 0.05) var walking_stride: float = 0.85
@export_range(0.2, 1.5, 0.05) var running_stride: float = 1.05

## Assign one or more short, non-looping footstep sounds in the Inspector.
@export var footstep_sounds: Array[AudioStream] = [
	preload("res://assets/audio/ambience/snow_step_01.wav"),
	preload("res://assets/audio/ambience/snow_step_02.wav"),
	preload("res://assets/audio/ambience/snow_step_03.wav"),
	preload("res://assets/audio/ambience/snow_step_04.wav"),
]
const BREATHS: Array[AudioStream] = [
	preload("res://assets/audio/ambience/breath_01.wav"),
	preload("res://assets/audio/ambience/breath_02.wav"),
]
const BRANCHES: Array[AudioStream] = [
	preload("res://assets/audio/ambience/branch_snap_01.wav"),
	preload("res://assets/audio/ambience/branch_snap_02.wav"),
	preload("res://assets/audio/ambience/branch_snap_03.wav"),
]
@onready var wind: AudioStreamPlayer = $Wind
@onready var steps: AudioStreamPlayer = $Footsteps
@onready var breath: AudioStreamPlayer = $Breathing
@onready var snap: AudioStreamPlayer3D = $BranchSnap
var player: CharacterBody3D
var forest: Node
var stride_distance: float = 0.0
var was_moving: bool = false
var breath_clock: float = 0.0
var exertion: float = 0.0
var branch_clock: float = 8.0
var last_step: int = -1
var last_position: Vector3 = Vector3.ZERO
var last_position_valid: bool = false

func _ready() -> void:
	player = get_node_or_null(target_path) as CharacterBody3D
	forest = get_node_or_null(forest_path) if not forest_path.is_empty() else null
	# WAV original mono, PCM de 16 bits. Duplicar evita modificar otros recursos.
	var loop := wind.stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	wind.stream = loop
	wind.volume_db = -50.0
	_reset_branch_timer()

func _physics_process(delta: float) -> void:
	if not sound_enabled or not is_instance_valid(player):
		_stop_all()
		last_position_valid = false
		_reset_stride()
		return
	# El LevelManager aparca escenas fuera del arbol: reiniciar solo el viento
	# al volver sin depender de que _ready se ejecute otra vez.
	if not wind.playing:
		wind.play()
	var now: Vector3 = player.global_position
	var movement: float = 0.0
	if last_position_valid:
		movement = Vector2(now.x - last_position.x, now.z - last_position.z).length()
	last_position = now
	last_position_valid = true
	var scare: bool = is_instance_valid(forest) and bool(forest.get("event_started")) and not bool(forest.get("event_finished"))
	var traveling: bool = LevelManager.travel_busy
	var active: bool = bool(player.get("controls_enabled")) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not traveling
	var combat: bool = GameState.phase == GameState.Phase.COMBAT
	# Respetar el silencio previo al cascabel y al apagón.
	if scare:
		wind.volume_db = -60.0
		_stop_local()
		_reset_stride()
		exertion = 0.0
		return
	var forest_depth: float = clampf((-now.z - 5.0) / 8.0, 0.0, 1.0) if is_instance_valid(forest) else 0.0
	var target_db: float = wind_db + forest_depth * 2.0
	if combat:
		target_db -= 5.0
	if not active:
		target_db -= 8.0
	wind.volume_db = move_toward(wind.volume_db, target_db, delta * 22.0)
	if not active:
		_stop_local()
		_reset_stride()
		exertion = 0.0
		return
	# Medir desplazamiento real, no teclas: no hay pasos al chocar con un muro.
	# Ignorar teletransportes y cambios de escena.
	if movement > 0.65:
		movement = 0.0
		_reset_stride()
	var horizontal_speed: float = movement / maxf(delta, 0.001)
	var moving: bool = player.is_on_floor() and horizontal_speed > 0.2
	var running: bool = moving and horizontal_speed > 3.6
	if moving:
		if not was_moving:
			# Primera pisada al detectar movimiento real, sin esperar una zancada.
			_play_step(running)
			stride_distance = 0.0
		else:
			stride_distance += movement
			var stride: float = running_stride if running else walking_stride
			if stride_distance >= stride:
				stride_distance = fmod(stride_distance, stride)
				_play_step(running)
		was_moving = true
	else:
		_reset_stride()
	# Respiración después de correr un poco y recuperación gradual al parar.
	exertion = clampf(exertion + delta * (0.8 if running else -0.44), 0.0, 1.0)
	breath_clock = maxf(0.0, breath_clock - delta)
	if exertion > 0.45 and breath_clock <= 0.0 and not breath.playing:
		breath.stream = BREATHS[randi_range(0, BREATHS.size() - 1)]
		breath.volume_db = breathing_db + (2.0 if running else 0.0)
		breath.pitch_scale = randf_range(0.94, 1.12)
		breath.play()
		breath_clock = 1.05 if running else 1.6
	# Los crujidos son ambientales, no otro enemigo ni un nuevo susto obligatorio.
	if not branches_enabled or combat or forest_depth < 0.25:
		return
	branch_clock -= delta
	if branch_clock <= 0.0:
		_reset_branch_timer()
		var side: float = -1.0 if randf() < 0.5 else 1.0
		snap.global_position = now + player.global_transform.basis.x * side * randf_range(3.5, 5.0) + player.global_transform.basis.z * randf_range(1.0, 3.0) + Vector3.UP * 0.6
		snap.stream = BRANCHES[randi_range(0, BRANCHES.size() - 1)]
		snap.volume_db = branches_db
		snap.pitch_scale = randf_range(0.85, 1.15)
		snap.play()

func _play_step(running: bool) -> void:
	var available: Array[AudioStream] = []
	for sound in footstep_sounds:
		if sound != null:
			available.append(sound)
	if available.is_empty():
		last_step = -1
		return
	var index: int = randi_range(0, available.size() - 1)
	if available.size() > 1 and index == last_step:
		index = (index + 1) % available.size()
	last_step = index
	steps.stream = available[index]
	steps.volume_db = footsteps_db + (3.0 if running else 0.0)
	steps.pitch_scale = randf_range(0.94, 1.08)
	steps.play()

func _reset_stride() -> void:
	stride_distance = 0.0
	was_moving = false

func _reset_branch_timer() -> void:
	branch_clock = randf_range(branch_interval_min, maxf(branch_interval_min, branch_interval_max))

func _stop_local() -> void:
	steps.stop()
	breath.stop()
	snap.stop()

func _stop_all() -> void:
	wind.stop()
	_stop_local()

func _exit_tree() -> void:
	if is_instance_valid(wind):
		_stop_all()
	last_position_valid = false
	_reset_stride()
	breath_clock = 0.0
	exertion = 0.0
