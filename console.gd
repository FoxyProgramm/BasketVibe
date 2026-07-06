extends VBoxContainer

func parse(commands:Array[String]) -> void:
	print(commands)

func _on_line_edit_text_submitted(new_text: String) -> void:
	var regex = RegEx.create_from_string("/\\w+/g")
	var results : Array[String] = []
	for result in regex.search_all(new_text):
		results.push_back(result.get_string())
	parse(results)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_debug_console"):
		self.visible = !self.visible
