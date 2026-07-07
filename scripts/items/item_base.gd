@abstract class_name ItemBase
extends RigidBody3D

#region Abstract functions
@abstract func is_pickable() -> bool

#endregion


#region Regular functions
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

#endregion
