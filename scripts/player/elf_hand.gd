extends Node3D
## Local axes: fingers -Z, wrist +Z. The left hand has its thumb at +X.
@onready var model: Node3D = $Model
@onready var skin: StandardMaterial3D = $Model/Palm.material_override

func configure(right_side: bool, skin_color: StringName, curl: float) -> void:
	model.scale.x = -1.0 if right_side else 1.0
	set_skin(skin_color)
	set_curl(curl)

func set_skin(value: StringName) -> void:
	var green := value == &"green"
	skin.albedo_color = Color(0.32, 0.57, 0.22) if green else Color(0.72, 0.055, 0.055)
	skin.roughness = 0.82 if green else 0.22
	skin.metallic = 0.0 if green else 0.15

## 0 = open hand, 1 = closed fist. Intermediate value supports gripping.
func set_curl(amount: float) -> void:
	var value := clampf(amount, 0.0, 1.0)
	for i in range(4):
		var finger := model.get_node("Finger%d" % i) as Node3D
		finger.rotation.x = -1.40 * value
		(finger.get_node("TipPivot") as Node3D).rotation.x = -1.45 * value
	($Model/Thumb as Node3D).rotation.z = -0.55 * value
