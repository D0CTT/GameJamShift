extends StaticBody3D

signal piece_placed(item_id: StringName)

@export var required_item: StringName = &"snowball_large"
@onready var placement_point: Marker3D = $PlacementPoint
@onready var preview: MeshInstance3D = $Preview
var filled: bool = false


func interact_with_player(player: Node) -> void:
	if filled or not player.has_method("try_place"):
		return
	if player.call("try_place", required_item, placement_point):
		filled = true
		preview.hide()
		piece_placed.emit(required_item)
		print("Pieza colocada: ", required_item)
