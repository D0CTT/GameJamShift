extends "res://scripts/components/pickup.gd"

signal taken_from_snowman
var on_snowman: bool = false

func set_carried() -> void:
	super.set_carried()
	if on_snowman:
		on_snowman = false
		taken_from_snowman.emit()
