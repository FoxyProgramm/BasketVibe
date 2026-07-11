class_name BallItem
extends ItemBase

var hold_offset := Vector3(0, -0.3, -1.2)

@export var sync_position: Vector3
@onready var debug = get_tree().get_first_node_in_group("debug_menu")

var is_dribbling: bool = false
@onready var anim_sprite = $AnimatedSprite3D

func is_swingable() -> bool:
	return true

func is_throwable() -> bool:
	return true

func is_pickable() -> bool:
	return true

func get_sync_properties() -> Array[String]:
	return ["sync_position"]

func _ready() -> void:
	super()

var last_position: Vector3

func is_authority() -> int:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

func _physics_process(delta: float) -> void:
	#debug.set_text(0, str(get_multiplayer_authority()) + " | " + str(self.freeze) + " | " + str(self.sleeping))
	if is_authority():
		if held_by_id != 0:
			var player = _get_player(held_by_id)
			if player:
				var head = player.get_node_or_null("Head")
				if head:
					global_position = head.global_transform * hold_offset
				else:
					global_position = player.global_transform * hold_offset

				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO
				rotation = Vector3.ZERO

		if self.global_position.y < -20:
			self.global_position = Vector3(0,10,0)
			self.linear_velocity = Vector3.ZERO
		sync_position = global_position
	else:
		global_position = global_position.lerp(sync_position, 25.0 * delta)

	var speed = 0.0
	if is_authority():
		speed = linear_velocity.length()
	else:
		if delta > 0:
			speed = (global_position - last_position).length() / delta

	last_position = global_position

	if anim_sprite:
		if held_by_id == 0 and speed > 0.5:
			if not anim_sprite.is_playing():
				anim_sprite.play("default")
			anim_sprite.speed_scale = speed * 0.4
		else:
			anim_sprite.stop()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var contact_count:int = state.get_contact_count()
	for i in range(contact_count):
		var collider = state.get_contact_collider_object(i)
		if collider is Player:
			var new_id : int = int(collider.name)
			if new_id == get_multiplayer_authority():
				return
			rpc("transfer_authority", new_id, self.linear_velocity)

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int) -> void:
	if not is_authority(): return
	if held_by_id != 0: return 

	var player = _get_player(player_id)
	if player:
		if global_position.distance_to(player.global_position) < 4.0:
			held_by_id = player_id
			rpc("update_held_state", player_id)
			rpc("transfer_authority", player_id)

@rpc("any_peer", "call_local", "reliable")
func request_drop(player_vel: Vector3 = Vector3.ZERO) -> void:
	if not is_authority(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		held_by_id = 0
		rpc("update_held_state", 0)
		linear_velocity = player_vel

@rpc("any_peer", "call_local", "reliable")
func request_throw(direction: Vector3, force: float, player_vel: Vector3 = Vector3.ZERO) -> void:
	if not is_authority(): return

	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		held_by_id = 0
		rpc("update_held_state", 0)
		linear_velocity = direction.normalized() * force + player_vel

@rpc("any_peer", "call_local", "reliable")
func request_dribble() -> void:
	if not is_authority(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id and not is_dribbling:
		var drop_y = -1.1
		var player = _get_player(sender_id)
		if player:
			var space_state = get_world_3d().direct_space_state
			var from = global_position
			var to = from + Vector3.DOWN * 4.0
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.exclude = [self.get_rid(), player.get_rid()]
			var result = space_state.intersect_ray(query)
			if result:
				drop_y = result.position.y - global_position.y + 0.3
				drop_y = min(-0.1, drop_y)

		rpc("play_dribble_anim", drop_y)

@rpc("call_local", "reliable")
func play_dribble_anim(target_y: float):
	if is_dribbling: return
	is_dribbling = true
	var tween = create_tween()
	tween.tween_property($AnimatedSprite3D, "position:y", target_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property($AnimatedSprite3D, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_dribbling = false)

@rpc("authority", "call_local", "reliable")
func update_held_state(new_id: int):
	held_by_id = new_id
	if new_id == 0:
		is_dribbling = false
		$AnimatedSprite3D.position.y = 0.0

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.name == str(id):
			return p
	return null

func _on_check_authority_timeout() -> void:
	if held_by_id != 0: return
	var closest_player = null
	var closest_distance: float = 0.0
	if not is_authority(): return
	for p in get_tree().get_nodes_in_group("player"):
		var distance: float = self.global_position.distance_to(p.global_position)
		if distance < 5.0:
			if closest_player == null:
				closest_player = p
				closest_distance = distance
			else :
				if distance < closest_distance:
					closest_player = p
					closest_distance = distance
	if closest_player == null: return
	var player_id : int = int(closest_player.name)
	if player_id != get_multiplayer_authority():
		rpc("transfer_authority", player_id, self.linear_velocity)

@rpc("any_peer", "reliable")
func set_linear_velocity_net(vect:Vector3) -> void:
	self.linear_velocity = vect
