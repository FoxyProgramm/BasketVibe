extends Area3D

@export var target_door: Node3D
@export var variation: int = 0:
	set(val):
		variation = val
		_update_sprite()
@export var location_environment: Environment
	
@onready var sprite = $AnimatedSprite3D

var player_nearby: Node3D = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_sprite()

func _update_sprite():
	if sprite and sprite.sprite_frames:
		var frame_count = sprite.sprite_frames.get_frame_count("default")
		if frame_count > 0:
			sprite.frame = variation % frame_count

func _on_body_entered(body: Node3D):
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_nearby = body

func _on_body_exited(body: Node3D):
	if body == player_nearby:
		player_nearby = null

func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("E"):
		_teleport()

func _teleport():
	var player_path = player_nearby.get_path()
	if multiplayer.is_server():
		_do_teleport(player_path)
	else:
		rpc_id(1, "_do_teleport", player_path)


@rpc("any_peer", "reliable")
func _do_teleport(player_path: NodePath):
	if not multiplayer.is_server():
		return
	
	var player = get_node_or_null(player_path)
	if player and target_door:
		var new_pos = target_door.global_position + Vector3(randf_range(-0.5, 0.5), -1.2, randf_range(-0.5, 0.5))
		
		# Сначала обновляем sync_position на сервере
		player.sync_position = new_pos
		player.global_position = new_pos
		
		# Отправляем environment
		var env_path = location_environment.resource_path if location_environment else ""
		# Отправляем клиенту команду телепортироваться и обновить sync_position
		player.rpc_id(player.name.to_int(), "_client_teleport", new_pos, env_path)
		rpc("_play_teleport_effect", player.name)

@rpc("call_local", "reliable")
func _play_teleport_effect(player_name: String):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.name == player_name:
		var cam = player.get_node_or_null("Head/Camera3D")
		if cam:
			var tween = create_tween()
			tween.tween_property(cam, "fov", 150.0, 0.01)
			tween.tween_property(cam, "fov", 75.0, 0.2).set_ease(Tween.EASE_OUT)
