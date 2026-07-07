extends MeshInstance3D

var time_offset: float
var sway_amount: float
var sway_speed: float

func _ready():
	time_offset = randf() * TAU
	sway_amount = randf_range(0.02, 0.06)
	sway_speed = randf_range(1.0, 2.5)
	# Рандомный размер
	var s = randf_range(0.7, 1.3)
	scale = Vector3(s, s, s)
	
	# Рандомный поворот
	rotation.y = randf() * TAU

func _process(_delta):
	var sway = sin(Time.get_ticks_msec() * 0.001 * sway_speed + time_offset) * sway_amount
	rotation.z = sway
	rotation.x = sway * 0.5
