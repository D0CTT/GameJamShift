extends StaticBody3D

@export var item_id: StringName = &"snowball_large"

var available: bool = true
var original_layer: int
var original_mask: int


func _ready() -> void:
	original_layer = collision_layer
	original_mask = collision_mask


func interact_with_player(player: Node) -> void:
	if available and player.has_method("try_pickup"):
		player.call("try_pickup", self)


func set_carried() -> void:
	available = false
	# El objeto no bloquea ni el cuerpo del jugador ni su RayCast.
	collision_layer = 0
	collision_mask = 0


func set_placed() -> void:
	# Las piezas ya montadas no se recogen otra vez en este prototipo.
	collision_layer = original_layer
	collision_mask = original_mask


func set_returned() -> void:
	available = true
	collision_layer = original_layer
	collision_mask = original_mask
