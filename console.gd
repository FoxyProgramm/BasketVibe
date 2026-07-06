extends VBoxContainer

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

@rpc("any_peer", "reliable")
func _delete_items(mode:int) -> void:
	if not multiplayer.is_server(): return
	var level_node = get_tree().current_scene.get_node_or_null("Level/Items")
	match mode:
		0: #ALL
			for child in level_node.get_children():
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
				
				

func _on_line_edit_text_submitted(new_text: String) -> void:
	var regex = RegEx.create_from_string("\\w+")
	var results : Array[String] = []
	for result in regex.search_all(new_text):
		results.append(result.get_string())
	parse(results)
	self.hide()
	toggle_mouse()

func toggle_mouse() -> void:
	if self.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		$LineEdit.grab_focus()
		$LineEdit.text = ""
	else :
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_debug_console"):
		self.visible = !self.visible
		toggle_mouse()
