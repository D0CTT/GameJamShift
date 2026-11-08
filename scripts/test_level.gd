
extends Node3D

# DURACION DE LA MISION EN SEGUNDOS
@export var mission_duration: float = 300.0

# REFERENCIAS
@onready var mission_timer: Timer = $MissionTimer
@onready var time_label: Label = $MissionHUD/TimeLabel
@onready var result_label: Label = $MissionHUD/ResultLabel
@onready var player: CharacterBody3D = $Player

var mission_finished: bool = false


func _ready() -> void:
	# Preparar el temporizador
	mission_timer.one_shot = true
	mission_timer.wait_time = mission_duration

	# Conectar su señal de finalizacion
	mission_timer.timeout.connect(_on_time_up)

	# Ocultar el mensaje final
	result_label.hide()

	# Iniciar la cuenta atras
	mission_timer.start()
	update_timer_display()


func _process(_delta: float) -> void:
	if mission_finished:
		return

	update_timer_display()


func update_timer_display() -> void:
	var total_seconds: int = int(ceil(mission_timer.time_left))

	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	time_label.text = "LLEGADA DEL PRESIDENTE: %02d:%02d" % [
		minutes,
		seconds
	]

	# Cambiar de color cuando quede poco tiempo
	if total_seconds <= 30:
		time_label.add_theme_color_override(
			"font_color", Color("#FF5555")
		)
	else:
		time_label.add_theme_color_override(
			"font_color", Color("#7BE3A2")
		)


func _on_time_up() -> void:
	mission_finished = true
	update_timer_display()

	# Comprobar si quedan cambiaformas
	var enemies_remaining: bool = false

	for enemy in get_tree().get_nodes_in_group("shapeshifter"):
		if is_instance_valid(enemy):
			if not enemy.is_queued_for_deletion():
				enemies_remaining = true
				break

	if enemies_remaining:
		result_label.text = "MISIÓN FALLIDA\nEl presidente está en peligro."
	else:
		result_label.text = "MISIÓN COMPLETADA\nInstalación asegurada."

	result_label.show()

	# Detener al jugador
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	# Mostrar el cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
