class_name Player
extends RigidBody3D

const WALK_SPEED = 6.0
const SPRINT_SPEED = 14.0
const JUMP_VELOCITY = 5.0
const MIN_THROW_FORCE = 4.0
const MAX_THROW_FORCE = 12.0
const MAX_CHARGE_TIME = 1.0

var target_yaw: float = 0.0
var is_charging: bool = false
var charge_progress: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO

@export var default_environment: Environment #юазовый эрваермент, чтобы потом менять

# Переменные для сетевой интерполяции
@export var sync_position: Vector3
@export var sync_rotation_y: float
@export var sync_head_rotation_x: float
@export var sync_grip_rotation: Vector3

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var weapon_grip = $Head/WeaponGrip
#@onready var body_mesh = $BodyMesh

var base_grip_rot := Vector3.ZERO
var is_swinging := false
#@onready var head_mesh = $Head/HeadMesh
@onready var ground_cast = $GroundCast
@onready var charge_bar = $UI/ChargeBar

@onready var console = get_tree().get_first_node_in_group("debug_menu").get_node("Console")

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	var sync = MultiplayerSynchronizer.new()
	sync.set_multiplayer_authority(name.to_int())
	sync.root_path = NodePath("..")
	var config = SceneReplicationConfig.new()

	# Синхронизируем наши новые переменные, а не физические координаты напрямую
	config.add_property(NodePath(".:sync_position"))
	config.add_property(NodePath(".:sync_rotation_y"))
	config.add_property(NodePath(".:sync_head_rotation_x"))
	config.add_property(NodePath(".:sync_grip_rotation"))
	sync.replication_config = config

	# Снова включаем экономию трафика! (20 пакетов в секунду)
	sync.replication_interval = 0.05
	sync.delta_interval = 0.05
	add_child(sync)
	
	if charge_bar:
		charge_bar.hide()
		# Случайный цвет
		var fill_color = Color(randf()*0.5+0.5, randf()*0.5+0.5, randf()*0.5+0.5, 1.0)
		# Более тёмный для фона
		var bg_color = fill_color.darkened(0.8)
		
		var fill_style = charge_bar.get_theme_stylebox("fill").duplicate()
		fill_style.modulate_color = fill_color
		charge_bar.add_theme_stylebox_override("fill", fill_style)
		
		var bg_style = charge_bar.get_theme_stylebox("background").duplicate()
		bg_style.modulate_color = bg_color
		charge_bar.add_theme_stylebox_override("background", bg_style)

	if is_multiplayer_authority():
		target_yaw = rotation.y
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		#body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		#head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

		# Инициализируем переменные своими начальными координатами
		sync_position = global_position
		sync_rotation_y = rotation.y
		sync_head_rotation_x = head.rotation.x
		sync_grip_rotation = weapon_grip.rotation
		
		var main = get_tree().current_scene
		if main.has_method("get_local_skin"):
			apply_skin(main.get_local_skin())
		
		if default_environment:
			camera.environment = default_environment # задаем инваермент в камере, чтобы у каждого игрока он мог быть свой
	else:
		# Чужие игроки отключены от локальной физики
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		sync_position = global_position
		sync_rotation_y = rotation.y
		sync_head_rotation_x = head.rotation.x
		sync_grip_rotation = weapon_grip.rotation

