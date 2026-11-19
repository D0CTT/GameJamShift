extends StaticBody3D

const SNOW_PUFF = preload("res://scripts/components/snow_puff.gd")
@export_enum("Gift", "Bell", "Pine") var kind: int = 0
@onready var pivot: Node3D = $Pivot
@onready var sound: AudioStreamPlayer3D = $Sound
var busy: bool = false
var opened: bool = false
var scarf_taken: bool = false
@onready var scarf: StaticBody3D = get_node_or_null("Scarf") as StaticBody3D

func _ready() -> void:
	if kind == 0 and is_instance_valid(scarf):
		# Se recoge interactuando con el regalo abierto; su caja intercepta el rayo.
		scarf.collision_layer = 0
		scarf.collision_mask = 0

func interact_with_player(player: Node) -> void:
	if busy or GameState.phase != GameState.Phase.ASCENT:
		return
	if not is_instance_valid(player) or is_instance_valid(player.get("held_item")):
		return
	if kind == 0 and opened and not scarf_taken and is_instance_valid(scarf):
		if player.has_method("try_pickup") and player.call("try_pickup", scarf):
			scarf_taken = true
			sound.play()
		return
	busy = true
	_run_animation.call_deferred()

func _run_animation() -> void:
	if not is_inside_tree():
		busy = false
		return
	var anim := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sound.play()
	match kind:
		0:
			opened = not opened
			anim.tween_property(pivot, "rotation:x", -1.65 if opened else 0.0, 0.42)
		1:
			for angle in [0.48, -0.42, 0.30, -0.20, 0.10, 0.0]:
				anim.tween_property(pivot, "rotation:z", angle, 0.085)
		2:
			SNOW_PUFF.spawn(self, Vector3(0, 0.95, 0), 36, true)
			for angle in [0.12, -0.13, 0.09, -0.07, 0.04, 0.0]:
				anim.tween_property(pivot, "rotation:z", angle, 0.09)
	await anim.finished
	busy = false
