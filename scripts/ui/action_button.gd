extends Button
## A real native button with an independently rendered, device-aware bind badge.
const UITheme = preload("res://scripts/ui/alpine_theme.gd")
const Prompts = preload("res://scripts/ui/controller_prompts.gd")
var hud
var action: String = ""
var menu_back = false
var fixed_key = 0
var fixed_pad = -1
var prompt: String = ""
var primary_action = false
var text_action = false
var pulse_time = 0.0
var press_flash = 0.0
var refreshing = false
var badge_width = 0.0
var style_key = ""

func configure(owner, primary: bool = false) -> void:
	hud = owner
	primary_action = primary
	theme_type_variation = "AlpinePrimary" if primary else ""
	focus_entered.connect(refresh_prompt)
	focus_exited.connect(refresh_prompt)
	visibility_changed.connect(refresh_prompt)
	theme_changed.connect(refresh_prompt)
	pressed.connect(func(): press_flash = .22; set_process(true))

func _ready() -> void:
	add_to_group("alpine_action_buttons")
	refresh_prompt()

func bind_action(value: String) -> void:
	action = value
	refresh_prompt()

func set_text_action(value: bool) -> void:
	text_action = value
	add_theme_font_size_override("font_size",18 if value else 16)
	theme_type_variation = "AlpineTextAction" if value else "AlpinePrimary" if primary_action else ""
	focus_mode = Control.FOCUS_NONE if value else Control.FOCUS_ALL
	refresh_prompt()

func refresh_prompt() -> void:
	if refreshing or hud == null or not is_inside_tree(): return
	refreshing = true
	var family: String = hud.input_family
	prompt = Prompts.binding(action,family) if not action.is_empty() else ""
	if prompt == "Unbound": prompt = ""
	if menu_back: prompt = "Esc" if family=="keyboard" else Prompts.button(JOY_BUTTON_B,family)
	if fixed_key!=0:
		prompt = OS.get_keycode_string(fixed_key) if family=="keyboard" else Prompts.button(fixed_pad,family) if fixed_pad>=0 else ""
	if prompt.is_empty() and has_focus() and not text_action:
		prompt = "Enter" if family == "keyboard" else Prompts.button(JOY_BUTTON_A,family)
	var font = get_theme_font("font")
	badge_width = font.get_string_size(prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+18.0 if not prompt.is_empty() else 0.0
	# Reserve the confirm badge even when unfocused, so navigation never shifts rows.
	var reserved = badge_width if text_action else maxf(badge_width,52.0)
	var key = theme_type_variation+":"+str(reserved)
	if key!=style_key:
		style_key = key
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var style = UITheme.create().get_stylebox(state,theme_type_variation if not theme_type_variation.is_empty() else "Button").duplicate()
			style.content_margin_right = reserved+24.0
			add_theme_stylebox_override(state,style)
	refreshing = false
	set_process(is_visible_in_tree() and (primary_action or press_flash>0.0) and not hud.feedback.reduced_motion)
	queue_redraw()

func _process(dt: float) -> void:
	if not is_visible_in_tree(): set_process(false); return
	pulse_time += dt
	press_flash = maxf(0.0,press_flash-dt)
	queue_redraw()
	if not primary_action and press_flash<=0.0: set_process(false)

func _draw() -> void:
	if hud == null: return
	var reduced: bool = hud.feedback.reduced_motion
	if not text_action and not disabled and not reduced and (primary_action or press_flash>0.0):
		var alpha = .12+.14*(.5+.5*sin(pulse_time*TAU/2.8)) if primary_action else 0.0
		alpha = maxf(alpha,press_flash/.22*.65)
		var color = Color(UITheme.ICE,alpha)
		var points = UITheme.AngularBox.outline(Rect2(Vector2(2,2),size-Vector2(4,4)),UITheme.CONTROL_CUT)
		points.append(points[0])
		draw_polyline(points,color,2.0,true)
	if prompt.is_empty() and not text_action: return
	var rect = Rect2(Vector2(12.0 if text_action else size.x-badge_width-14.0,(size.y-26.0)*.5),Vector2(badge_width,26))
	if text_action:
		var action_font = get_theme_font("font")
		var font_size = 18
		var origin = Vector2(rect.end.x+10,(size.y-action_font.get_height(font_size))*.5+action_font.get_ascent(font_size))
		var color = Color("b2c4d0") if disabled else Color.WHITE
		var width = maxf(0,size.x-origin.x-10)
		draw_string(action_font,origin+Vector2(1,1),text,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,Color(.02,.055,.085,.85))
		draw_string(action_font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)
	if prompt.is_empty(): return
	var bg = Color("e3f1f7") if not text_action else Color("f4fbff")
	var fg = UITheme.DISABLED if disabled else UITheme.INK
	draw_style_box(UITheme.box(bg,UITheme.EDGE,0,Vector2(6,3)),rect)
	var font = get_theme_font("font")
	draw_string(font,rect.position+Vector2(9,(26-font.get_height(13))*.5+font.get_ascent(13)),prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,13,fg)
