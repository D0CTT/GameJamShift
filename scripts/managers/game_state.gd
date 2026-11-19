
extends Node

enum Phase {
	ASCENT,
	DESCENT,
	COMBAT
}

var phase: Phase = Phase.ASCENT

var current_level: int = 1
var level_01_completed: bool = false
var carried_item_id: StringName = &""

var skin_color: StringName = &"red"

var destroyed_objects: Dictionary = {}

func complete_level_01(item_id: StringName) -> void:
	level_01_completed = true
	carried_item_id = item_id

	print("Level 1 completed")
	print("Carried item: ", carried_item_id)
