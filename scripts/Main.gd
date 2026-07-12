extends Node3D

var names : Array[String] = []
var item_id:int = 0

func get_item_id() -> String:
	item_id += 1
	return "Item_" + str(item_id)

const PORT = 7777
const MAX_CLIENTS = 12

@onready var main_menu = $UI/MainMenu
@onready var address_entry = $UI/MainMenu/AddressEntry
@onready var port_entry = $UI/MainMenu/PortEntry
@onready var players_node = $Players
@onready var level_node = $Level
@onready var level_items: Node3D = $Level/Items

@onready var username_line: LineEdit = $UI/MainMenu/HBoxContainer/Username

var players : Dictionary[int, PlayerInfo] = {}
var local_info := PlayerInfo.new()

var player_scene = preload("res://scenes/player.tscn")

func _ready():
	names = preload("res://resources/names.tres").names
	
	$PlayerSpawner.add_spawnable_scene("res://scenes/player.tscn")
	
	$LevelSpawner.add_spawnable_scene("res://scenes/items/ball.tscn")
	$LevelSpawner.add_spawnable_scene("res://scenes/items/bat.tscn")
	$LevelSpawner.add_spawnable_scene("res://scenes/items/radio.tscn")
	$LevelSpawner.add_spawnable_scene("res://scenes/items/trash.tscn")
	$LevelSpawner.add_spawnable_scene("res://scenes/items/seed.tscn")
	$LevelSpawner.add_spawnable_scene("res://scenes/items/box.tscn")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Привязываем функции к кнопкам
	$UI/MainMenu/HostButton.pressed.connect(_on_host_pressed)
	$UI/MainMenu/JoinButton.pressed.connect(_on_join_pressed)
	username_line.text = names.pick_random()

func _on_host_pressed():
	local_info.name = username_line.text
	local_info.skin = $UI/MainMenu/OptionButton.get_selected_id()
	main_menu.hide()
	$UI/background.visible = false
	var port = port_entry.text.to_int()
	if port <= 0: port = 7777

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		print("Cannot host: ", err)
		return
	multiplayer.multiplayer_peer = peer

	_spawn_player(multiplayer.get_unique_id())

	_spawn_item("ball", Vector3(0, 3, -4))
	_spawn_item("bat", Vector3(-2, 3, -4))
	_spawn_item("radio", Vector3(11.7, 2.5, -36.5))
	_spawn_item("trash", Vector3(35, 3.3, -33.2))
	_spawn_item("seed", Vector3(0, 3, 0))
	_spawn_item("box", Vector3(3,3,3))
	
func _on_join_pressed():
	main_menu.hide()
	local_info.name = username_line.text
	local_info.skin = $UI/MainMenu/OptionButton.get_selected_id()
	$UI/background.visible = false
	var port = port_entry.text.to_int()
	if port <= 0: port = 7777

	var peer = ENetMultiplayerPeer.new()
	var addr = address_entry.text
	if addr == "": addr = "127.0.0.1"
	var err = peer.create_client(addr, port)
	if err != OK:
		print("Cannot join: ", err)
		return
	multiplayer.multiplayer_peer = peer

@rpc("any_peer", "reliable")
func add_player(id:int, info:PackedByteArray) -> void:
	var info_ := PlayerInfo.unpack(info)
	players[id] = info_
	var player:Player = $Players.get_node_or_null(str(id))
	if player:
		player.get_node("Username").text = info_.name
		player.apply_skin(info_.skin)

func _on_peer_connected(id) -> void:
	if multiplayer.is_server():
		_spawn_player(id)
		sync_vars(id)
	rpc_id(id, "add_player", multiplayer.get_unique_id(), local_info.pack())
	
func _on_peer_disconnected(id) -> void:
	if not multiplayer.is_server():return 
		
	if players_node.has_node(str(id)):
		players_node.get_node(str(id)).queue_free()

	for child in $Level/Items.get_children():
		if child and child is ItemBase:
			if child.held_by_id == id:
				child.rpc("transfer_authority", 1)
				child.held_by_id = 0
				child.freeze = false
			elif child.get_multiplayer_authority() == id:
				child.rpc("transfer_authority", 1)
				child.freeze = false
				child.held_by_id = 0

func _spawn_player(id: int):
	var p = player_scene.instantiate()
	p.name = str(id)
	p.position = Vector3(randf_range(-10, 10), 2, randf_range(-10, 10))
	players_node.add_child(p, true)

func _spawn_item(item:String, position_:Vector3 = Vector3(0,2,0)) -> void:
	var b = Items.ITEM_DICT.get(item).instantiate()
	b.name = get_item_id()
	if b:
		b.position = position_
		level_items.add_child(b, true)

func _on_menu_character_selected(index: int) -> void:
	var character: Characters.Character = Characters.LIST.get(index)
	if character:
		$UI/MainMenu/Control/TextureRect.texture = character.head_texture

func get_local_skin() -> int:
	return local_info.skin

@rpc("call_local", "reliable")
func spawn_flowers_at(pos: Vector3, count: int, radius: float, mesh_path: String, mat_path: String):
	var mesh = load(mesh_path)
	var material = load(mat_path) if mat_path != "" else null
	
	var container = Node3D.new()
	container.name = "FlowerCluster"
	container.position = pos
	level_items.add_child(container)
	
	var multimesh = MultiMeshInstance3D.new()
	multimesh.multimesh = MultiMesh.new()
	multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.multimesh.mesh = mesh
	multimesh.multimesh.instance_count = count
	multimesh.position = Vector3.ZERO
	container.add_child(multimesh)
	
	for i in range(count):
		var x = randf_range(-radius, radius)
		var z = randf_range(-radius, radius)
		var local_pos = Vector3(x, 0, z)
		var angle = randf() * TAU
		var scale = randf_range(1.5, 2.5)
		
		var t = Transform3D()
		t.origin = local_pos
		t = t.rotated(Vector3.UP, angle)
		t = t.scaled(Vector3(scale, scale, scale))
		multimesh.multimesh.set_instance_transform(i, t)
	
	multimesh.multimesh.visible_instance_count = count
	if material:
		multimesh.material_override = material

func _on_reroll_username_pressed() -> void:
	username_line.text = names.pick_random()

func sync_vars(id):
	var spike_forest = get_node_or_null("Level/level_thorn")
	if spike_forest:
		spike_forest.rpc_id(id, "set_seed", spike_forest.seed_value)
	var console = $"UI/Debug/Console"
	console.rpc_id(id, "_update_cheat_mode", console.cheat_mode)
