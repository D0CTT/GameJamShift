extends "res://scripts/components/pickup.gd"

func set_placed() -> void:
	super.set_placed()
	$Folded.hide()
	$Worn.show()
	# La bufanda puesta es decorativa; no tapa el acceso a otras piezas.
	collision_layer = 0
	collision_mask = 0

func set_carried() -> void:
	super.set_carried()
	$Folded.show()
	$Worn.hide()

func set_returned() -> void:
	super.set_returned()
	$Folded.show()
	$Worn.hide()
