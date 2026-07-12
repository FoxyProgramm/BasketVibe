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
	super()
	add_to_group("seed")

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
	await get_tree().create_timer(0.5).timeout
	rpc("_remove_seed")

@rpc("any_peer", "call_local", "reliable")
func _remove_seed():
	queue_free()

@rpc("any_peer", "call_local", "reliable")
func _hide_seed():
	visible = false
	freeze = true
	set_process(false)
	set_physics_process(false)

@rpc("any_peer", "call_local", "reliable")
func request_throw(direction: Vector3, force: float, player_vel: Vector3 = Vector3.ZERO) -> void:
	super(direction, force, player_vel)
	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		rpc("mark_as_thrown")

@rpc("call_local", "reliable")
func mark_as_thrown():
	was_held = true

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
