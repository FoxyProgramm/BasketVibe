extends CenterContainer

var line := preload("res://scenes/player_tab_info_line.tscn")

var players:Dictionary[int, PlayerTabInfoLine] = {}

func add_new_player(id:int, info:PlayerInfo) -> void:
	var new_line :PlayerTabInfoLine= line.instantiate()
	new_line.setup(id, info.name)
	players[id] = new_line
	$PanelContainer/MarginContainer/VBoxContainer.add_child(new_line)

func remove_player(id:int) -> void:
	players.get(id).queue_free()
	players.set(id, null)
