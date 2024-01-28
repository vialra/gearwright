extends ColorRect

@onready var slot_scene = preload("res://Scenes/grid_slot.tscn")
@onready var item_scene = preload("res://Scenes/item.tscn")

@onready var head_container = $ContainerContainer/HeadContainer
@onready var chest_container = $ContainerContainer/ChestContainer
@onready var l_arm_container = $ContainerContainer/LeftArmContainer
@onready var r_arm_container = $ContainerContainer/RightArmContainer
@onready var leg_container = $ContainerContainer/LegContainer
@onready var containers = [chest_container, l_arm_container, r_arm_container, head_container, leg_container]

@onready var stats = $"../VBoxContainer/Stats/StatsList"

var save_path = "res://Data/Save Data/"
var screenshot_path = "res://Screenshots/"

var grid_array := []
var item_held = null
var current_slot = null
var can_place := false
var can_lock := false
var icon_anchor : Vector2
enum Modes {EQUIP, PLACE, UNLOCK}
var mode = Modes.EQUIP

var fisher

signal item_installed(item)
signal item_removed(item)

var default_unlocks := []
signal incrememnt_lock_tally(change)
signal set_gear_ability(frame_data)

# Called when the node enters the scene tree for the first time.
func _ready():
	for container in containers:
		for i in container.capacity:
			create_slot(container)
	
	fisher = DataHandler.create_player()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("mouse_leftclick"):
		match mode:
			Modes.EQUIP:
				for container in containers:
					if container.get_global_rect().has_point(get_global_mouse_position()):
						pickup_item()
			Modes.PLACE:
				for container in containers:
					if container.get_global_rect().has_point(get_global_mouse_position()):
						place_item()
			Modes.UNLOCK:
				for container in containers:
					if container.get_global_rect().has_point(get_global_mouse_position()):
						toggle_locked()
	elif Input.is_action_just_pressed("mouse_rightclick"):
		match mode:
			Modes.PLACE:
				drop_item()
	pass

func create_slot(container):
	var new_slot = slot_scene.instantiate()
	new_slot.slot_ID = grid_array.size()
	container.add_child(new_slot)
	grid_array.push_back(new_slot)
	new_slot.slot_entered.connect(_on_slot_mouse_entered)
	new_slot.slot_exited.connect(_on_slot_mouse_exited)

func _on_slot_mouse_entered(a_Slot):
	icon_anchor = Vector2(10000, 10000)
	current_slot = a_Slot
	if item_held:
		check_slot_availability(current_slot)
		set_grids.call_deferred(current_slot)
	if mode == Modes.UNLOCK:
		check_lock_availability(current_slot)
		set_lock_grids.call_deferred(current_slot)
	pass
	
func _on_slot_mouse_exited():
	if mode == Modes.UNLOCK:
		current_slot.set_color(current_slot.States.TAKEN)
		for grid in grid_array:
			if not default_unlocks.has(grid.slot_ID):
				grid.set_color(grid.States.DEFAULT)
	else:
		clear_grid()
	pass

func check_lock_availability(a_Slot):
	if not a_Slot.locked and default_unlocks.has(a_Slot.slot_ID):
		can_lock = false
		return
	if a_Slot.installed_item:
		can_lock = false
		return
	if a_Slot.locked and not stats.unlocks_remaining():
		can_lock = false
		return
	can_lock = true

func check_slot_availability(a_Slot):
	var column_count = a_Slot.get_parent().columns
	for grid in item_held.item_grids:
		var grid_to_check = a_Slot.slot_ID + grid[0] + grid[1] * column_count
		var line_switch_check = a_Slot.slot_ID % column_count + grid[0]
		if line_switch_check < 0 or line_switch_check >= column_count:
			can_place = false
			return
		if grid_to_check < 0 or grid_to_check >= grid_array.size():
			can_place = false
			return
		if grid_array[grid_to_check].state == grid_array[grid_to_check].States.TAKEN or grid_array[grid_to_check].locked:
			can_place = false
			return
		if grid_array[grid_to_check].get_parent() != current_slot.get_parent():
			can_place = false
			return
		if item_held.item_data["section"] != "any" and !grid_array[grid_to_check].get_parent().get_name().ends_with(item_held.item_data["section"].capitalize() + "Container"):
			can_place = false
			return
		can_place = true

func set_lock_grids(a_Slot):
	if can_lock:
		grid_array[a_Slot.slot_ID].set_color(grid_array[a_Slot.slot_ID].States.FREE)
	else: 
		grid_array[a_Slot.slot_ID].set_color(grid_array[a_Slot.slot_ID].States.TAKEN)

