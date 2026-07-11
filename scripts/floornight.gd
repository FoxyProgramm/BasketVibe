extends StaticBody3D

@export var synced_rotation_y: float = 0.0:
	set(val):
		synced_rotation_y = val
		rotation_degrees.y = val
func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	generate_collision()
	
	# Создаём синхронизатор
	var sync = MultiplayerSynchronizer.new()
	sync.root_path = NodePath("..")
	sync.name = "MultiplayerSynchronizer"
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:synced_rotation_y"))
	sync.replication_config = config
	add_child(sync, true)
	
	if multiplayer.is_server():
		synced_rotation_y = 90 * randi_range(1, 4)


func generate_collision():
	var mesh_instance = $MeshInstance3D
	var original_mesh = mesh_instance.mesh
	
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var arrays = original_mesh.get_mesh_arrays()
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices = arrays[Mesh.ARRAY_INDEX]
	
	if indices == null or indices.size() == 0:
		indices = PackedInt32Array()
		for i in range(vertices.size()):
			indices.append(i)
	
	var bumps = [
		Vector2(0.2, 0.1), Vector2(0.5, 0.15), Vector2(0.8, 0.2),
		Vector2(0.15, 0.4), Vector2(0.45, 0.45), Vector2(0.75, 0.4),
		Vector2(0.1, 0.7), Vector2(0.4, 0.75), Vector2(0.7, 0.7),
		Vector2(0.25, 0.9), Vector2(0.55, 0.9), Vector2(0.85, 0.85)
	]
	var radii = [0.25, 0.28, 0.25, 0.28, 0.3, 0.28, 0.25, 0.28, 0.25, 0.28, 0.25, 0.28]
	var heights_arr = [0.6, 0.8, 0.5, 0.7, 1.0, 0.6, 0.8, 0.9, 0.5, 0.7, 0.6, 0.8]
	
	var small_bumps = [
		Vector2(0.05, 0.05), Vector2(0.3, 0.2), Vector2(0.6, 0.1), Vector2(0.9, 0.35),
		Vector2(0.15, 0.55), Vector2(0.5, 0.6), Vector2(0.8, 0.55), Vector2(0.35, 0.85)
	]
	var small_radii = [0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18]
	var small_heights = [0.3, 0.4, 0.3, 0.4, 0.3, 0.4, 0.3, 0.4]
	
	for i in range(vertices.size()):
		var uv = uvs[i] if uvs and i < uvs.size() else Vector2.ZERO
		var height = 0.0
		
		for j in range(12):
			var dist = uv.distance_to(bumps[j])
			if dist < radii[j]:
				var t = 1.0 - (dist / radii[j])
				t = t * t * (3.0 - 2.0 * t)
				height += heights_arr[j] * t * 2.7
		
		for k in range(8):
			var dist = uv.distance_to(small_bumps[k])
			if dist < small_radii[k]:
				var t = 1.0 - (dist / small_radii[k])
				t = t * t * (3.0 - 2.0 * t)
				height += small_heights[k] * t * 1.4
		
		vertices[i].y += height
		surface_tool.add_vertex(vertices[i])
	
	for i in indices:
		surface_tool.add_index(i)
	
	surface_tool.generate_normals()
	var new_mesh = surface_tool.commit()
	
	var collision_shape = $CollisionShape3D
	var concave_shape = ConcavePolygonShape3D.new()
	concave_shape.set_faces(new_mesh.get_faces())
	collision_shape.shape = concave_shape
	collision_shape.position = Vector3.ZERO
	collision_shape.scale = Vector3.ONE
	collision_shape.rotation = Vector3.ZERO
