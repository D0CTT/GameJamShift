extends AudioStreamPlayer
## Local to the fight: cannot survive a retry or scene change.
const SANTA_TRACK = preload("res://assets/audio/music/santa_boss.ogg")
const RUDOLPH_TRACK = preload("res://assets/audio/music/rudolph_boss.ogg")
const SETTINGS_PATH := "user://makeshift_menu.cfg"
const MIX_DB := -7.0
var target_db: float = MIX_DB
var volume_tween: Tween
var tempo_tween: Tween
var phase: int = 0

func _ready() -> void:
	var cfg := ConfigFile.new()
	var level: float = 0.8
	if cfg.load(SETTINGS_PATH) == OK:
		level = clampf(float(cfg.get_value("menu", "music", 0.8)), 0.0, 1.0)
	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		bus = &"Music"
		# Match main menu settings, including when testing with F6.
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(level, 0.001)))
		target_db = MIX_DB if level > 0.0 else -80.0
	else:
		bus = &"Master"
		target_db = MIX_DB + linear_to_db(maxf(level, 0.0001)) if level > 0.0 else -80.0
	volume_db = -80.0

func play_phase(next_phase: int) -> void:
	if next_phase == phase and playing:
		return
	_cancel_tweens()
	stop()
	phase = next_phase
	var source: AudioStreamOggVorbis = SANTA_TRACK if phase == 1 else RUDOLPH_TRACK
	var track: AudioStreamOggVorbis = source.duplicate() as AudioStreamOggVorbis
	track.loop = true
	track.loop_offset = 0.0
	stream = track
	pitch_scale = 1.0
	volume_db = -80.0
	play()
	volume_tween = create_tween()
	volume_tween.tween_property(self, "volume_db", target_db, 0.35)

func intensify() -> void:
	if phase == 0 or not playing:
		return
	if is_instance_valid(tempo_tween):
		tempo_tween.kill()
	tempo_tween = create_tween()
	tempo_tween.tween_property(self, "pitch_scale", 1.06 if phase == 1 else 1.08, 0.9).set_trans(Tween.TRANS_SINE)

func fade_out(seconds: float = 0.25) -> void:
	_cancel_tweens()
	phase = 0
	if not playing:
		return
	volume_tween = create_tween()
	volume_tween.tween_property(self, "volume_db", -80.0, seconds)
	volume_tween.tween_callback(stop)

func _cancel_tweens() -> void:
	if is_instance_valid(volume_tween):
		volume_tween.kill()
	if is_instance_valid(tempo_tween):
		tempo_tween.kill()
