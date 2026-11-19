extends Control

const SETTINGS_PATH := "user://makeshift_menu.cfg"
const SAVE_PATH := "user://makeshift_save.cfg"
const START_SCENE := "res://tests/test_level_01.tscn"

const COPY := {
	"en": {
		"title": "MAKE/SHIFT CHRISTMAS",
		"subtitle": "Improvise Christmas. Then destroy it.",
		"play": "PLAY",
		"continue": "CONTINUE",
		"settings": "SETTINGS",
		"exit": "EXIT",
		"settings_title": "SETTINGS",
		"language": "Language",
		"music": "Music",
		"sfx": "SFX",
		"fullscreen": "Fullscreen",
		"back": "BACK",
		"hint": "Use arrow keys / W S to navigate, Enter to confirm.",
		"no_save": "No saved progress found.",
		"has_save": "Saved progress available.",
		"loading": "Loading...",
		"missing_scene": "Start scene not found: %s"
	},
	"es": {
		"title": "MAKE/SHIFT CHRISTMAS",
		"subtitle": "Improvisa la Navidad. Luego destrúyela.",
		"play": "JUGAR",
		"continue": "CONTINUAR",
		"settings": "AJUSTES",
		"exit": "SALIR",
		"settings_title": "AJUSTES",
		"language": "Idioma",
		"music": "Música",
		"sfx": "Efectos",
		"fullscreen": "Pantalla completa",
		"back": "VOLVER",
		"hint": "Usa flechas / W S para navegar y Enter para confirmar.",
		"no_save": "No hay progreso guardado.",
		"has_save": "Hay una partida guardada disponible.",
		"loading": "Cargando...",
		"missing_scene": "No se encontró la escena inicial: %s"
	}
}

@onready var title_label: Label = $Content/RootHBox/MenuColumn/Title
@onready var subtitle_label: Label = $Content/RootHBox/MenuColumn/Subtitle
@onready var play_button: Button = $Content/RootHBox/MenuColumn/Buttons/PlayButton
@onready var continue_button: Button = $Content/RootHBox/MenuColumn/Buttons/ContinueButton
@onready var settings_button: Button = $Content/RootHBox/MenuColumn/Buttons/SettingsButton
@onready var exit_button: Button = $Content/RootHBox/MenuColumn/Buttons/ExitButton
@onready var hint_label: Label = $Content/RootHBox/MenuColumn/Hint
@onready var status_label: Label = $Content/RootHBox/MenuColumn/Status
@onready var settings_panel: Control = $SettingsLayer/SettingsPanel
@onready var settings_card: PanelContainer = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard
@onready var settings_title: Label = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/SettingsTitle
@onready var language_label: Label = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/LanguageRow/LanguageLabel
@onready var language_option: OptionButton = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/LanguageRow/LanguageOption
@onready var music_label: Label = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/MusicRow/MusicLabel
@onready var music_slider: HSlider = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/MusicRow/MusicSlider
@onready var sfx_label: Label = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/SfxRow/SfxLabel
@onready var sfx_slider: HSlider = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/SfxRow/SfxSlider
@onready var fullscreen_check: CheckBox = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/FullscreenCheck
@onready var back_button: Button = $SettingsLayer/SettingsPanel/SettingsCenter/SettingsCard/SettingsMargin/SettingsVBox/SettingsButtons/BackButton

var locale: String = "en"
var save_scene_path: String = ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_styles()
	_build_language_option()
	_load_settings()
	_refresh_continue_state()
	_apply_texts()
	play_button.pressed.connect(_on_play_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_open_settings)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_close_settings)
	language_option.item_selected.connect(_on_language_selected)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	play_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_panel.visible:
		get_viewport().set_input_as_handled()
		_close_settings()

