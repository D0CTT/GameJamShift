extends Node3D
## Generación semiprocedural: puntos despejados, sin duplicar objetos ni alterar la historia.
@export var generation_seed: int = -1 # -1: aleatoria; >= 0: reproducible
const CARROT_PUZZLE = preload("res://scripts/levels/carrot_puzzle.gd")
var active_seed: int
var generated := false

func _ready() -> void:
	if generated:
		return
	generated = true
	var rng := RandomNumberGenerator.new()
	if generation_seed < 0:
		rng.randomize()
	else:
		rng.seed = generation_seed
	active_seed = rng.seed
	# Puntos sobre el suelo, separados de árboles, montículos, accidente,
	# acceso al bosque y zona de montaje. Cada punto se utiliza una sola vez.
	var points: Array[Vector2] = [
		Vector2(-2.8, 4.0), Vector2(2.8, 4.65),
		Vector2(-2.3, 6.0), Vector2(0.0, 5.65), Vector2(2.1, 6.35),
		Vector2(-1.8, 8.0), Vector2(0.3, 7.65), Vector2(2.15, 8.3),
		Vector2(-2.1, 10.15), Vector2(0.0, 10.65), Vector2(2.1, 10.4),
		Vector2(-2.1, -3.65), Vector2(2.5, -3.65)
	]
	_shuffle(points, rng)
	var items: Array[Node3D] = [$LargeSnowball, $MediumSnowball, $SnowmanHead, $OptionalInteractions/SpilledGift, $OptionalInteractions/LooseBell]
	for i in range(items.size()):
		var item := items[i]
		var ground_point := points[i]
		# Conservar altura y orientación originales (los objetos no flotan).
		item.position.x = ground_point.x
		item.position.z = ground_point.y
	# Dos ramas de cuatro árboles. Los objetos permanecen hijos del claro,
	# para que Q, recogida y montaje conserven el contrato existente.
	var trees: Array[Node] = $BranchTrees.get_children()
	_shuffle_nodes(trees, rng)
	var branches: Array[Node3D] = [$Branch1, $Branch2]
	for i in range(branches.size()):
		var marker := trees[i].get_node("BranchPoint") as Marker3D
		branches[i].global_transform = marker.global_transform
	# La zanahoria es un puzle fijo, no forma parte del sorteo.
	var puzzle := CARROT_PUZZLE.new()
	puzzle.name = "CarrotPuzzle"
	add_child(puzzle)
	print("Level 1 clearing seed: ", active_seed)

func _shuffle(points: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for i in range(points.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous := points[i]
		points[i] = points[j]
		points[j] = previous

func _shuffle_nodes(nodes: Array[Node], rng: RandomNumberGenerator) -> void:
	for i in range(nodes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous := nodes[i]
		nodes[i] = nodes[j]
		nodes[j] = previous
