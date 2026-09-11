extends Node
## Controller text entry for ordinary player fields, including popup filename fields.
var hud
var dialog: ConfirmationDialog
var field: LineEdit
var target: Control
var key_grid: GridContainer
var shifted = false
var symbols = false
const LETTERS = "qwertyuiopasdfghjklzxcvbnm"
const SYMBOLS = "1234567890-_.:/+@#%&=!?()[]"

func setup(owner_hud) -> void:
	hud = owner_hud
	dialog = ConfirmationDialog.new()
	dialog.title = "Enter text"
	dialog.theme = hud.root.theme
	dialog.ok_button_text = "Apply"
	dialog.cancel_button_text = "Cancel"
	dialog.min_size = Vector2i(700,440)
	hud.root.add_child(dialog)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	dialog.add_child(column)
	field = LineEdit.new()
	field.custom_minimum_size.y = 46
	column.add_child(field)
	key_grid = GridContainer.new()
	key_grid.columns = 10
	column.add_child(key_grid)
	for i in LETTERS.length():
		var key = hud._button(LETTERS[i])
		key.custom_minimum_size = Vector2(55,42)
		key.alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.pressed.connect(func(): field.insert_text_at_caret(key.text))
		key_grid.add_child(key)
	var actions = HFlowContainer.new()
	column.add_child(actions)
	for label in ["Space","Delete","Shift","123 / ABC","←","→","Paste"]:
		var button = hud._button(label)
		actions.add_child(button)
		button.pressed.connect(func():
			match label:
				"Space": field.insert_text_at_caret(" ")
				"Delete":
					var caret = field.caret_column
					if caret>0: field.delete_text(caret-1,caret)
				"Shift": shifted = not shifted; _keys()
				"123 / ABC": symbols = not symbols; _keys()
				"←": field.caret_column = maxi(0,field.caret_column-1)
				"→": field.caret_column = mini(field.text.length(),field.caret_column+1)
				"Paste": field.insert_text_at_caret(DisplayServer.clipboard_get())
		)
	dialog.confirmed.connect(apply)
	dialog.canceled.connect(_return_focus)

func _keys() -> void:
	var chars = SYMBOLS if symbols else LETTERS.to_upper() if shifted else LETTERS
	for i in key_grid.get_child_count():
		var button = key_grid.get_child(i)
		button.text = chars[i] if i<chars.length() else " "

func open(control: Control) -> void:
	if control==field: return
	target = control
	field.text = target.text
	field.max_length = target.max_length if target is LineEdit else 65536
	field.caret_column = field.text.length()
	# The text entry dialog is a transient child of the active native popup.
	var parent = target.get_window()
	if dialog.get_parent()!=parent: dialog.reparent(parent)
	dialog.popup_centered(Vector2i(780,460))
	key_grid.get_child(0).grab_focus.call_deferred()

func apply() -> void:
	if is_instance_valid(target):
		target.text = field.text
		if target is LineEdit: target.text_changed.emit(target.text)
		elif target is TextEdit: target.text_changed.emit()
	_return_focus()

func _return_focus() -> void:
	if is_instance_valid(target) and target.is_visible_in_tree(): target.grab_focus.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(dialog): dialog.queue_free()
