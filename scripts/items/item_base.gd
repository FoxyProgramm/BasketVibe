@abstract class_name ItemBase
extends RigidBody3D

#region Abstract functions
@abstract func is_pickable() -> bool
@abstract func is_throwable() -> bool
@abstract func is_swingable() -> bool
@abstract func get_sync_properties() -> Array[String]
#endregion

#region Properties
@export var held_by_id: int = 0:
	set(val):
		held_by_id = val
		_update_state()
#endregion

#region Regular functions

func _ready() -> void:
	var sync = MultiplayerSynchronizer.new()
	sync.root_path = NodePath("..")
	sync.name = "MultiplayerSynchronizer"
	
	var config = SceneReplicationConfig.new()
	
	for prop in get_sync_properties():
		config.add_property(NodePath(".:%s" % [prop]))
	
	sync.replication_config = config
	sync.replication_interval = 0.05
	sync.delta_interval = 0.05
	
	add_child(sync, true)

	if not multiplayer.is_server():
		freeze = true

@rpc("any_peer", "call_local", "reliable")
func transfer_authority(new_id:int, velocity: Vector3 = Vector3.ZERO) -> void:
	if new_id == multiplayer.get_unique_id():
		self.freeze = false
		self.sleeping = false
		linear_velocity = velocity
	else :
		self.freeze = true
		self.sleeping = true
	self.set_multiplayer_authority(new_id)

@rpc("any_peer", "call_local", "reliable")
func apply_item_impulse(impulse: Vector3) -> void:
	apply_central_impulse(impulse)

func _update_state():
	if held_by_id != 0:
		if not freeze:
			freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		if not is_multiplayer_authority():
			freeze = true
		else:
			if freeze:
				freeze = false
		collision_layer = 3
		collision_mask = 3

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.name == str(id):
			return p
	return null

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int) -> void:
	if not is_multiplayer_authority(): return
	if not is_pickable(): return
	if held_by_id != 0: return

	var player = _get_player(player_id)
	if player:
		held_by_id = player_id
		self.rotation = Vector3.ZERO
		rpc("update_held_state", player_id)
		rpc("transfer_authority", player_id)

@rpc("any_peer", "call_local", "reliable")
func request_drop(player_vel: Vector3 = Vector3.ZERO) -> void:
	if not is_multiplayer_authority(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		rpc("update_held_state", 0)
		linear_velocity = player_vel

@rpc("authority", "call_local", "reliable")
func update_held_state(new_id: int):
	if new_id == 0:
		var player :Player= _get_player(held_by_id)
		player.held_item = null
	else :
		var player := _get_player(new_id)
		player.held_item = self
	held_by_id = new_id

@rpc("any_peer", "call_local", "reliable")
func request_throw(direction: Vector3, force: float, player_vel: Vector3 = Vector3.ZERO) -> void:
	if not is_multiplayer_authority(): return
	if not is_throwable(): return

	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		#held_by_id = 0
		rpc("update_held_state", 0)
		linear_velocity = direction.normalized() * force + player_vel

#endregion
