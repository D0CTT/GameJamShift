extends Node3D
## Exterior de prueba. Volver por el camino conecta con la instancia del bosque.
@export var debug_start_with_lights: bool = false
@export var debug_allow_descent: bool = true
var descent_hint: Label
@export_file("*.tscn") var previous_level_scene: String = "res://tests/test_level_01.tscn"
@onready var player: CharacterBody3D = $Player
@onready var items: Node3D = $WorldItems

func _ready() -> void:
	if debug_allow_descent:
		descent_hint = Label.new()
		player.get_node("HUD").add_child(descent_hint)
		descent_hint.position = Vector2(24, 66)
		descent_hint.add_theme_font_size_override("font_size", 18)
		descent_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
		descent_hint.add_theme_constant_override("shadow_offset_x", 2)
		descent_hint.add_theme_constant_override("shadow_offset_y", 2)
		descent_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		descent_hint.text = "B - Simulate descent (test only)"
	_update_phase_hud()
	# El gestor de ida/vuelta transfiere el objeto real cuando termina el fundido.
	if LevelManager.travel_busy:
		return
	if debug_start_with_lights and not GameState.carried_item_pending and not GameState.level_01_completed:
		GameState.prepare_item_transfer(&"powered_lights")
	GameState.current_level = 2
	if not LevelManager.restore_carried_item(player, items):
		push_error("Level 2: carried item restoration failed")

func _unhandled_input(event: InputEvent) -> void:
	if not debug_allow_descent or LevelManager.travel_busy or not GameState.level_01_completed or GameState.phase != GameState.Phase.ASCENT:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Only in this temporary cabin, simulate the summit and destroyed exterior lights.
		var held := player.get("held_item") as Node3D
		if is_instance_valid(held) and held.get("item_id") == &"powered_lights":
			player.set("held_item", null)
			player.set("pickup_parent", null)
			player.set("drop_requested", false)
			held.hide()
			held.queue_free()
			player.emit_signal("held_item_changed", null)
			GameState.carried_item_id = &""
		GameState.begin_descent()
		_update_phase_hud()
		get_viewport().set_input_as_handled()

func _update_phase_hud() -> void:
	var down: bool = GameState.phase == GameState.Phase.DESCENT
	var objective := player.get_node("HUD/Objective") as Label
	objective.text = "MAKE SHIT CHRISTMAS" if down else "MAKE/SHIFT CHRISTMAS"
	objective.add_theme_color_override("font_color", Color(1, 0.23, 0.26) if down else Color.WHITE)
	if is_instance_valid(descent_hint):
		descent_hint.visible = GameState.level_01_completed and not down

func _physics_process(_delta: float) -> void:
	if LevelManager.travel_busy:
		return
	# Cruza ANTES de las barreras laterales de nieve. Toda la anchura es válida:
	# no se exige pisar una franja estrecha ni llevar luces en la mano.
	if player.global_position.z >= 6.2:
		LevelManager.travel_between.call_deferred(1, previous_level_scene)

func get_travel_player() -> Node3D:
	return player

func get_travel_items() -> Node3D:
	return items

func prepare_travel_arrival() -> void:
	_update_phase_hud()
	player.global_position = Vector3(0.0, 0.05, 3.8)
	player.rotation.y = 0.0
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	player.velocity = Vector3.ZERO
