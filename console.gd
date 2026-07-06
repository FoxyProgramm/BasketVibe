extends VBoxContainer

@rpc("any_peer", "reliable")
func _spawn_item(item_id:int, count:int = 1) -> void:
	if not multiplayer.is_server(): return
	var players:Node3D = get_tree().get_first_node_in_group("players")
	var sender_id:int = multiplayer.get_remote_sender_id()
	var player = players.get_node_or_null(str(sender_id))
	var level_node = get_tree().current_scene.get_node_or_null("Level/Items")
	var spawn_position:Vector3 = Vector3(0, 5, 0)
	
	if player != null:
		spawn_position = player.global_position + Vector3(0, 2, 0)
	
	for i in range(count):
		var item = Items.ITEM_DICT.values()[item_id].instantiate()
		item.position = spawn_position
		if level_node:
			level_node.add_child(item, true)
		else:
			get_tree().current_scene.add_child(item, true)

func _delete_items(mode:int) -> void:
	if not multiplayer.is_server(): return
	

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
			match commands.get(1):
				"all":
					pass
				"radius":
					pass
				"count":
					pass
				"random":
					pass
				"persent":
					pass
				
				

func _on_line_edit_text_submitted(new_text: String) -> void:
	var regex = RegEx.create_from_string("\\w+")
	var results : Array[String] = []
	for result in regex.search_all(new_text):
		results.append(result.get_string())
	parse(results)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_debug_console"):
		self.visible = !self.visible
