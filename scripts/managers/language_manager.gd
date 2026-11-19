extends CanvasLayer
## Autoload: LanguageManager. All gameplay labels use English source strings.
signal language_changed(locale: String)

const SETTINGS_PATH := "user://makeshift_language.cfg"
const TEXT_ES := {
	"Language": "Idioma",
	"F2 - Language": "F2 - Idioma",
	"Back to game": "Volver al juego",
	"Choose your language": "Elige tu idioma",
	"You need the Christmas lights to cross the forest.": "Necesitas las luces navideñas para cruzar el bosque.",
	"Pick up the lights before continuing.": "Recupera las luces antes de continuar.",
	"Level 1 complete - Cabin reached (prototype)": "Nivel 1 completado - Llegada a la cabaña (prototipo)",
}
var current_locale: String = "en"
var menu: Control
var english_button: Button
var spanish_button: Button
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var previously_paused := false
var menu_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	var spanish := Translation.new()
	spanish.locale = "es"
	for source in TEXT_ES:
		spanish.add_message(StringName(source), StringName(TEXT_ES[source]))
	TranslationServer.add_translation(spanish)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		current_locale = String(config.get_value("language", "locale", "en"))
	if current_locale not in ["en", "es"]:
		current_locale = "en"
	TranslationServer.set_locale(current_locale)
	_build_menu()
	_update_buttons()

func set_language(locale: String) -> void:
	if locale not in ["en", "es"]:
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	_update_buttons()
	var config := ConfigFile.new()
	config.set_value("language", "locale", locale)
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Could not save language setting: " + error_string(result))
	language_changed.emit(locale)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			get_viewport().set_input_as_handled()
			if menu_open:
				_close_menu()
			else:
				_open_menu()
		elif menu_open and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_menu()

func _open_menu() -> void:
	if menu_open:
		return
	previously_paused = get_tree().paused
	previous_mouse_mode = Input.mouse_mode
	menu_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show()
	if current_locale == "en":
		english_button.grab_focus()
	else:
		spanish_button.grab_focus()

func _close_menu() -> void:
	if not menu_open:
		return
	menu.hide()
	menu_open = false
	get_tree().paused = previously_paused
	Input.mouse_mode = previous_mouse_mode

func _update_buttons() -> void:
	if not is_instance_valid(english_button) or not is_instance_valid(spanish_button):
		return
	english_button.set_pressed_no_signal(current_locale == "en")
	spanish_button.set_pressed_no_signal(current_locale == "es")

func _build_menu() -> void:
	var shortcut := Label.new()
	add_child(shortcut)
	shortcut.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	shortcut.offset_left = -200
	shortcut.offset_top = -42
	shortcut.offset_right = -18
	shortcut.offset_bottom = -12
	shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shortcut.add_theme_color_override("font_shadow_color", Color.BLACK)
	shortcut.add_theme_constant_override("shadow_offset_x", 2)
	shortcut.add_theme_constant_override("shadow_offset_y", 2)
	shortcut.text = "F2 - Language"

	menu = Control.new()
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.055, 0.075, 0.89)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.16)
	style.border_color = Color(0.42, 0.58, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.custom_minimum_size.x = 260
	column.add_theme_constant_override("separation", 12)
	var title := Label.new()
	column.add_child(title)
	title.text = "Language"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	var subtitle := Label.new()
	column.add_child(subtitle)
	subtitle.text = "Choose your language"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	english_button = Button.new()
	column.add_child(english_button)
	english_button.text = "English"
	english_button.custom_minimum_size.y = 42
	english_button.toggle_mode = true
	english_button.button_group = group
	english_button.pressed.connect(set_language.bind("en"))
	spanish_button = Button.new()
	column.add_child(spanish_button)
	spanish_button.text = "Español"
	spanish_button.custom_minimum_size.y = 42
	spanish_button.toggle_mode = true
	spanish_button.button_group = group
	spanish_button.pressed.connect(set_language.bind("es"))
	var back := Button.new()
	column.add_child(back)
	back.text = "Back to game"
	back.custom_minimum_size.y = 42
	back.pressed.connect(_close_menu)
	menu.hide()
