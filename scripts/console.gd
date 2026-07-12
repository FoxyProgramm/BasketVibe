extends VBoxContainer

@export var output_label: RichTextLabel
@export var line_edit: LineEdit

@onready var background = get_tree().get_first_node_in_group("background")

@onready var main: Node3D = $"../../.."

var command_history: Array[String] = []
var history_index: int = -1

var cheat_mode: String = "nobody"


func _ready():
	pass
	#line_edit.text_submitted.connect(_on_line_edit_text_submitted)

func _on_command_submitted(new_text: String):
	if new_text.is_empty(): return
	
	command_history.append(new_text)
	history_index = command_history.size() - 1
	
	console_log("[color=green]> " + new_text + "[/color]")
	
	var space_pos = new_text.find(" ")
	var command = new_text.substr(0, space_pos) if space_pos != -1 else new_text
	var args = new_text.substr(space_pos + 1).strip_edges() if space_pos != -1 else ""
	
	var commands: Array[String] = [command]
	if args != "": commands.append(args)
	parse(commands)
	
	line_edit.text = ""

func console_log(text: String):
	output_label.append_text(text + "\n")

@rpc("any_peer", "reliable")
func _spawn_item(item_id:int, count:int = 1) -> void:
	if not multiplayer.is_server(): return
	var players:Node3D = get_tree().get_first_node_in_group("players")
	var sender_id:int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	var player = players.get_node_or_null(str(sender_id))
	var level_node = get_tree().current_scene.get_node_or_null("Level/Items")
	var spawn_position:Vector3 = Vector3(0, 5, 0)
	
	if player:
		spawn_position = player.global_position + Vector3(0, 3, 0)
	
	for i in range(count):
		var item = Items.ITEM_DICT.values()[item_id].instantiate()
		item.position = spawn_position
		item.name = main.get_item_id()
		if level_node:
			level_node.add_child(item, true)
		else:
			get_tree().current_scene.add_child(item, true)
		log_info("Created " + str(item) + " on " + str(position), "#5a8a54")
	log_info("Successful created, total count:" + str(count), "#12ab00")

@rpc("any_peer", "reliable")
func _delete_items(mode:int) -> void:
	if not multiplayer.is_server(): return
	var level_node = get_tree().current_scene.get_node_or_null("Level/Items")
	match mode:
		0: #ALL
			for child in level_node.get_children():
				log_info("Deleted " + str(child), "#5a8a54")
				child.queue_free()

func parse(commands:Array[String]) -> void:
	match commands.get(0):
		"create":
			var idx:int = 0
			if Items.ITEM_DICT.has(commands.get(1)):
				idx = Items.ITEM_DICT.keys().find(commands[1])
			if multiplayer.is_server():
				_spawn_item(idx, int(commands.get(2)) if commands.size() > 2 else 1)
			else :
				rpc_id(1, "_spawn_item", idx, int(commands.get(2)) if commands.size() > 2 else 1)
		"delete":
			var delete_modes:Array[String] = ["all", "radius", "count"]
			var idx:int = delete_modes.find(commands.get(1))
			idx = max(idx, 0)
			if multiplayer.is_server():
				_delete_items(idx)
			else :
				rpc_id(1, "_delete_items", idx)
		"addsong":
			if commands.size() > 1:
				var path = commands[1]
				_client_add_song(path)
		"cheats":
			if commands.size() > 1:
				var mode = commands[1]
				if mode in ["nobody", "host", "all"]:
					if multiplayer.is_server():
						_set_cheat_mode(mode)
					else:
						log_info("You do not have permission to change cheat operation mode", "red")
				else:
					log_info("Unknown cheat operation mode", "red")
		"noclip":
			if not can_use_cheats():
				cantusecheats()
				return
			var player = get_tree().get_first_node_in_group("player")
			if player and player.is_multiplayer_authority():
				player.noclip = !player.noclip
				log_info("Noclip: " + str(player.noclip), "#12ab00")
		"resetpos":
			var player = get_tree().get_first_node_in_group("player")
			if player and player.is_multiplayer_authority():
				var new_pos = Vector3.ZERO
				if multiplayer.is_server():
					player.global_position = new_pos
					player.sync_position = new_pos
					player.rpc_id(player.name.to_int(), "_client_teleport", new_pos, "")
				else:
					rpc_id(1, "_teleport_player", player.get_path(), new_pos)
				log_info("Your coordinate reseted", "#12ab00")

