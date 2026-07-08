extends VBoxContainer

@export var output_label: RichTextLabel
@export var line_edit: LineEdit

@onready var background = get_tree().get_first_node_in_group("background")

var command_history: Array[String] = []
var history_index: int = -1

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
	var player = players.get_node_or_null(str(sender_id))
	var level_node = get_tree().current_scene.get_node_or_null("Level/Items")
	var spawn_position:Vector3 = Vector3(0, 5, 0)
	
	if player:
		spawn_position = player.global_position + Vector3(0, 2, 0)
	
	for i in range(count):
		var item = Items.ITEM_DICT.values()[item_id].instantiate()
		item.position = spawn_position
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
				log_info("Delited " + str(child), "#5a8a54")
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
				if FileAccess.file_exists(path):
					if multiplayer.is_server():
						_add_song(path)
					else:
						rpc_id(1, "_add_song", path)
					log_info("Successful add track from " + path, "#12ab00")
				else:
					log_info("Error add track, check your path: " + path, "red")

@rpc("any_peer", "reliable")
func _add_song(path: String):
	if not multiplayer.is_server():
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	# Отправляем аудиоданные всем радио
	for radio in get_tree().get_nodes_in_group("radio"):
		radio.rpc("_receive_song_data", data)
				

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
