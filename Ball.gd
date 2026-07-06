extends RigidBody3D

var hold_offset := Vector3(0, -0.3, -1.2)

# Переменные для сетевой интерполяции мяча
@export var sync_position: Vector3
#@export var sync_rotation: Vector3
@onready var debug = get_tree().get_first_node_in_group("debug_menu")

var is_dribbling: bool = false
@onready var anim_sprite = $AnimatedSprite3D
# Синхронизируемые переменные (через RPC)
@export var held_by_id: int = 0:
	set(val):
		held_by_id = val
		_update_ball_state()

func _ready() -> void:
	var sync = MultiplayerSynchronizer.new()
	sync.root_path = NodePath("..")
	var config = SceneReplicationConfig.new()
	# Синхронизируем кастомные переменные вместо прямых координат
	config.add_property(NodePath(".:sync_position"))
	#config.add_property(NodePath(".:sync_rotation"))
	sync.replication_config = config

	# Снова включаем экономию трафика! (20 пакетов в секунду)
	sync.replication_interval = 0.05
	sync.delta_interval = 0.05
	add_child(sync)

	sync_position = global_position
	#sync_rotation = rotation

	if not multiplayer.is_server():
		# На клиенте мы не симулируем физику мяча, он полностью контролируется сервером и интерполяцией
		freeze = true

func _update_ball_state():
	if held_by_id != 0:
		if not freeze:
			freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		#if not multiplayer.is_server():
		if not is_authority():
			# На клиенте мяч всегда заморожен (следует за интерполяцией от сервера)
			freeze = true
		else:
			if freeze:
				freeze = false
		collision_layer = 3
		collision_mask = 3

var last_position: Vector3

#func _process(delta: float) -> void:
#@onready var label_1: Label = $UI/Debug/Display/Label1

func is_authority() -> int:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

func _physics_process(delta: float) -> void:
	debug.set_text(0, str(get_multiplayer_authority()) + " | " + str(self.freeze) + " | " + str(self.sleeping))
	if is_authority():
		#$UI/Debug/Display/Label1.text = str(get_multiplayer_authority())  + ".." + str(delta)
		# --- ЛОГИКА СЕРВЕРА ---
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
				rotation = Vector3.ZERO # Фиксируем вращение при удержании, чтобы локальный Y смотрел ровно вниз

		# Сервер записывает реальную позицию мяча для отправки в сеть
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
			rpc("transfer_authority", new_id)

@rpc("any_peer", "call_local", "reliable")
func transfer_authority(new_id:int) -> void:
	if new_id == multiplayer.get_unique_id():
		self.freeze = false
		self.sleeping = false
	else :
		self.freeze = true
		self.sleeping = true
	self.set_multiplayer_authority(new_id)

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
				# Вычисляем нужную позицию: уровень пола минус текущая позиция мяча + радиус мяча (0.3)
				drop_y = result.position.y - global_position.y + 0.3
				# На всякий случай ограничиваем, чтобы мяч не "отскакивал" вверх сквозь руки
				drop_y = min(-0.1, drop_y)

		rpc("play_dribble_anim", drop_y)

@rpc("call_local", "reliable")
func play_dribble_anim(target_y: float):
	if is_dribbling: return
	is_dribbling = true
	var tween = create_tween()
	#if has_node("AnimatedSprite3D"):
	tween.tween_property($AnimatedSprite3D, "position:y", target_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property($AnimatedSprite3D, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_dribbling = false)

@rpc("authority", "call_local", "reliable")
func update_held_state(new_id: int):
	held_by_id = new_id
	if new_id == 0:
		is_dribbling = false
		if has_node("MeshInstance3D"):
			$MeshInstance3D.position.y = 0.0
		if has_node("AnimatedSprite3D"):
			$AnimatedSprite3D.position.y = 0.0

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.name == str(id):
			return p
	return null

func _on_check_authority_timeout() -> void:
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
		rpc("transfer_authority", player_id)
			
