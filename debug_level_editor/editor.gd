extends CanvasLayer
## Debug authoring tool for the same PackedScenes the game loads.

const Guides = preload("res://debug_level_editor/guides.gd")
const Backdrop = preload("res://backdrop.gd")
const DRAFT_DIR := "user://recoil_level_drafts"
const HISTORY_LIMIT := 40
const EDITABLE_SCRIPTS := {
	"block.gd": "Solid block / platform",
	"bouncy.gd": "Bounce surface",
	"checkpoint.gd": "Checkpoint / finish",
	"crumble.gd": "Crumble platform",
	"mouth.gd": "Mouth trap",
	"mover.gd": "Moving platform",
	"refill.gd": "Shell refill",
	"rising.gd": "Rising flood",
	"shooter.gd": "Turret",
	"spikes.gd": "Spike row",
}

var game
var _drafts: Dictionary = {}
var _palette: Array[Script] = []
var _level_index := -1
var _floor: Level
var _selected: Node2D
var _drag_before: PackedScene
var _drag_origin := Vector2.ZERO
var _drag_mouse := Vector2.ZERO
var _drag_trigger := 0.0
var _resize_drag := false
var _pan := false
var _last_click := Vector2(INF, INF)
var _last_click_time := 0
var _ui: Control
var _level_picker: OptionButton
var _canvas: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera2D
var _backdrop: Node2D
var _guides: Node2D
var _objects: ItemList
var _object_nodes: Array[Node2D] = []
var _properties: VBoxContainer
var _status: Label
var _undo: Button
var _redo: Button
var _duplicate: Button
var _delete: Button
var _palette_picker: OptionButton
var _overwrite: ConfirmationDialog


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = PanelContainer.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var layout := VBoxContainer.new()
	_ui.add_child(layout)
	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	_level_picker = OptionButton.new()
	toolbar.add_child(_level_picker)
	_level_picker.item_selected.connect(_open_level)
	_undo = _button(toolbar, "Undo", _history.bind(-1))
	_redo = _button(toolbar, "Redo", _history.bind(1))
	_button(toolbar, "Fit", _fit)
	var snap := CheckButton.new()
	snap.text = "Grid snap"
	toolbar.add_child(snap)
	snap.toggled.connect(func(on: bool) -> void:
		_guides.snap = on
		_guides.queue_redraw()
	)
	_button(toolbar, "Save Draft", _save.bind(false))
	if OS.has_feature("editor"):
		_button(toolbar, "Overwrite Level…", _confirm_overwrite)
	_button(toolbar, "Playtest", _playtest)
	_button(toolbar, "Close (F2)", _toggle)

	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	_canvas = SubViewportContainer.new()
	_canvas.stretch = true
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.gui_input.connect(_canvas_input)
	_canvas.resized.connect(func() -> void: _redraw())
	content.add_child(_canvas)
	_viewport = SubViewport.new()
	_viewport.world_2d = World2D.new()
	_viewport.gui_disable_input = true
	_canvas.add_child(_viewport)
	_camera = Camera2D.new()
	_viewport.add_child(_camera)
	_backdrop = Backdrop.new()
	_viewport.add_child(_backdrop)
	_guides = Guides.new()
	_guides.camera = _camera
	_guides.z_index = 100
	_viewport.add_child(_guides)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 285
	content.add_child(sidebar)
	var palette_row := HBoxContainer.new()
	sidebar.add_child(palette_row)
	_palette_picker = OptionButton.new()
	_palette_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_row.add_child(_palette_picker)
	_button(palette_row, "Add", _add_object)
	_objects = ItemList.new()
	_objects.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_objects.custom_minimum_size.y = 110
	_objects.item_selected.connect(func(index: int) -> void: _select(_object_nodes[index]))
	sidebar.add_child(_objects)
	var actions := HBoxContainer.new()
	sidebar.add_child(actions)
	_duplicate = _button(actions, "Duplicate", _duplicate_object)
	_delete = _button(actions, "Delete", _delete_object)
	var inspector := ScrollContainer.new()
	inspector.custom_minimum_size.y = 210
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(inspector)
	_properties = VBoxContainer.new()
	_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_child(_properties)

	_status = Label.new()
	layout.add_child(_status)
	_overwrite = ConfirmationDialog.new()
	_overwrite.title = "Overwrite the original level?"
	_overwrite.ok_button_text = "Overwrite Level"
	_overwrite.confirmed.connect(_save.bind(true))
	add_child(_overwrite)
	hide()


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		_toggle()
	elif visible and event.ctrl_pressed and event.keycode == KEY_S:
		get_viewport().set_input_as_handled()
		_save(false)


func _toggle() -> void:
	if visible:
		_finish_drag()
		hide()
		game.close_debug_editor()
		return
	if not game.open_debug_editor():
		return
	show()
	if _level_picker.item_count == 0:
		_catalog()
		_open_level(game.level_index if not game.tower_mode else game.current)


