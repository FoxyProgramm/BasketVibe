# BoxLevel.gd
extends Node3D

@export var box_scene: PackedScene
@export var grid_size: int = 6   # Уменьшил чтобы не нагружать
@export var layers: int = 3
@export var box_size: float = 1.0

func _ready():
	await get_tree().process_frame
	if multiplayer.is_server():
		_spawn_all_boxes()

func _spawn_all_boxes():
	var half = (grid_size - 1) * box_size / 2.0
	var count = 0
	
	for y in range(layers):
		for x in range(grid_size):
			await get_tree().process_frame  # Разгружаем кадр
			for z in range(grid_size):
				var local_pos = Vector3(
					x * box_size - half - 0.5,
					-y * box_size - 0.5,
					z * box_size - half - 0.5
				)
				var angle = randi_range(0, 3) * PI/2
				rpc("_create_box", local_pos, angle)
				count += 1
	


@rpc("any_peer", "call_local", "reliable")
func _create_box(local_pos: Vector3, angle: float):
	var box = box_scene.instantiate()
	box.position = local_pos
	box.rotation.y = angle
	box.freeze = true
	add_child(box)

func _process(delta):
	_check_fall()
func _check_fall():
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if not player.is_multiplayer_authority(): continue
		
		var dist_to_level = (player.global_position - global_position).length()
		var below_threshold = global_position.y - (layers * box_size) - 20.0  # 20 метров ниже дна
		
		if dist_to_level < 81 and player.global_position.y < below_threshold:
			# Телепорт на верх коробок
			var new_pos = Vector3(global_position.x, global_position.y + 20.0, global_position.z)
			if multiplayer.is_server():
				player.global_position = new_pos
				player.sync_position = new_pos
				player.rpc_id(player.name.to_int(), "_client_teleport", new_pos, "")
			else:
				rpc_id(1, "_teleport_player", player.get_path(), new_pos)

@rpc("any_peer", "reliable")
func _teleport_player(player_path: NodePath, new_pos: Vector3):
	if not multiplayer.is_server(): return
	var player = get_node_or_null(player_path)
	if player:
		player.global_position = new_pos
		player.sync_position = new_pos
		player.rpc_id(player.name.to_int(), "_client_teleport", new_pos, "")

func clear_boxes():
	if not multiplayer.is_server(): return
	rpc("_clear_boxes")

@rpc("any_peer", "call_local", "reliable")
func _clear_boxes():
	for child in get_children():
		if child.is_in_group("box"):
			child.visible = false
			child.collision_layer = 0
			child.collision_mask = 0
			child.freeze = true
			if multiplayer.is_server():
				child.queue_free()

func respawn_boxes():
	if multiplayer.is_server():
		_do_respawn()

@rpc("any_peer", "reliable")
func _do_respawn():
	if not multiplayer.is_server(): return
	_clear_boxes()
	await get_tree().process_frame
	_spawn_all_boxes()

@rpc("any_peer", "reliable")
func clear_boxes_at_level():
	if not multiplayer.is_server(): return
	clear_boxes()

@rpc("any_peer", "reliable")
func respawn_boxes_at_level():
	if not multiplayer.is_server(): return
	respawn_boxes()