func set_grids(a_Slot):
	var column_count = a_Slot.get_parent().columns
	for grid in item_held.item_grids:
		var grid_to_check = a_Slot.slot_ID + grid[0] + grid[1] * column_count
		var line_switch_check = a_Slot.slot_ID % column_count + grid[0]
		if line_switch_check < 0 or line_switch_check >= column_count:
			continue
		if grid_to_check < 0 or grid_to_check >= grid_array.size():
			continue
		if grid_array[grid_to_check].get_parent() != current_slot.get_parent():
			continue
		if can_place:
			grid_array[grid_to_check].set_color(grid_array[grid_to_check].States.FREE)
			
			if grid[1] < icon_anchor.x: icon_anchor.x = grid[1]
			if grid[0] < icon_anchor.y: icon_anchor.y = grid[0]
		else:
			grid_array[grid_to_check].set_color(grid_array[grid_to_check].States.TAKEN)

func clear_grid():
	for grid in grid_array:
		grid.set_color(grid.States.DEFAULT)

func place_item():
	if not can_place or not current_slot:
		return
	
	var column_count = current_slot.get_parent().columns
	var calculated_grid_id = current_slot.slot_ID + icon_anchor.x * column_count + icon_anchor.y
	if calculated_grid_id >= grid_array.size():
		return
	
	item_held.get_parent().remove_child(item_held)
	current_slot.get_parent().add_child(item_held)
	item_held.global_position = get_global_mouse_position()
	
	item_held.snap_to(grid_array[calculated_grid_id].global_position)
	
	item_held.grid_anchor = current_slot
	for grid in item_held.item_grids:
		var grid_to_check = current_slot.slot_ID + grid[0] + grid[1] * column_count
		grid_array[grid_to_check].state = grid_array[grid_to_check].States.TAKEN
		grid_array[grid_to_check].installed_item = item_held
	
	emit_signal("item_installed", item_held)
	
	item_held = null
	mode = Modes.EQUIP
	clear_grid()

func pickup_item():
	if not current_slot or not current_slot.installed_item:
		return
	
	var column_count = current_slot.get_parent().columns
	item_held = current_slot.installed_item
	item_held.selected = true
	
	for grid in item_held.item_grids:
		var grid_to_check = item_held.grid_anchor.slot_ID + grid[0] + grid[1] * column_count
		grid_array[grid_to_check].state = grid_array[grid_to_check].States.FREE
		grid_array[grid_to_check].installed_item = null
	
	check_slot_availability(current_slot)
	set_grids.call_deferred(current_slot)
	
	emit_signal("item_removed", item_held)
	
	mode = Modes.PLACE

func drop_item():
	item_held.queue_free()
	item_held = null
	mode = Modes.EQUIP

func toggle_locked():
	if not current_slot or not can_lock:
		return
	
	if current_slot.locked:
		current_slot.unlock()
		emit_signal("incrememnt_lock_tally", 1)
	else:
		if !current_slot.installed_item:
			current_slot.lock()
			emit_signal("incrememnt_lock_tally", -1)
	
	check_lock_availability(current_slot)
	set_lock_grids.call_deferred(current_slot)

func _on_frame_chooser_load_frame(a_Frame):
	emit_signal("set_gear_ability", a_Frame)
	default_unlocks = PackedInt32Array(a_Frame["default_unlocks"])
	
	for grid in grid_array:
		grid.lock()
	for index in a_Frame["default_unlocks"]:
		grid_array[index].unlock()

func _on_unlock_toggle_button_down():
	if item_held:
		drop_item()
	
	if mode == Modes.UNLOCK:
		clear_grid()
		mode = Modes.EQUIP
	else:
		mode = Modes.UNLOCK
		for grid in grid_array:
			if default_unlocks.has(grid.slot_ID):
				grid.set_color(grid.States.TAKEN)

func on_item_inventory_spawn_item(a_Item_ID):
	if item_held:
		return
	var new_item = item_scene.instantiate()
	add_child(new_item)
	new_item.load_item(a_Item_ID)
	new_item.selected = true
	item_held = new_item
	mode = Modes.PLACE

func install_item(a_Item_ID, a_Index):
	var new_item = item_scene.instantiate()
	grid_array[a_Index].get_parent().add_child(new_item)
	new_item.load_item(a_Item_ID)
	
	for grid in new_item.item_grids:
		var grid_to_check = a_Index + grid[0] + grid[1] * grid_array[a_Index].get_parent().columns
		grid_array[a_Index].state = grid_array[grid_to_check].States.TAKEN
		grid_array[a_Index].installed_item = new_item
	
	new_item.snap_to(grid_array[a_Index].global_position)
	new_item.grid_anchor = grid_array[a_Index]
	emit_signal("item_installed", new_item)

func _on_button_button_down():
	var image = get_viewport().get_texture().get_image()
	var _time = Time.get_datetime_string_from_system()
	var filename = "user://Screenshot.png"
	
	image.save_png(filename)
	
	var path
	if OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("user://")
	else:
		path = OS.get_executable_path().get_base_dir().path_join("user://")
	OS.shell_show_in_file_manager(path, true)
