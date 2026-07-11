# seed.gd
class_name SeedItem
extends ItemBase

var hold_offset := Vector3(0, -0.3, -1.2)

@export var sync_position: Vector3

@export var flower_mesh: Mesh
@export var flower_material: Material
@export var cluster_radius: float = 3.0
@export var flower_count: int = 40

var was_held: bool = false

func is_swingable() -> bool:
	return true

func is_throwable() -> bool:
	return true

func is_pickable() -> bool:
	return true

func is_authority() -> int:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

func get_sync_properties() -> Array[String]:
	return ["sync_position"]

func _ready() -> void:
	add_to_group("seed")
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	sync.root_path = NodePath("..")
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:sync_position"))
	sync.replication_config = config
	sync.replication_interval = 0.05
	sync.delta_interval = 0.05
	add_child(sync, true)
	sync_position = global_position
	if not multiplayer.is_server():
		freeze = true

func _physics_process(delta: float) -> void:
	if is_authority():
		if held_by_id != 0:
			var player = _get_player(held_by_id)
			if player:
				var head = player.get_node_or_null("Head")
				if head:
					global_position = head.global_transform * hold_offset
				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO
		sync_position = global_position
	else:
		global_position = global_position.lerp(sync_position, 25.0 * delta)



func _do_plant():
	if multiplayer.is_server():
		_plant(global_position)
	else:
		rpc_id(1, "_plant", global_position)

@rpc("any_peer", "reliable")
func _plant(pos: Vector3):
	if not multiplayer.is_server(): return
	rpc("_hide_seed")
	var mesh_path = flower_mesh.resource_path
	var mat_path = flower_material.resource_path if flower_material else ""
	pos.y -= 0.34
	get_tree().current_scene.rpc("spawn_flowers_at", pos, flower_count, cluster_radius, mesh_path, mat_path)

@rpc("any_peer", "call_local", "reliable")
func _hide_seed():
	visible = false
	freeze = true
	var tween = create_tween()
	tween.tween_callback(queue_free).set_delay(0.5)

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.name == str(id):
			return p
	return null

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int) -> void:
	if not is_authority(): return
	if held_by_id != 0 or was_held: return
	var player = _get_player(player_id)
	if player and global_position.distance_to(player.global_position) < 4.0:
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
		rpc("mark_as_thrown")
		linear_velocity = direction.normalized() * force + player_vel

@rpc("call_local", "reliable")
func mark_as_thrown():
	was_held = true

@rpc("authority", "call_local", "reliable")
func update_held_state(new_id: int):
	held_by_id = new_id

@rpc("any_peer", "call_local", "reliable")
func transfer_authority(new_id:int, velocity: Vector3 = Vector3.ZERO) -> void:
	if new_id == multiplayer.get_unique_id():
		self.freeze = false
		self.sleeping = false
		linear_velocity = velocity
	else:
		self.freeze = true
		self.sleeping = true
	self.set_multiplayer_authority(new_id)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if was_held and not body.is_in_group("player")and not body.is_in_group("seed"):
		_do_plant()