func _input(event):
	if not is_multiplayer_authority(): return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		target_yaw -= event.relative.x * 0.003
		head.rotate_x(-event.relative.y * 0.003)
		head.rotation.x = clamp(head.rotation.x, -PI/2.5, PI/2.5)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if is_charging:
				is_charging = false
				charge_bar.hide()
		else:
			if !console.visible:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		var held = get_held_object()
		if held:
			held.rpc_id(held.get_multiplayer_authority(), "request_drop", linear_velocity)
			if is_charging:
				is_charging = false
				charge_bar.hide()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var held = get_held_object()
			if held and held.is_in_group("ball"):
				held.rpc_id(held.get_multiplayer_authority(), "request_dribble")

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if !console.visible:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

		var held = get_held_object()
		
		if held:
			if held.is_in_group("ball"):
				if event.pressed:
					is_charging = true
					charge_progress = 0.0
				else:
					if is_charging:
						is_charging = false
						var throw_dir = -head.global_transform.basis.z
						throw_dir += Vector3.UP * 0.2
						var force = lerp(MIN_THROW_FORCE, MAX_THROW_FORCE, charge_progress)
						held.rpc_id(held.get_multiplayer_authority(), "request_throw", throw_dir, force, linear_velocity)
						charge_bar.hide()
			elif held.is_in_group("bat"):
				if event.pressed:
					is_charging = true
					charge_progress = 0.0
				else:
					if is_charging:
						is_charging = false
						held.rpc_id(held.get_multiplayer_authority(), "request_swing", charge_progress)
						charge_bar.hide()
			elif held.is_in_group("radio"):
				if event.pressed:
					held.use()
		else:
			if event.pressed:
				var closest = get_closest_interactable()
				if closest:
					closest.rpc_id(closest.get_multiplayer_authority(), "request_pickup", multiplayer.get_unique_id())
					

func get_held_object():
	for b in get_tree().get_nodes_in_group("ball"):
		if b.held_by_id == multiplayer.get_unique_id(): return b
	for b in get_tree().get_nodes_in_group("bat"):
		if b.held_by_id == multiplayer.get_unique_id(): return b
	for b in get_tree().get_nodes_in_group("radio"):
		if b.held_by_id == multiplayer.get_unique_id(): return b
	return null

func get_closest_interactable() -> Node3D:
	var closest = null
	var min_dist = 4.0

	for b in get_tree().get_nodes_in_group("ball"):
		if b.held_by_id == 0:
			var d = global_position.distance_to(b.global_position)
			if d < min_dist:
				closest = b
				min_dist = d

	for b in get_tree().get_nodes_in_group("bat"):
		if b.held_by_id == 0:
			var d = global_position.distance_to(b.global_position)
			if d < min_dist:
				closest = b
				min_dist = d

	for b in get_tree().get_nodes_in_group("radio"):
		if b.held_by_id == 0:
			var d = global_position.distance_to(b.global_position)
			if d < min_dist:
				closest = b
				min_dist = d

	return closest

func _process(delta: float):
	if not is_multiplayer_authority(): return

	if is_charging:
		charge_progress = min(charge_progress + delta / MAX_CHARGE_TIME, 1.0)
		if not charge_bar.visible:
			charge_bar.show()
		charge_bar.value = charge_progress

		var held = get_held_object()
		if held and held.is_in_group("bat"):
			# Отводим "руку" вправо во время заряда
			var charge_rot = Vector3(deg_to_rad(-10), deg_to_rad(60), deg_to_rad(20))
			if not is_swinging:
				var q_current = Quaternion.from_euler(weapon_grip.rotation)
				var q_target = Quaternion.from_euler(charge_rot)
				weapon_grip.rotation = q_current.slerp(q_target, 10.0 * delta).get_euler()

	else:
		if not is_swinging:
			var q_current = Quaternion.from_euler(weapon_grip.rotation)
			var q_target = Quaternion.from_euler(base_grip_rot)
			weapon_grip.rotation = q_current.slerp(q_target, 15.0 * delta).get_euler()

func apply_skin(id:int) -> void:
	var character:Characters.Character = Characters.LIST.get(id)
	if character != null:
		$Head/HeadSprite.texture = character.head_texture
		$BodySprite.texture = character.body_texture

@rpc("call_local", "reliable")
func play_swing_anim():
	if is_swinging: return
	is_swinging = true
	var tween = create_tween()
	var strike_rot = Vector3(deg_to_rad(15), deg_to_rad(-20), deg_to_rad(-10))
	tween.tween_property(weapon_grip, "rotation", strike_rot, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_grip, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): is_swinging = false)

