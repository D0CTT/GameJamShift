
extends StaticBody3D

# CONFIGURACION DEL OBJETO
@export var object_name: String = "Objeto"
@export var is_shapeshifter: bool = false

# COMPONENTES
@export var visual_node: Node3D
@export var clue_sound: AudioStreamPlayer3D

# CONFIGURACION DE LAS PISTAS
@export_range(0.0, 1.0, 0.01) var false_clue_probability: float = 0.12

@export var min_clue_interval: float = 5.0
@export var max_clue_interval: float = 11.0
@export var shake_degrees: float = 3.0

# VARIABLES INTERNAS
var clue_timer: Timer
var original_rotation: Vector3
var produces_clues: bool = false


func _ready() -> void:
	# Registrar cambiaformas para el final de mision
	if is_shapeshifter:
		add_to_group("shapeshifter")

	# Decidir si este objeto producira pistas
	if is_shapeshifter:
		produces_clues = true
	else:
		produces_clues = randf() < false_clue_probability

	if not produces_clues:
		return

	if visual_node == null:
		push_warning("Falta asignar Visual Node en: " + name)
		return

	original_rotation = visual_node.rotation

	# Crear temporizador de pistas
	clue_timer = Timer.new()
	clue_timer.one_shot = true
	add_child(clue_timer)

	clue_timer.timeout.connect(_on_clue_timer_timeout)

	schedule_next_clue()


func schedule_next_clue() -> void:
	var minimum: float = maxf(min_clue_interval, 1.0)
	var maximum: float = maxf(max_clue_interval, minimum)

	clue_timer.start(randf_range(minimum, maximum))


func _on_clue_timer_timeout() -> void:
	if not is_instance_valid(visual_node):
		return

	# Reproducir sonido, si existe
	if clue_sound != null and clue_sound.stream != null:
		clue_sound.play()

	# Crear un temblor breve
	var angle: float = deg_to_rad(shake_degrees)

	var tween: Tween = create_tween()

	tween.tween_property(
		visual_node,
		"rotation",
		original_rotation + Vector3(0, 0, angle),
		0.08
	)

	tween.tween_property(
		visual_node,
		"rotation",
		original_rotation + Vector3(0, 0, -angle),
		0.08
	)

	tween.tween_property(
		visual_node,
		"rotation",
		original_rotation,
		0.16
	)

	# Preparar el siguiente comportamiento
	schedule_next_clue()


func interact() -> void:
	print("Inspeccionando: ", object_name)


func vacuum_up() -> void:
	# Registrar daño si era inocente
	if not is_shapeshifter:
		get_tree().call_group(
			"mission_controller",
            "register_innocent_absorption"
		)

	# Desaparecer independientemente de la identidad
	queue_free()