func _setup_styles() -> void:
	var title_color := Color(0.95, 0.97, 1.0)
	var subtitle_color := Color(0.72, 0.81, 0.93)
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", subtitle_color)
	hint_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.88, 0.85))
	status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.88))
	for button in [play_button, continue_button, settings_button, exit_button, back_button]:
		_style_button(button)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.08, 0.13, 0.88)
	card_style.border_color = Color(0.76, 0.84, 0.96, 0.42)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	settings_card.add_theme_stylebox_override("panel", card_style)
	for label in [settings_title, language_label, music_label, sfx_label]:
		label.add_theme_color_override("font_color", title_color)
	settings_title.add_theme_font_size_override("font_size", 28)
	fullscreen_check.add_theme_color_override("font_color", title_color)
	for slider in [music_slider, sfx_slider]:
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _style_button(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.98, 0.98, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.68, 0.9))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.04, 0.08, 0.12)
	normal.border_color = Color(0.80, 0.88, 1.0, 0.16)
	normal.set_border_width_all(0)
	normal.content_margin_left = 12
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.14, 0.24, 0.62)
	hover.border_color = Color(0.93, 0.97, 1.0, 0.55)
	hover.set_border_width_all(1)
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.13, 0.19, 0.29, 0.88)
	var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.02, 0.04, 0.08, 0.05)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)

func _build_language_option() -> void:
	language_option.clear()
	language_option.add_item("English", 0)
	language_option.add_item("Español", 1)

func _apply_texts() -> void:
	var t: Dictionary = COPY.get(locale, COPY["en"])
	title_label.text = t["title"]
	subtitle_label.text = t["subtitle"]
	play_button.text = t["play"]
	continue_button.text = t["continue"]
	settings_button.text = t["settings"]
	exit_button.text = t["exit"]
	settings_title.text = t["settings_title"]
	language_label.text = t["language"]
	music_label.text = t["music"]
	sfx_label.text = t["sfx"]
	fullscreen_check.text = t["fullscreen"]
	back_button.text = t["back"]
	hint_label.text = t["hint"]
	status_label.text = t["has_save"] if continue_button.disabled == false else t["no_save"]

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		locale = String(cfg.get_value("menu", "language", "en"))
		music_slider.value = float(cfg.get_value("menu", "music", 0.80))
		sfx_slider.value = float(cfg.get_value("menu", "sfx", 0.90))
		fullscreen_check.button_pressed = bool(cfg.get_value("menu", "fullscreen", false))
	if locale not in ["en", "es"]:
		locale = "en"
	language_option.select(0 if locale == "en" else 1)
	_apply_audio_bus("Music", music_slider.value)
	_apply_audio_bus("SFX", sfx_slider.value)
	_apply_window_mode(fullscreen_check.button_pressed)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("menu", "language", locale)
	cfg.set_value("menu", "music", music_slider.value)
	cfg.set_value("menu", "sfx", sfx_slider.value)
	cfg.set_value("menu", "fullscreen", fullscreen_check.button_pressed)
	cfg.save(SETTINGS_PATH)

func _refresh_continue_state() -> void:
	save_scene_path = ""
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		save_scene_path = String(cfg.get_value("save", "scene_path", ""))
	continue_button.disabled = save_scene_path.is_empty() or not ResourceLoader.exists(save_scene_path)

func _open_settings() -> void:
	settings_panel.show()
	language_option.grab_focus()

func _close_settings() -> void:
	settings_panel.hide()
	settings_button.grab_focus()

func _on_play_pressed() -> void:
	status_label.text = COPY[locale]["loading"]
	if ResourceLoader.exists(START_SCENE):
		get_tree().change_scene_to_file(START_SCENE)
	else:
		status_label.text = COPY[locale]["missing_scene"] % START_SCENE

func _on_continue_pressed() -> void:
	if continue_button.disabled:
		return
	status_label.text = COPY[locale]["loading"]
	get_tree().change_scene_to_file(save_scene_path)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_language_selected(index: int) -> void:
	locale = "en" if index == 0 else "es"
	_apply_texts()
	_save_settings()

func _on_music_changed(value: float) -> void:
	_apply_audio_bus("Music", value)
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	_apply_audio_bus("SFX", value)
	_save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_window_mode(enabled)
	_save_settings()

func _apply_audio_bus(bus_name: String, normalized_value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	var db: float = linear_to_db(clamp(normalized_value, 0.001, 1.0))
	AudioServer.set_bus_volume_db(bus, db)

func _apply_window_mode(fullscreen_enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)
