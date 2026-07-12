class_name RadioItem
extends ItemBase

var hold_offset := Vector3(0, -0.0, -1.2)
var hold_rotation := Vector3(0, 0, 0)

@export var sync_position: Vector3
@export var sync_rotation: Vector3

@export var songs: Array[AudioStream] = []
@export var fade_duration: float = 1.8
@export var volume_db: float = -15.0

@onready var audio_player = $AudioStreamPlayer3D

var is_on: bool = false
var current_song_index: int = -1
var fade_tween: Tween
var original_pitch: float = 1.0

@onready var sprite_mat = $Sprite3D

func is_swingable() -> bool:
	return true

func is_throwable() -> bool:
	return true

func is_pickable() -> bool:
	return true

func get_sync_properties() -> Array[String]:
	return ["sync_position", "sync_rotation"]

func _ready() -> void:
	super()
	original_pitch = audio_player.pitch_scale
	audio_player.volume_db = -80.0
	audio_player.finished.connect(_on_song_finished)

func _on_song_finished():
	if is_on and audio_player.stream:
		audio_player.play()

func use():
	if multiplayer.is_server():
		_radio_toggle()
	else:
		rpc_id(1, "_radio_toggle")

@rpc("any_peer", "reliable")
func _radio_toggle():
	if not multiplayer.is_server():
		return
	
	is_on = !is_on
	
	if is_on:
		current_song_index = randi_range(0, songs.size() - 1)
		audio_player.stream = songs[current_song_index]
		audio_player.play()
	
	rpc("_update_radio_state", is_on, current_song_index)

@rpc("call_local", "reliable")
func _update_radio_state(state: bool, song_index: int):
	is_on = state
	current_song_index = song_index
	
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()
	
	fade_tween = create_tween()
	
	if is_on:
		if song_index >= 0 and song_index < songs.size():
			audio_player.stream = songs[song_index]
		if not audio_player.playing:
			audio_player.play()
		fade_tween.tween_property(audio_player, "volume_db", volume_db, fade_duration).set_ease(Tween.EASE_OUT)
	else:
		fade_tween.tween_property(audio_player, "volume_db", -200.0, fade_duration).set_ease(Tween.EASE_IN)

func _process(delta: float):
	var cam = get_viewport().get_camera_3d()
	var sprite = get_node_or_null("Visuals/Sprite3D")
	if cam and sprite:
		var to_cam = cam.global_position - sprite.global_position
		var local_up = global_transform.basis.y.normalized()
		var projected_to_cam = to_cam - local_up * to_cam.dot(local_up)
		if projected_to_cam.length_squared() > 0.001:
			var forward = projected_to_cam.normalized()
			var right = local_up.cross(forward).normalized()
			sprite.global_basis = Basis(right, local_up, forward) * 0.5

	var anim_sprite = get_node_or_null("Visuals/AnimatedSprite3D")
	if cam and anim_sprite:
		var to_cam = cam.global_position - anim_sprite.global_position
		var local_up = global_transform.basis.y.normalized()
		var projected_to_cam = to_cam - local_up * to_cam.dot(local_up)
		if projected_to_cam.length_squared() > 0.001:
			var forward = projected_to_cam.normalized()
			var right = local_up.cross(forward).normalized()
			anim_sprite.global_basis = Basis(right, local_up, forward) * 0.5

func _physics_process(delta: float) -> void:
	if held_by_id != 0:
		var player = _get_player(held_by_id)
		if player:
			var grip = player.get_node_or_null("Head/WeaponGrip")
			if grip:
				global_position = grip.global_transform * hold_offset
				global_transform.basis = grip.global_transform.basis * Basis.from_euler(hold_rotation)
			else:
				var head = player.get_node_or_null("Head")
				if head:
					global_position = head.global_transform * hold_offset
					global_transform.basis = head.global_transform.basis * Basis.from_euler(hold_rotation)
				else:
					global_position = player.global_transform * hold_offset

		if multiplayer.is_server():
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			sync_position = global_position
			sync_rotation = rotation
	else:
		if multiplayer.is_server():
			sync_position = global_position
			sync_rotation = rotation
		else:
			global_position = global_position.lerp(sync_position, 15.0 * delta)
			rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)
			rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
			rotation.z = lerp_angle(rotation.z, sync_rotation.z, 15.0 * delta)

@rpc("any_peer", "call_local", "reliable")
func apply_item_impulse(impulse:Vector3) -> void:
	super(impulse)
	_hit_pitch_effect()

func _hit_pitch_effect():
	var hit_pitch = randf_range(0.3, 1.8)
	audio_player.pitch_scale = hit_pitch
	var tween = create_tween()
	tween.tween_property(audio_player, "pitch_scale", original_pitch, 0.9).set_ease(Tween.EASE_OUT)

@rpc("any_peer", "reliable")
func add_song_from_path(path: String):
	if not multiplayer.is_server():
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Ошибка: не могу открыть файл ", path)
		return
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	var audio_stream = AudioStreamMP3.new()
	audio_stream.data = data
	
	songs.append(audio_stream)
	
	# Рассылаем всем клиентам аудиоданные
	for p in get_tree().get_nodes_in_group("player"):
		p.rpc_id(p.name.to_int(), "_receive_song_data", data)

@rpc("any_peer", "call_local", "reliable")
func _receive_song_data(data: PackedByteArray):
	var audio_stream = AudioStreamMP3.new()
	audio_stream.data = data
	songs.append(audio_stream)
	print("Песня добавлена, всего: ", songs.size())