@rpc("any_peer", "call_local", "reliable")
func apply_knockback(direction: Vector3, force: float):
	if is_multiplayer_authority():
		knockback_velocity = direction.normalized() * force 
		knockback_velocity.y = force * 0.25
		_play_hit_effect(direction, force)
@warning_ignore("unused_parameter")
func _play_hit_effect(dir: Vector3, strength: float):
	var side = 1.0 if randf() > 0.5 else -1.0  # Случайно влево или вправо
	# Трясём камеру
	var tween = create_tween()
	tween.tween_property(camera, "rotation:z", dir.x * 0.3 * side, 0.05)
	tween.tween_property(camera, "rotation:z", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "rotation:x", -abs(dir.y) * 0.2 * side, 0.05)
	tween.tween_property(camera, "rotation:x", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	

func _physics_process(delta):
	if is_multiplayer_authority():
		# Хозяин игрока записывает свои реальные координаты в синхронизируемые переменные
		sync_position = global_position
		sync_rotation_y = target_yaw
		sync_head_rotation_x = head.rotation.x
		sync_grip_rotation = weapon_grip.rotation
	else:
		# ИНТЕРПОЛЯЦИЯ для чужих игроков
		global_position = global_position.lerp(sync_position, 15.0 * delta)
		rotation.y = lerp_angle(rotation.y, sync_rotation_y, 15.0 * delta)
		head.rotation.x = lerp_angle(head.rotation.x, sync_head_rotation_x, 15.0 * delta)

		if not is_swinging:
			var q_current = Quaternion.from_euler(weapon_grip.rotation)
			var q_target = Quaternion.from_euler(sync_grip_rotation)
			weapon_grip.rotation = q_current.slerp(q_target, 15.0 * delta).get_euler()

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not is_multiplayer_authority(): return
	var t = state.transform
	t.basis = Basis.from_euler(Vector3(0, target_yaw, 0))
	state.transform = t
	
	if console.visible:
		state.linear_velocity.x = 0
		state.linear_velocity.z = 0
		return 

	var is_on_floor = ground_cast.is_colliding()

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor:
		state.linear_velocity.y = JUMP_VELOCITY

	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction = (t.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_y = state.linear_velocity.y

	var current_speed = SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED

	var target_x = 0.0
	var target_z = 0.0

	if direction:
		target_x = direction.x * current_speed
		target_z = direction.z * current_speed

	state.linear_velocity.x = target_x + knockback_velocity.x
	state.linear_velocity.z = target_z + knockback_velocity.z

	if knockback_velocity.y > 0:
		current_y = max(current_y, knockback_velocity.y)
		knockback_velocity.y = 0

	state.linear_velocity.y = current_y

	# Трение для отталкивания
	# Вместо раздельного трения:
	var knockback_speed = knockback_velocity.length()
	if knockback_speed > 0:
		knockback_speed = move_toward(knockback_speed, 0, 20.0 * state.step)
		knockback_velocity = knockback_velocity.normalized() * knockback_speed

func interact():
	pass

@rpc("any_peer", "call_local", "reliable")
func _client_teleport(new_pos: Vector3, env_path: String): # временное отключение синхронизации чтобы она не откатывала телепорт двери
	var synchronizer = get_node_or_null("MultiplayerSynchronizer")
	if synchronizer:
		synchronizer.set_process(false)
		synchronizer.set_physics_process(false)
	
	global_position = new_pos
	sync_position = new_pos
	
	if env_path != "":
		var env = load(env_path)
		if env and camera:
			camera.environment = env
	
	await get_tree().create_timer(0.1).timeout
	
	if synchronizer:
		synchronizer.set_process(true)
		synchronizer.set_physics_process(true)

func set_environment(env: Environment): # для смены инваерментов
	if camera:
		camera.environment = env
