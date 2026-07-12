extends Node3D

@export var spike_mesh: Mesh
@export var spike_material: Material
@export var area_size: float = 100.0
@export var spike_count: int = 500
@export var min_radius: float = 0.3
@export var max_radius: float = 0.8
@export var max_depth = 15.0
@export var seed_value: int = 12345

var spike_multimesh: MultiMeshInstance3D

@export var teleport_margin: float = 2.0  # Отступ от края
@export var collision_radius: float = 15.0
@export var max_collisions: int = 40
@export var player_path: NodePath

var player: Node3D
var active_collisions: Array[StaticBody3D] = []
var collision_timer: float = 0.0

func _ready():
	if multiplayer.is_server():
		seed_value = randi()
	# Всегда генерируем шипы
	_generate_spikes()
	_generate_collisions()
func _process(delta):
	_check_teleport()

func _check_teleport():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	
	for player in players:
		if not player.is_multiplayer_authority(): continue
		if abs(player.global_position.y - global_position.y) > 20.0:
			continue
		
		var half = area_size / 2.0
		var pos = player.global_position
		var new_pos = pos
		var teleported = false
		
		if pos.x > half - teleport_margin:
			new_pos.x = -half + teleport_margin
			teleported = true
		elif pos.x < -half + teleport_margin:
			new_pos.x = half - teleport_margin
			teleported = true
		
		if pos.z > half - teleport_margin:
			new_pos.z = -half + teleport_margin
			teleported = true
		elif pos.z < -half + teleport_margin:
			new_pos.z = half - teleport_margin
			teleported = true
		
		if teleported:
			_play_pacman_teleport()
			if multiplayer.is_server():
				player.global_position = new_pos
				player.sync_position = new_pos
				player.rpc_id(player.name.to_int(), "_client_teleport", new_pos, "")
			else:
				rpc_id(1, "_teleport_player", player.get_path(), new_pos)
	
	_push_items_from_edge()

func _push_items_from_edge():
	if not multiplayer.is_server(): return
	
	var half = area_size / 2.0
	var margin = teleport_margin * 1.05
	var location_y = global_position.y
	var height_threshold = 20.0 
	
	for group in Items.ITEM_NAMES:
		for item in get_tree().get_nodes_in_group(group):
			# Проверяем что предмет примерно на высоте леса
			if abs(item.global_position.y - location_y) > height_threshold:
				continue
			
			var ipos = item.global_position
			var pushed = false
			
			if ipos.x > half - margin:
				ipos.x = half - margin
				pushed = true
			elif ipos.x < -half + margin:
				ipos.x = -half + margin
				pushed = true
			
			if ipos.z > half - margin:
				ipos.z = half - margin
				pushed = true
			elif ipos.z < -half + margin:
				ipos.z = -half + margin
				pushed = true
			
			if pushed:
				item.global_position = ipos
				if item is RigidBody3D:
					item.linear_velocity = Vector3.ZERO

@rpc("any_peer", "reliable")
func _teleport_player(player_path: NodePath, new_pos: Vector3):
	if not multiplayer.is_server(): return
	var player = get_node_or_null(player_path)
	if player:
		player.global_position = new_pos
		player.sync_position = new_pos
		player.rpc_id(player.name.to_int(), "_client_teleport", new_pos, "")

var rand := RandomNumberGenerator.new()

func _get_random_properties() -> Dictionary[String, Variant]:
	var result :Dictionary[String, Variant] = {}
	
	result['pos'] = Vector3(
		rand.randf_range(-area_size / 2, area_size / 2),
	 	rand.randf_range(0, max_depth),
		rand.randf_range(-area_size / 2, area_size / 2)
	)
	result['tilt'] = Vector2( rand.randf_range(-0.1, 0.1), rand.randf_range(-0.1, 0.1) )
	result['radius'] = rand.randf_range(min_radius, max_radius)
	result['rotate_y'] = rand.randf() * TAU
	
	return result

func _generate_collisions():
	rand.seed = seed_value
	rand.state = 0
	
	for i in range(spike_count):
		var properties := _get_random_properties()
		
		var x:float = properties['pos'].x
		var z:float = properties['pos'].z
		var depth:float = properties['pos'].y
		var radius:float = properties['radius']
		var tilt_x:float = properties['tilt'].x
		var tilt_z:float = properties['tilt'].y
		var rot_y:float = properties['rotate_y']
		
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.height = 18.0 - depth
		shape.radius = radius * 0.5
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		
		var t = Transform3D()
		t.origin = Vector3(x, -depth, z)
		var basis_ = Basis()
		basis_ = basis_.rotated(Vector3.UP, rot_y)
		basis_ = basis_.rotated(Vector3.RIGHT, tilt_x)
		basis_ = basis_.rotated(Vector3.FORWARD, tilt_z)
		t.basis = basis_.scaled(Vector3(radius, 1.0, radius))
		body.transform = t
		
		body.collision_layer = 1
		body.collision_mask = 1
		add_child(body)
		active_collisions.append(body)
	
@rpc("call_local", "reliable")
func set_seed(seed: int):
	seed_value = seed
	_generate_spikes()
	# Удаляем старые коллизии и создаём новые
	for c in active_collisions:
		c.queue_free()
	active_collisions.clear()
	_generate_collisions()

func _generate_spikes():
	if spike_multimesh:
		spike_multimesh.queue_free()
	
	rand.seed = seed_value
	rand.state = 0
	
	spike_multimesh = MultiMeshInstance3D.new()
	spike_multimesh.multimesh = MultiMesh.new()
	spike_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	spike_multimesh.multimesh.mesh = spike_mesh
	spike_multimesh.multimesh.instance_count = spike_count
	add_child(spike_multimesh)
	
	for i in range(spike_count):
		var properties := _get_random_properties()

		var x:float = properties["pos"].x
		var z:float = properties["pos"].z
		var depth:float = properties["pos"].y
		var radius:float = properties["radius"]
		var tilt_x:float = properties["tilt"].x
		var tilt_z:float = properties["tilt"].y
		var rot_y:float = properties["rotate_y"]
		
		var t = Transform3D()
		t.origin = Vector3(x, -depth, z)  # Заглубляем
		
		var basis_ = Basis()
		basis_ = basis_.rotated(Vector3.UP, rot_y)
		basis_ = basis_.rotated(Vector3.RIGHT, tilt_x)
		basis_ = basis_.rotated(Vector3.FORWARD, tilt_z)
		t.basis = basis_.scaled(Vector3(radius, 1.0, radius))
		
		spike_multimesh.multimesh.set_instance_transform(i, t)

	spike_multimesh.multimesh.visible_instance_count = spike_count
	
	if spike_material:
		spike_multimesh.material_override = spike_material

@rpc("call_local", "reliable")
func _play_pacman_teleport():
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_multiplayer_authority(): return
	
	var cam = player.get_node_or_null("Head/Camera3D")
	if not cam: return
	
	var black = ColorRect.new()
	black.color = Color.BLACK
	black.size = get_viewport().get_visible_rect().size
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(black)
	var tween = create_tween()
	tween.tween_property(black, "color:a", 0.0, 0.35)
