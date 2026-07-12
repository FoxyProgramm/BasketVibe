class_name TrashItem
extends ItemBase

@onready var area = $Area3D
@export var slow_down_speed: float = 15.0  # Скорость замедления
@export var delete_threshold: float = 0.2  # При какой скорости удалять
@export var ejection_force: float = 20.0
var is_slowing: bool = false

var sync_position:Vector3 = Vector3.ZERO
var sync_rotation:Vector3 = Vector3.ZERO

func is_swingable() -> bool:
	return true

func is_throwable() -> bool:
	return false

func is_pickable() -> bool:
	return false

func get_sync_properties() -> Array[String]:
	return ["sync_position", "sync_rotation"]

func _ready():
	super()
	$AnimationPlayer.play("new_animation")
	scale = scale* 1.3
	area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if self.is_multiplayer_authority():
		sync_position = global_position
		sync_rotation = global_rotation
	else :
		global_position = global_position.lerp(sync_position, 15.0 * delta)
		rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)
		rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
		rotation.z = lerp_angle(rotation.z, sync_rotation.z, 15.0 * delta)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		var eject_dir = (body.global_position - global_position).normalized() + Vector3.UP * 0.5
		eject_dir = eject_dir.normalized()
		body.rpc_id(body.name.to_int(), "apply_knockback", eject_dir, ejection_force)
	is_slowing = true
	if not multiplayer.is_server():
		return
	for group in Items.ITEM_NAMES:
		if body.is_in_group(group):
			_start_slow_and_delete(body)
			break

func _start_slow_and_delete(body: RigidBody3D):
	if is_slowing == true:
		await get_tree().create_timer(0.2).timeout
		body.angular_damp = slow_down_speed
		var tween = create_tween()
		tween.tween_property(body, "linear_damp", 20.0, 0.5).set_ease(Tween.EASE_IN)
		is_slowing = true
		while body.linear_velocity.length() > delete_threshold:
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		body.queue_free()
	
@rpc("any_peer", "call_local", "reliable")
func apply_item_impulse(impulse: Vector3) -> void:
	super(impulse*20)
	
	var hit_dir = impulse.normalized()
	var strength = impulse.length() * -0.5
	var torque = hit_dir.cross(Vector3.UP) * strength
	torque += hit_dir * strength * 0.3
	torque += hit_dir.cross(Vector3.RIGHT) * strength * 0.7
	
	apply_torque_impulse(torque*20)