@rpc("any_peer", "reliable")
func _teleport_player(player_path: NodePath, new_pos: Vector3):
	if not multiplayer.is_server(): return
	var player = get_node_or_null(player_path)
	if player:
		player.global_position = new_pos
		player.sync_position = new_pos
		player.rpc_id(player.name.to_int(), "_client_teleport", new_pos, "")

@rpc("any_peer", "reliable")
func _set_cheat_mode(mode: String):
	if not multiplayer.is_server(): return
	cheat_mode = mode
	rpc("_update_cheat_mode", mode)

@rpc("call_local", "reliable")
func _update_cheat_mode(mode: String):
	cheat_mode = mode
	log_info("Cheats mode: " + mode, "#12ab00")

func can_use_cheats() -> bool:
	match cheat_mode:
		"all":  return true
		"host": return multiplayer.is_server()
		_: return false

func cantusecheats():
	log_info("You do not have permission to use cheats commands", "red")
@rpc("any_peer", "reliable")
func _add_song(data: PackedByteArray):
	if not multiplayer.is_server():
		return
	
	for radio in get_tree().get_nodes_in_group("radio"):
		radio.rpc("_receive_song_data", data)
	
	log_info("Successful add track", "#12ab00")

func _client_add_song(path: String):
	if not FileAccess.file_exists(path):
		log_info("Error add track, check your path: " + path, "red")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var data = file.get_buffer(file.get_length())
	file.close()
	
	if multiplayer.is_server():
		_add_song(data)
	else:
		rpc_id(1, "_add_song", data)
	log_info("Sending track to all players...", "#88ccff")

func _on_line_edit_text_submitted(new_text: String) -> void:
	if new_text.is_empty(): return
	
	command_history.append(new_text)
	history_index = command_history.size() - 1
	
	console_log("[color=green]> " + new_text + "[/color]")
	
	var commands := _parse_args(new_text)
	parse(commands)
	
	line_edit.text = ""
	self.hide()
	background.visible = false
	toggle_mouse()

func _parse_args(text: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var in_quotes := false
	
	for i in range(text.length()):
		var ch = text[i]
		
		if ch == "\"":
			in_quotes = !in_quotes
			continue
		
		if ch == " " and not in_quotes:
			if current != "":
				result.append(current)
				current = ""
			continue
		
		current += ch
	
	if current != "":
		result.append(current)
	
	return result

signal console_toggled(is_open: bool)
func toggle_mouse() -> void:
	if self.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		$LineEdit.grab_focus()
		await get_tree().create_timer(0.03).timeout
		$LineEdit.text = ""
		output_label.scroll_to_line(output_label.get_line_count() - 1)
	else :
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	console_toggled.emit(self.visible)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_debug_console"):
		self.visible = !self.visible
		background.visible = !background.visible
		toggle_mouse()
	if not visible: return
	
	if event.is_action_pressed("ui_up"):
		if command_history.size() > 0:
			history_index = max(history_index, 0)
			line_edit.text = command_history[history_index]
			history_index -= 1
			if history_index < 0:
				history_index = command_history.size() - 1
			line_edit.caret_column = line_edit.text.length()
	
	if event.is_action_pressed("ui_down"):
		history_index = (history_index + 1) % command_history.size()
		line_edit.text = command_history[history_index]
		line_edit.caret_column = line_edit.text.length()

func log_info(text: String, color: String = "#66ff66"):
	console_log("[color=" + color + "]" + text + "[/color]")
