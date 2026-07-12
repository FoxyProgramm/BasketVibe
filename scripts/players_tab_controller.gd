extends CenterContainer

var line := preload("res://scenes/player_tab_info_line.tscn")

var players:Dictionary[int, PlayerTabInfoLine] = {}
@onready var players_node:Node3D = get_tree().get_first_node_in_group("players")

func get_player(id:int) -> Player:
	return players_node.get_node_or_null(str(id))

func spawn_player(id:int) -> void:
	var player:Player = get_player(id)
	if player:
		player.rpc("reset_position")

func kick_player(id:int) -> void:
	var player:Player = get_player(id)
	if player:
		player.rpc_id(id, "disconnect_from_server")

func add_new_player(id:int, info:PlayerInfo) -> void:
	var new_line :PlayerTabInfoLine= line.instantiate()
	new_line.setup(id, info.name)
	new_line.on_spawn_clicked.connect(spawn_player.bind(id))
	new_line.on_kick_clicked.connect(kick_player.bind(id))
	players[id] = new_line
	$PanelContainer/MarginContainer/VBoxContainer.add_child(new_line)

func remove_player(id:int) -> void:
	players.get(id).queue_free()
	players.set(id, null)
