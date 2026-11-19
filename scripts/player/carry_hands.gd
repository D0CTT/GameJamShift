extends Node3D
const HAND = preload("res://scenes/art/player/elf_hand.tscn")
var player: CharacterBody3D
var hands: Array[Node3D] = []
var lift: float = 0.0
var clock: float = 0.0

func _ready() -> void:
	for i in range(2):
		var hand := HAND.instantiate() as Node3D
		add_child(hand)
		hand.call("configure", i == 1, GameState.skin_color, 0.68)
		hands.append(hand)
	hide()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		hide()
		return
	var item := player.get("held_item") as Node3D
	var carrying := is_instance_valid(item) and GameState.phase != GameState.Phase.COMBAT and bool(player.get("controls_enabled"))
	lift = move_toward(lift, 1.0 if carrying else 0.0, delta * 7.0)
	visible = lift > 0.01 and is_instance_valid(item) and GameState.phase != GameState.Phase.COMBAT and bool(player.get("controls_enabled"))
	if not visible:
		return
	clock += delta * (3.5 + Vector2(player.velocity.x, player.velocity.z).length() * 2.0)
	# Follow the existing HoldPoint. Hands are visual only.
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		hands[i].position = Vector3(side * 0.145, -0.105 - (1.0-lift)*0.24 + sin(clock)*0.008, 0.12)
		hands[i].rotation = Vector3(-0.30, side * 0.28, side * -0.14)
		hands[i].call("set_skin", GameState.skin_color)
