extends Node3D

@onready var floor = $Floor
@export var flower_mesh: Mesh
@export var flower_material: Material
@export var plane_size: float = 82.0  # Размер PlaneMesh

var clusters_data = [
	# Левый верхний бугор (0.2, 0.1)
	{"uv": Vector2(0.2, 0.1), "height": 1.5, "radius": 2.5, "count": 30},
	# Верхний центр (0.5, 0.15)
	{"uv": Vector2(0.5, 0.15), "height": 1.7, "radius": 3.0, "count": 35},
	# Правый верхний (0.8, 0.2)
	{"uv": Vector2(0.8, 0.2), "height": 1.3, "radius": 2.5, "count": 30},
	
	# Левый средний (0.15, 0.4)
	{"uv": Vector2(0.15, 0.4), "height": 1.6, "radius": 3.0, "count": 35},
	# Центр (0.45, 0.45) — самый высокий бугор
	{"uv": Vector2(0.45, 0.45), "height": 2.0, "radius": 4.0, "count": 45},
	# Правый средний (0.75, 0.4)
	{"uv": Vector2(0.75, 0.4), "height": 1.4, "radius": 2.5, "count": 30},
	
	# Левый нижний (0.1, 0.7)
	{"uv": Vector2(0.1, 0.7), "height": 1.7, "radius": 3.0, "count": 35},
	# Нижний центр (0.4, 0.75)
	{"uv": Vector2(0.4, 0.75), "height": 1.9, "radius": 3.5, "count": 40},
	# Правый нижний (0.7, 0.7)
	{"uv": Vector2(0.7, 0.7), "height": 1.3, "radius": 2.5, "count": 30},
	
	# Нижний левый угол (0.25, 0.9)
	{"uv": Vector2(0.25, 0.9), "height": 1.6, "radius": 2.5, "count": 25},
	# Нижний центр 2 (0.55, 0.9)
	{"uv": Vector2(0.55, 0.9), "height": 1.5, "radius": 2.5, "count": 25},
	# Нижний правый угол (0.85, 0.85)
	{"uv": Vector2(0.85, 0.85), "height": 1.7, "radius": 3.0, "count": 30},
	
	# Мелкие бугры
	{"uv": Vector2(0.05, 0.05), "height": 1.0, "radius": 2.0, "count": 20},
	{"uv": Vector2(0.3, 0.2), "height": 1.2, "radius": 2.0, "count": 20},
	{"uv": Vector2(0.6, 0.1), "height": 1.0, "radius": 2.0, "count": 20},
	{"uv": Vector2(0.9, 0.35), "height": 1.2, "radius": 2.0, "count": 20},
	{"uv": Vector2(0.15, 0.55), "height": 1.0, "radius": 2.0, "count": 20},
	{"uv": Vector2(0.5, 0.6), "height": 1.2, "radius": 2.0, "count": 20},
	{"uv": Vector2(0.8, 0.55), "height": 1.0, "radius": 2.0, "count": 20},
	{"uv": Vector2(0.35, 0.85), "height": 1.2, "radius": 2.0, "count": 20},
]
func _ready():
	for data in clusters_data:
		spawn_flower_cluster(data)

func spawn_flower_cluster(data: Dictionary):
	var uv = data["uv"]
	var h = data["height"]
	var r = data["radius"]
	var count = data["count"]
	
	var world_x = (uv.x - 0.5) * plane_size
	var world_z = (uv.y - 0.5) * plane_size
	var center = Vector3(world_x, h, world_z)
	
	var container = Node3D.new()
	container.name = "FlowerCluster"
	container.position = center
	floor.add_child(container)
	
	var multimesh = MultiMeshInstance3D.new()
	multimesh.multimesh = MultiMesh.new()
	multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.multimesh.mesh = flower_mesh
	multimesh.multimesh.instance_count = count
	multimesh.position = Vector3.ZERO
	container.add_child(multimesh)
	
	for i in range(count):
		var x = randf_range(-r, r)
		var z = randf_range(-r, r)
		var local_pos = Vector3(x, 0, z)
		var angle = randf() * TAU
		var scale = randf_range(1.5, 2.5)
		
		var t = Transform3D()
		t.origin = local_pos
		t = t.rotated(Vector3.UP, angle)
		t = t.scaled(Vector3(scale, scale, scale))
		multimesh.multimesh.set_instance_transform(i, t)
	
	multimesh.multimesh.visible_instance_count = count
	
	if flower_material:
		multimesh.material_override = flower_material
