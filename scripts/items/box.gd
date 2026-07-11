class_name BoxItem
extends ItemBase

var hold_offset := Vector3(0, 0.0, -2.5)
var setka = false
@export var sync_position: Vector3

func is_pickable() -> bool:
	return true

func is_throwable() -> bool:
	return false

func is_swingable() -> bool:
	return true

func get_sync_properties() -> Array[String]:
	return ["sync_position"]

func is_authority() -> int:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

func _ready() -> void:
	super()
	add_to_group("box")
	freeze = true  # Не двигается

func _update_state():
	if held_by_id != 0:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 3
		collision_mask = 3

func _physics_process(delta: float) -> void:
	if is_authority():
		if held_by_id != 0:
			var player = _get_player(held_by_id)
			if player:
				var head = player.get_node_or_null("Head")
				if head:
					var target_pos = head.global_transform * hold_offset
					if setka:
						var grid = 1.0
						target_pos.x = round(target_pos.x / grid) * grid
						target_pos.y = round(target_pos.y / grid) * grid + 0.5
						target_pos.z = round(target_pos.z / grid) * grid
					global_position = target_pos
		sync_position = global_position
	else:
		global_position = global_position.lerp(sync_position, 25.0 * delta)

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.name == str(id):
			return p
	return null

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int) -> void:
	if not is_authority(): return
	if held_by_id != 0: return
	var player = _get_player(player_id)
	if player and global_position.distance_to(player.global_position) < 4.0:
		held_by_id = player_id
		rpc("update_held_state", player_id)

@rpc("any_peer", "call_local", "reliable")
func request_drop(player_vel: Vector3 = Vector3.ZERO) -> void:
	if not is_authority(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		held_by_id = 0
		rpc("update_held_state", 0)
		linear_velocity = player_vel

@rpc("authority", "call_local", "reliable")
func update_held_state(new_id: int):
	held_by_id = new_id

@rpc("any_peer", "call_local", "reliable")
func setkas():
	setka = !setka

@rpc("any_peer", "call_local", "reliable")
func destroy():
	if multiplayer.is_server():
		rpc("_do_destroy")

@rpc("call_local", "reliable")
func _do_destroy():
	collision_layer = 0
	collision_mask = 0
	freeze = true
	held_by_id = 0
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_callback(_remove)

func _remove():
	if multiplayer.is_server():
		queue_free()
