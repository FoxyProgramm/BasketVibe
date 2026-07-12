class_name NameStorer
extends Resource

@export var names: Array[String] = []

static func create(names_:Array[String]) -> NameStorer:
	var new_instance := NameStorer.new()
	new_instance.names = names_
	return new_instance
