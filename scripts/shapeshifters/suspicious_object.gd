
extends StaticBody3D

@export var object_name: String = "Objeto"
@export var is_shapeshifter: bool = false


func _ready() -> void:
	if is_shapeshifter:
		add_to_group("shapeshifter")

func interact() -> void:
	print("Inspeccionando: ", object_name)


func vacuum_up() -> bool:
	var was_shapeshifter: bool = is_shapeshifter

	if was_shapeshifter:
		print("¡Cambiaformas eliminado!")
	else:
		print("Objeto normal absorbido: ", object_name)

	# Todos los objetos desaparecen
	queue_free()

	# Informamos al jugador del tipo de objeto
	return was_shapeshifter
