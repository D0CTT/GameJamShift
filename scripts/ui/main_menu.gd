
extends Control

# Paleta de colores
const GREEN := Color("#8AFFA7")
const GREEN_DARK := Color("#478C5A")
const GREEN_BORDER := Color("#244B31")
const BG_COLOR := Color("#07110D")
const BUTTON_BG := Color("#091710")
const BUTTON_HOVER := Color("#102B19")

# Referencias
@onready var title: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var prompt: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Prompt
@onready var status: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/StatusLabel

@onready var new_game: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var options: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ExitButton

var blink_timer := 0.0
var cursor_visible := true


func _ready() -> void:
	# Conectar botones
	new_game.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)
	options.pressed.connect(_on_options)
	exit_button.pressed.connect(_on_exit)

	# Configuración inicial
	continue_button.disabled = true

	# Aplicar estética
	_setup_interface()

	print("THE SHAPESHIFTER - SYSTEM ONLINE")


func _process(delta: float) -> void:
	# Cursor parpadeante
	blink_timer += delta

	if blink_timer >= 0.5:
		blink_timer = 0.0
		cursor_visible = not cursor_visible

		prompt.text = "SELECT OPERATION: " + ("█" if cursor_visible else " ")


func _setup_interface() -> void:
	# Fondo
	$Background.color = BG_COLOR

	# Título
	title.add_theme_color_override("font_color", GREEN)
	title.add_theme_font_size_override("font_size", 36)

	# Subtítulo
	subtitle.add_theme_color_override("font_color", GREEN_DARK)
	subtitle.add_theme_font_size_override("font_size", 13)

	# Estado del sistema
	status.add_theme_color_override("font_color", GREEN)
	status.add_theme_font_size_override("font_size", 12)

	# Prompt
	prompt.add_theme_color_override("font_color", GREEN_DARK)
	prompt.add_theme_font_size_override("font_size", 14)

	# Botones
	_style_button(new_game, "01  >  NEW GAME")
	_style_button(continue_button, "02  >  CONTINUE")
	_style_button(options, "03  >  OPTIONS")
	_style_button(exit_button, "04  >  EXIT")
	# Panel principal
	var panel := $CenterContainer/PanelContainer

	panel.custom_minimum_size = Vector2(520, 530)

	var panel_style := _make_style(
		Color("#07110D"),
		GREEN_BORDER
	)

	panel_style.set_border_width_all(1)

	panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

func _style_button(button: Button, button_text: String) -> void:
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 48)

	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GREEN_DARK)
	button.add_theme_color_override("font_hover_color", GREEN)
	button.add_theme_color_override("font_pressed_color", GREEN)
	button.add_theme_color_override("font_disabled_color", Color("#304638"))

	# Estado normal
	button.add_theme_stylebox_override(
		"normal",
		_make_style(BUTTON_BG, GREEN_BORDER)
	)

	# Estado hover
	button.add_theme_stylebox_override(
		"hover",
		_make_style(BUTTON_HOVER, GREEN)
	)

	# Estado presionado
	button.add_theme_stylebox_override(
		"pressed",
		_make_style(Color("#193A24"), GREEN)
	)

	# Estado deshabilitado
	button.add_theme_stylebox_override(
		"disabled",
		_make_style(BUTTON_BG, GREEN_BORDER)
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg
	style.border_color = border

	style.set_border_width_all(1)
	style.set_corner_radius_all(2)

	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	return style


# Botones
func _on_new_game() -> void:
	print("INITIALIZING NEW OPERATION...")


func _on_continue() -> void:
	print("LOADING SAVED OPERATION...")


func _on_options() -> void:
	print("OPENING SYSTEM CONFIGURATION...")


func _on_exit() -> void:
	get_tree().quit()
