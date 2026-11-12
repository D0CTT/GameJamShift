
extends StaticBody3D

var already_pressed: bool = false


# Cuando pulsa el jugador con E
func interact() -> void:
	if already_pressed:
		return

	already_pressed = true

	get_tree().call_group(
		"mission_controller",
        "on_president_called_by_player"
	)


# Cuando llega un cambiaformas
func press_by_shapeshifter() -> void:
	if already_pressed:
		return

	already_pressed = true

	get_tree().call_group(
		"mission_controller",
        "on_president_called_by_shapeshifter"
	)
