class_name BatItem
extends ItemBase

var hold_offset := Vector3(0.5, -0.1, -0.8)
var hold_rotation := Vector3(0, 0, 0)

@export var sync_position: Vector3
@export var sync_rotation: Vector3

@export var held_by_id: int = 0:
	set(val):
		held_by_id = val
		_update_bat_state()

@onready var visuals = $Visuals

@onready var sprite_mat = $Visuals/Sprite3D.material_override

func is_swingable() -> bool:
	return true

func is_throwable() -> bool:
	return true

func is_pickable() -> bool:
	return true

func _ready() -> void:
	var sync = MultiplayerSynchronizer.new()
	sync.root_path = NodePath("..")
	var config = SceneReplicationConfig.new()

	config.add_property(NodePath(".:sync_position"))
	config.add_property(NodePath(".:sync_rotation"))
	sync.replication_config = config

	sync.replication_interval = 0.05
	sync.delta_interval = 0.05
	add_child(sync)

	sync_position = global_position
	sync_rotation = rotation

	if not multiplayer.is_server():
		freeze = true

func _update_bat_state():
	if held_by_id != 0:
		if not freeze: freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		if not is_authority():
			freeze = true
		else:
			freeze = false
		collision_layer = 3
		collision_mask = 3


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

	# --- ЛОГИКА АНИМАЦИИ СПРАЙТА ---
	if anim_sprite and anim_sprite.sprite_frames:
		var anim_name = anim_sprite.animation
		var frame_count = anim_sprite.sprite_frames.get_frame_count(anim_name)

		if frame_count > 0:
			# Если у нас настроен анимированный спрайт, прячем статичный
			if sprite: sprite.hide()
			anim_sprite.show()

			var player = _get_player(held_by_id) if held_by_id != 0 else null

			if player:
				var is_swinging = player.get("is_swinging")

				if is_swinging:
					# Во время удара проигрываем анимацию
					if anim_sprite.frame == 0 and not anim_sprite.is_playing():
						anim_sprite.play(anim_name)
				else:
					# В спокойном состоянии или при заряде останавливаем анимацию на первом кадре
					anim_sprite.stop()
					anim_sprite.frame = 0
			else:
				# Если бита валяется на земле
				anim_sprite.stop()
				anim_sprite.frame = 0

	# --- ЛОГИКА ОБВОДКИ (Outline) ---
	var target_alpha = 0.0
	var target_thickness = 1.0

	if held_by_id == 0 and cam:
		var dist = global_position.distance_to(cam.global_position)
		target_alpha = clamp((dist - 3.0) / 12.0, 0.0, 1.0)
		target_thickness = clamp(1.0 + (dist / 10.0), 1.0, 15.0)

	if sprite_mat:
		var current_color = sprite_mat.get_shader_parameter("outline_color")
		current_color.a = lerp(current_color.a, target_alpha, 5.0 * delta)
		sprite_mat.set_shader_parameter("outline_color", current_color)
		sprite_mat.set_shader_parameter("outline_thickness", target_thickness)

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

		if is_authority():
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			sync_position = global_position
			sync_rotation = rotation
	else:
		if is_authority():
			sync_position = global_position
			sync_rotation = rotation
		else:
			global_position = global_position.lerp(sync_position, 15.0 * delta)
			
			rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)
			rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
			rotation.z = lerp_angle(rotation.z, sync_rotation.z, 15.0 * delta)

func is_authority() -> int:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int) -> void:
	if not is_authority(): return
	
	if held_by_id != 0: return

	var player = _get_player(player_id)
	if player:
		if global_position.distance_to(player.global_position) < 4.0:
			held_by_id = player_id
			self.rotation = Vector3.ZERO
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
func request_swing(charge: float) -> void:
	if not is_authority(): return
	print("Swing requested")
	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		var player:Player = _get_player(sender_id)
		if player:
			player.rpc("play_swing_anim")

		if player:
			var head:Node3D = player.get_node_or_null("Head")
			if not head: return
			var swing_dir:Vector3 = -head.global_transform.basis.z
			
			var items := player.get_items_in_sight()
			for item in items:
				if !item.is_swingable(): continue
				var to_item : Vector3 = head.global_position.direction_to(item.global_position)
				if swing_dir.dot(to_item) > 0.2:
					var speed:float = item.linear_velocity.length()
					var base_force:float = lerp(8.0, 16.0, charge)
					var hit_force:float = base_force + (clamp(speed, 1.0, 10.0) * 1.5)
					var impulse = (swing_dir + Vector3.UP * 0.2).normalized() * hit_force
					if multiplayer.get_unique_id() == item.get_multiplayer_authority():
						item.apply_item_impulse(impulse)
					else :
						item.rpc_id(item.get_multiplayer_authority(), "apply_item_impulse", impulse)

			# Проверяем попадание по ИГРОКАМ
			for p in get_tree().get_nodes_in_group("player"):
				if p.name == str(sender_id): continue # Не бьем сами себя!

				var dist = player.global_position.distance_to(p.global_position)
				if dist < 4.0:
					var to_p = (p.global_position - head.global_position).normalized()
					if swing_dir.dot(to_p) > 0.2:
						var knock_force = lerp(6.0, 20.0, charge)
						p.rpc_id(p.name.to_int(), "apply_knockback", swing_dir, knock_force)

						for ball in get_tree().get_nodes_in_group("ball"):
							if ball.held_by_id == p.name.to_int():
								ball.held_by_id = 0
								ball.rpc("update_held_state", 0)
						for bat in get_tree().get_nodes_in_group("bat"):
							if bat.held_by_id == p.name.to_int():
								bat.held_by_id = 0
								bat.rpc("update_held_state", 0)

@rpc("authority", "call_local", "reliable")
func update_held_state(new_id: int):
	held_by_id = new_id

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.name == str(id):
			return p
	return null
