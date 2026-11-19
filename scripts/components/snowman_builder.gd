extends Node3D

signal snowman_completed
signal battery_revealed(battery_item: Node3D)

@onready var slots: Array[StaticBody3D] = [$BaseSlot, $TorsoSlot, $HeadSlot, $CarrotSlot]
@onready var battery: StaticBody3D = get_node_or_null("Battery") as StaticBody3D
@onready var placement_sound: AudioStreamPlayer3D = get_node_or_null("PlacementSound") as AudioStreamPlayer3D
@onready var celebration_sound: AudioStreamPlayer3D = get_node_or_null("CelebrationSound") as AudioStreamPlayer3D
var stage: int = 0
var complete: bool = false

func _ready() -> void:
	for slot in slots:
		slot.connect("piece_placed", _on_piece_placed)
		set_slot_active(slot, false)
	set_slot_active(slots[0], true)
	# Los hijos ya ejecutaron _ready: Pickup conserva sus capas originales.
	if is_instance_valid(battery):
		battery.hide()
		battery.call("set_carried")

func set_slot_active(slot: StaticBody3D, active: bool) -> void:
	slot.get_node("Preview").visible = active
	slot.collision_layer = 1 if active else 0
	slot.collision_mask = 0

func _on_piece_placed(_item_id: StringName) -> void:
	if complete:
		return
	set_slot_active(slots[stage], false)
	stage += 1
	if stage == slots.size():
		complete = true
		print("¡Muñeco de nieve completo!")
		if is_instance_valid(celebration_sound):
			celebration_sound.play()
		snowman_completed.emit()
		if is_instance_valid(battery):
			_play_head_fall()
	else:
		if is_instance_valid(placement_sound):
			placement_sound.play()
		set_slot_active(slots[stage], true)

func _play_head_fall() -> void:
	# Pausa deliberada después de la celebración.
	await get_tree().create_timer(2.0, false).timeout
	var head_point: Node3D = slots[2].get_node("PlacementPoint") as Node3D
	var carrot_point: Node3D = slots[3].get_node("PlacementPoint") as Node3D
	if head_point.get_child_count() == 0 or carrot_point.get_child_count() == 0:
		return
	var head_item: StaticBody3D = head_point.get_child(0) as StaticBody3D
	var carrot: StaticBody3D = carrot_point.get_child(0) as StaticBody3D
	if not is_instance_valid(head_item) or not is_instance_valid(carrot):
		return
	# La nariz acompaña a la cabeza. No se simula una caída física.
	head_item.collision_layer = 0
	head_item.collision_mask = 0
	carrot.collision_layer = 0
	carrot.collision_mask = 0
	head_item.reparent(self, true)
	carrot.reparent(head_item, true)
	var start: Vector3 = head_item.position
	var tilt := create_tween()
	tilt.tween_property(head_item, "rotation:z", -0.40, 0.45).set_trans(Tween.TRANS_SINE)
	tilt.parallel().tween_property(head_item, "position:x", start.x + 0.14, 0.45)
	await tilt.finished
	var fall := create_tween()
	fall.tween_property(head_item, "position", Vector3(0.88, 0.16, 0.0), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(head_item, "rotation:z", -1.35, 0.48)
	await fall.finished
	# La batería sale desde la cabeza y queda disponible en la nieve.
	battery.position = Vector3(0.88, 0.17, 0.0)
	battery.show()
	var pop := create_tween()
	pop.tween_property(battery, "position", Vector3(1.10, 0.45, 0.12), 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(battery, "position", Vector3(1.30, 0.105, 0.22), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pop.finished
	battery.call("set_returned")
	battery_revealed.emit(battery)
	print("¡Una batería salió de la cabeza!")