func _catalog() -> void:
	var used: Dictionary = {}
	for path: String in game.levels:
		var scene := load(path) as PackedScene
		var state := scene.get_state()
		var title := path.get_file().get_basename()
		for node_index in state.get_node_count():
			for property_index in state.get_node_property_count(node_index):
				var property := state.get_node_property_name(node_index, property_index)
				var value: Variant = state.get_node_property_value(node_index, property_index)
				if node_index == 0 and property == &"title":
					title = str(value)
				if property == &"script" and value is Script:
					used[value.resource_path.get_file()] = value
		_level_picker.add_item(title)
	for file: String in EDITABLE_SCRIPTS:
		if used.has(file):
			_palette.append(used[file])
			_palette_picker.add_item(EDITABLE_SCRIPTS[file])


func _draft_path(index: int) -> String:
	return DRAFT_DIR.path_join(game.levels[index].get_file())


func _open_level(index: int) -> void:
	_finish_drag()
	_level_index = index
	_level_picker.select(index)
	var message := ""
	if not _drafts.has(index):
		var scene: PackedScene
		var path := _draft_path(index)
		if FileAccess.file_exists(path):
			scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			if not _valid_scene(scene):
				scene = null
				message = "Couldn't open the saved draft. Loaded the original."
		if scene == null:
			scene = load(game.levels[index]) as PackedScene
		_drafts[index] = {"steps": [scene], "index": 0, "saved": scene}
	var draft: Dictionary = _drafts[index]
	_show_scene(draft.steps[draft.index])
	_fit.call_deferred()
	_update_status(message)


func _valid_scene(scene: PackedScene) -> bool:
	if scene == null or not scene.can_instantiate():
		return false
	var instance := scene.instantiate()
	var valid := instance is Level and instance.get_node_or_null("Start") is Marker2D
	instance.free()
	return valid


func _show_scene(scene: PackedScene, selected_path := NodePath()) -> void:
	if is_instance_valid(_floor):
		_viewport.remove_child(_floor)
		_floor.queue_free()
	_floor = scene.instantiate() as Level
	_floor.process_mode = Node.PROCESS_MODE_DISABLED
	_viewport.add_child(_floor)
	_backdrop.target_tint = _floor.backdrop_tint
	_guides.floor_node = _floor
	_selected = _floor.get_node_or_null(selected_path) as Node2D if not selected_path.is_empty() else null
	_refresh_objects()
	_select(_selected)


func _refresh_objects() -> void:
	_objects.clear()
	_object_nodes.clear()
	_objects.add_item("Level bounds")
	_object_nodes.append(_floor)
	for child in _floor.get_children():
		if child is Node2D:
			_objects.add_item(str(child.name))
			_object_nodes.append(child)


func _snapshot() -> PackedScene:
	var scene := PackedScene.new()
	if scene.pack(_floor) != OK:
		_update_status("Couldn't capture this level.")
		return null
	return scene


func _commit() -> void:
	var scene := _snapshot()
	if scene == null:
		return
	var draft: Dictionary = _drafts[_level_index]
	var steps: Array = draft.steps
	steps.resize(draft.index + 1)
	steps.append(scene)
	if steps.size() > HISTORY_LIMIT + 1:
		steps.pop_front()
	draft.index = steps.size() - 1
	_update_status()


func _history(direction: int) -> void:
	_finish_drag()
	var draft: Dictionary = _drafts[_level_index]
	var next: int = draft.index + direction
	if next < 0 or next >= draft.steps.size():
		return
	var path := _floor.get_path_to(_selected) if is_instance_valid(_selected) else NodePath()
	draft.index = next
	_show_scene(draft.steps[next], path)
	_update_status()


func _update_status(message := "") -> void:
	if _level_index < 0:
		return
	var draft: Dictionary = _drafts[_level_index]
	_undo.disabled = draft.index == 0
	_redo.disabled = draft.index + 1 == draft.steps.size()
	var state := "Unsaved changes" if draft.steps[draft.index] != draft.saved else "Draft ready"
	_status.text = message if not message.is_empty() else (
		"%s  ·  Drag to move or resize  ·  Middle-drag to pan  ·  Scroll to zoom  ·  Click again to cycle overlaps" % state)


func _confirm_overwrite() -> void:
	_finish_drag()
	_overwrite.dialog_text = "Replace %s in the project? Save Draft keeps a separate copy." % game.levels[_level_index].get_file()
	_overwrite.popup_centered()


func _save(overwrite: bool) -> void:
	_finish_drag()
	if overwrite and not OS.has_feature("editor"):
		return
	var scene := _snapshot()
	if scene == null:
		return
	var path: String = game.levels[_level_index] if overwrite else _draft_path(_level_index)
	var temporary := path.get_basename() + ".saving.tscn"
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error == OK:
		error = ResourceSaver.save(scene, temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
		_update_status("Save failed (%s). The previous file is still in place." % error_string(error))
		return
	if overwrite:
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	else:
		var draft: Dictionary = _drafts[_level_index]
		draft.saved = draft.steps[draft.index]
	_update_status("Saved %s" % path)


func _playtest() -> void:
	_finish_drag()
	var scene := _snapshot()
	if scene != null:
		hide()
		game.play_debug_draft(_level_index, scene)
