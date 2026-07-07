extends MarginContainer

func set_text(label:int, text:Variant) -> void:
	var display_label : Label = $Display.get_child(clamp(label, 0, $Display.get_child_count()))
	display_label.text = str(text)
	
