# balloon.gd
class_name BalloonItem
extends ItemBase

var hold_offset := Vector3(0, -0.3, -1.2)

@export var sync_position: Vector3

var is_popped: bool = false

func is_swingable() -> bool:
	return true

func is_throwable() -> bool:
	return true

func is_pickable() -> bool:
	return not is_popped

func get_sync_properties() -> Array[String]:
	return ["sync_position"]

func _ready() -> void:
	super()
	var hue = randf()  # 0.0 - 1.0
	var color = Color.from_hsv(hue, 0.8, 1.3, 1.0)  # Яркий, насыщенный
	var mat = $MeshInstance3D.get_active_material(0).duplicate()
	if mat is StandardMaterial3D:
		mat.albedo_color = color
	$MeshInstance3D.material_override = mat

func _physics_process(delta: float) -> void:
	if self.is_multiplayer_authority():
		if held_by_id != 0 and held_by_player:
			var head = held_by_player.get_node_or_null("Head")
			if head:
				global_position = head.global_transform * hold_offset
			else:
				global_position = held_by_player.global_transform * hold_offset
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
		sync_position = global_position
	else:
		global_position = global_position.lerp(sync_position, 25.0 * delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	transfer_authority_on_touch(state)


func _pop():
	rpc("_do_pop")

@rpc("any_peer", "call_local", "reliable")
func _do_pop():
	var mat = $MeshInstance3D.get_active_material(0).duplicate()
	mat.albedo_texture = preload("res://textures/deadvozduhniiball.png")
	$MeshInstance3D.material_override = mat
	is_popped = true
	held_by_id = 0
	if held_by_player:
		held_by_player = null
	freeze = true
	collision_layer = 0
	collision_mask = 0
	if multiplayer.is_server():
		await get_tree().create_timer(0.2).timeout
		queue_free()



@rpc("any_peer", "call_local", "reliable")
func request_dribble() -> void:
	pass  # Шарик не дриблится

@rpc("authority", "call_local", "reliable")
func update_held_state(new_id: int):
	super(new_id)

func _on_check_authority_timeout() -> void:
	if held_by_id != 0: return
	var closest_player = null
	var closest_distance: float = 0.0
	if self.is_multiplayer_authority(): return
	for p in get_tree().get_nodes_in_group("player"):
		var distance: float = global_position.distance_to(p.global_position)
		if distance < 5.0:
			if closest_player == null:
				closest_player = p
				closest_distance = distance
			elif distance < closest_distance:
				closest_player = p
				closest_distance = distance
	if closest_player == null: return
	var player_id: int = int(closest_player.name)
	if player_id != get_multiplayer_authority():
		rpc("transfer_authority", player_id, linear_velocity)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if is_popped or held_by_id != 0 or body == self:
		return
	
	if body.is_in_group("player"):
		var player_id = int(body.name)
		if player_id != get_multiplayer_authority():
			rpc("transfer_authority", player_id, body.linear_velocity + linear_velocity)

	var my_speed = linear_velocity.length()
	var other_speed = 0.0
	var vertical_factor = 1.0
	
	if body is RigidBody3D:
		other_speed = body.linear_velocity.length()
		if body.linear_velocity.y < -2.0:
			vertical_factor = 2.0
	if body.is_in_group("player"):
		if body.linear_velocity.y < -0.1:
			vertical_factor = 30.0
		if body.linear_velocity.y > 1.0:
			vertical_factor = 0.5
		other_speed /= 2
	
	var impact_speed = (my_speed + other_speed) * vertical_factor 
	if impact_speed > 8.0:
		_pop()
