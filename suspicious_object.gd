
extends StaticBody3D

@export var object_name: String = "Caja de archivos"
@export var is_shapeshifter: bool = true


func interact() -> void:
	print("Inspeccionando: ", object_name)

	if is_shapeshifter:
		print("¡Algo extraño ocurre con este objeto!")
	else:
		print("Parece un objeto completamente normal.")
