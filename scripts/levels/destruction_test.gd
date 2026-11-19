extends Node3D
## Only this test scene forces the narrative phase. A real level never does this.
const RETRO_FX = preload("res://scenes/components/retro_effects.tscn")
@export var debug_start_in_destruction: bool = true
@onready var objective: Label = $Player/HUD/Objective

func _ready() -> void:
	if get_tree().get_first_node_in_group("makeshift_retro_fx") == null:
		add_child(RETRO_FX.instantiate())
	GameState.phase = GameState.Phase.DESCENT if debug_start_in_destruction else GameState.Phase.ASCENT
	if debug_start_in_destruction:
		GameState.skin_color = &"green"
		objective.text = "MAKE SHIT CHRISTMAS"
		objective.add_theme_color_override("font_color", Color(1.0, 0.23, 0.26))
	for target in get_tree().get_nodes_in_group("destructible"):
		if is_ancestor_of(target):
			target.connect("destroyed", _on_target_destroyed)

func _on_target_destroyed(object_id: StringName) -> void:
	print("Destroyed: ", object_id)
	for target in get_tree().get_nodes_in_group("destructible"):
		if is_ancestor_of(target) and not bool(target.get("is_destroyed")):
			return
	print("All destruction targets completed")
