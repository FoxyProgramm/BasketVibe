extends StaticBody3D

@export var item_type: String = "ball"
@onready var spawn_point = $Marker3D
@onready var area = $ballspawner/Area3D

var players_nearby: Array = []

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player") and body.is_multiplayer_authority():
		if not players_nearby.has(body):
			players_nearby.append(body)

func _on_body_exited(body: Node3D):
	players_nearby.erase(body)

func _process(_delta):
	if players_nearby.size() > 0 and Input.is_action_just_pressed("lkm"):
		_request_spawn()

func _request_spawn():
	if multiplayer.is_server():
		_spawn_item()
	else:
		rpc_id(1, "_spawn_item")

@rpc("any_peer", "reliable")
func _spawn_item():
	if not multiplayer.is_server():
		return
	
	var item
	if item_type == "ball":
		item = load("res://Ball.tscn").instantiate()
	else:
		item = load("res://Bat.tscn").instantiate()
	
	var spawn_pos = spawn_point.global_position if spawn_point else global_position + Vector3.UP * 0.5
	
	var level_node = get_tree().current_scene.get_node_or_null("Level")
	if level_node:
		level_node.add_child(item, true)
	else:
		get_tree().current_scene.add_child(item, true)
	
	item.global_position = spawn_pos
	
	rpc("_play_press_anim")

@rpc("call_local", "reliable")
func _play_press_anim():
	if $MeshInstance3D:
		var tween = create_tween()
		tween.tween_property($MeshInstance3D, "position:y", -0.1, 0.1)
		tween.tween_property($MeshInstance3D, "position:y", 0.0, 0.2)
