class_name BoxItem
extends ItemBase

var hold_offset := Vector3(0, 0.0, -2.5)
var setka: bool = true
@export var is_reinforced: bool = false
@export var sync_position: Vector3

func is_pickable() -> bool:
	return true

func is_throwable() -> bool:
	return false

func is_swingable() -> bool:
	return true

func get_sync_properties() -> Array[String]:
	return ["sync_position", "is_reinforced"]

func is_authority() -> int:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

func _ready() -> void:
	super()
	add_to_group("box")
	freeze = true  # Не двигается

func _update_state():
	if held_by_id != 0:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 3
		collision_mask = 3

func _physics_process(delta: float) -> void:
	if is_authority():
		if held_by_id != 0:
			var player = _get_player(held_by_id)
			if player:
				var head = player.get_node_or_null("Head")
				if head:
					var target_pos = head.global_transform * hold_offset
					if setka:
						var grid = 1.0
						target_pos.x = round(target_pos.x / grid) * grid
						target_pos.y = round(target_pos.y / grid) * grid + 0.5
						target_pos.z = round(target_pos.z / grid) * grid
					global_position = target_pos
		sync_position = global_position
	else:
		global_position = global_position.lerp(sync_position, 25.0 * delta)

@rpc("authority", "call_local", "reliable")
func request_drop(player_vel: Vector3 = Vector3.ZERO) -> void:
	super(Vector3.ZERO)
	freeze = true

@rpc("any_peer", "call_local", "reliable")
func setkas():
	setka = !setka

@rpc("any_peer", "call_local", "reliable")
func destroy():
	if is_reinforced: return
	if multiplayer.is_server():
		rpc("_do_destroy")

@rpc("call_local", "reliable")
func _do_destroy():
	if is_reinforced: return
	collision_layer = 0
	collision_mask = 0
	freeze = true
	held_by_id = 0
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_callback(_remove)

func _remove():
	if multiplayer.is_server():
		held_by_id = 0
		if held_by_player:
			held_by_player = null
		await get_tree().create_timer(0.1).timeout
		queue_free()

@rpc("any_peer", "call_local", "reliable")
func reinforce():
	is_reinforced = !is_reinforced
	rpc("_update_texture", is_reinforced)

@rpc("call_local", "reliable")
func _update_texture(reinforced: bool):
	var texture_path = "res://textures/crutaa_box.png" if reinforced else "res://textures/box.png"
	var mat = $MeshInstance3D.get_active_material(0).duplicate()
	mat.albedo_texture = load(texture_path)
	$MeshInstance3D.material_override = mat
