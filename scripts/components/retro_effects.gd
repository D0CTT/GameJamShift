extends CanvasLayer
## Screen-only effects. No camera, physics, light or audio changes.
@export var effects_enabled: bool = true
@export_range(180, 1080, 1) var virtual_height: int = 480
@export_range(8, 64, 1) var color_levels: int = 32
@export_range(0.0, 1.0, 0.05) var retro_mix: float = 0.65
@export_range(0.0, 0.6, 0.01) var vignette: float = 0.16
@export_range(0.0, 0.05, 0.001) var grain: float = 0.008
@export var event_effects: bool = true
@onready var screen: ColorRect = $Screen
@onready var buffer: BackBufferCopy = $BackBufferCopy
var material_instance: ShaderMaterial
var tension_target: float = 0.0
var tension_amount: float = 0.0
var impact_amount: float = 0.0
var damage_amount: float = 0.0
var last_settings: Array = []

func _ready() -> void:
	add_to_group("makeshift_retro_fx")
	material_instance = screen.material.duplicate() as ShaderMaterial
	screen.material = material_instance
	_apply_settings()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		effects_enabled = not effects_enabled
		_apply_settings()
		get_viewport().set_input_as_handled()
		print("Retro effects: ", "ON" if effects_enabled else "OFF")

func _apply_settings() -> void:
	if not is_instance_valid(material_instance):
		return
	var settings: Array = [effects_enabled, virtual_height, color_levels, retro_mix, vignette, grain]
	if settings == last_settings:
		return
	last_settings = settings
	screen.visible = effects_enabled
	buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if effects_enabled else BackBufferCopy.COPY_MODE_DISABLED
	material_instance.set_shader_parameter("virtual_height", float(virtual_height))
	material_instance.set_shader_parameter("color_levels", float(color_levels))
	material_instance.set_shader_parameter("retro_mix", retro_mix)
	material_instance.set_shader_parameter("vignette", vignette)
	material_instance.set_shader_parameter("grain", grain)

func set_tension(active: bool) -> void:
	tension_target = 1.0 if active else 0.0

func pulse(strength: float = 0.6, received_damage: bool = false) -> void:
	if not effects_enabled or not event_effects:
		return
	impact_amount = maxf(impact_amount, clampf(strength, 0.0, 1.0))
	if received_damage:
		damage_amount = maxf(damage_amount, impact_amount)

func _process(delta: float) -> void:
	# Inspector changes also work from the Remote tree during play.
	_apply_settings()
	tension_amount = move_toward(tension_amount, tension_target if event_effects else 0.0, delta * 2.4)
	impact_amount = move_toward(impact_amount, 0.0, delta * 3.0)
	damage_amount = move_toward(damage_amount, 0.0, delta * 1.8)
	if not event_effects:
		impact_amount = 0.0
		damage_amount = 0.0
	if not effects_enabled:
		return
	material_instance.set_shader_parameter("tension", tension_amount)
	material_instance.set_shader_parameter("impact", impact_amount)
	material_instance.set_shader_parameter("damage", damage_amount)
