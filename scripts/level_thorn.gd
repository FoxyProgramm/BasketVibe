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
	for body in active_collisions:
		body.rotate_y(delta * 0.0)
func _generate_collisions():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	for i in range(spike_count):
		var x = rng.randf_range(-area_size / 2, area_size / 2)
		var z = rng.randf_range(-area_size / 2, area_size / 2)
		var depth = rng.randf_range(0, max_depth)
		var radius = rng.randf_range(min_radius, max_radius)
		var tilt_x = rng.randf_range(-0.1, 0.1)
		var tilt_z = rng.randf_range(-0.1, 0.1)
		var rot_y = rng.randf() * TAU
		
		var body = StaticBody3D.new()
		var shape = CylinderShape3D.new()
		shape.height = 18.0 - depth
		shape.radius = radius * 0.5
		var col = CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		
		body.position = Vector3(x, -depth, z)
		body.rotation_degrees = Vector3(rad_to_deg(tilt_x), rad_to_deg(rot_y), rad_to_deg(tilt_z))
		body.scale = Vector3(radius, 1.0, radius)
		body.collision_layer = 1
		body.collision_mask = 1
		add_child(body)
		active_collisions.append(body)
	
	print("Всего коллизий: ", active_collisions.size())

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
	
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	spike_multimesh = MultiMeshInstance3D.new()
	spike_multimesh.multimesh = MultiMesh.new()
	spike_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	spike_multimesh.multimesh.mesh = spike_mesh
	spike_multimesh.multimesh.instance_count = spike_count
	add_child(spike_multimesh)
	
	for i in range(spike_count):
		var x = rng.randf_range(-area_size / 2, area_size / 2)
		var z = rng.randf_range(-area_size / 2, area_size / 2)
		
		var depth = rng.randf_range(0, max_depth)  # Насколько уходит под землю
		var visible_height = 18.0 - depth           # Сколько видно над землёй
		
		var tilt_x = rng.randf_range(-0.1, 0.1)
		var tilt_z = rng.randf_range(-0.1, 0.1)
		
		var t = Transform3D()
		t.origin = Vector3(x, -depth, z)  # Заглубляем
		
		var basis = Basis()
		basis = basis.rotated(Vector3.UP, rng.randf() * TAU)
		basis = basis.rotated(Vector3.RIGHT, tilt_x)
		basis = basis.rotated(Vector3.FORWARD, tilt_z)
		var radius = rng.randf_range(min_radius, max_radius)
		t.basis = basis.scaled(Vector3(radius, 1.0, radius))
		
		spike_multimesh.multimesh.set_instance_transform(i, t)
		if i == 0:
			print("Шип 0: origin=", t.origin, " rotation_deg=", t.basis.get_euler() * 180/PI, " scale=", t.basis.get_scale())
	
	spike_multimesh.multimesh.visible_instance_count = spike_count
	
	if spike_material:
		spike_multimesh.material_override = spike_material
	
