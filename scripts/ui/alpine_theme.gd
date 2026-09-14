extends RefCounted
## One presentation theme, shared by all UI roots and their native popup controls.
const AngularBox = preload("res://scripts/ui/angular_style_box.gd")
const Art = preload("res://scripts/ui/alpine_art.gd")
const ICE = Color("007fa7")
const WHITE = Color("173247")
const MUTED = Color("506778")
const INK = Color("102832")
const PANEL = Color(0.956,0.980,1.0,0.95)
const FIELD = Color("e4eff6")
const HOVER = Color("c7effa")
const EDGE = Color("9ab9cc")
const DISABLED = Color("748795")
const SUCCESS = Color("18794e")
const WARNING = Color("a35408")
const DANGER = Color("bf3044")
const HUD_SUCCESS = Color("76f2b3")
const HUD_WARNING = Color("ffd072")
const HUD_DANGER = Color("ff8193")
const HUD_ACCENT = Color("78e6ff")
const PANEL_CUT = Vector2(24,12)
const CONTROL_CUT = Vector2(12,6)
static var shared: Theme
static var styles: Dictionary = {}
static var icons: Dictionary = {}

static func box(bg: Color, border: Color = Color.TRANSPARENT, padding: float = 14.0, corner: Vector2 = CONTROL_CUT, stroke: float = 1.0, marker: Color = Color.TRANSPARENT) -> StyleBox:
	var key = [bg,border,padding,corner,stroke,marker]
	if styles.has(key): return styles[key]
	var style = AngularBox.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width = stroke
	style.cut = corner
	style.marker_color = marker
	style.set_content_margin_all(padding)
	styles[key] = style
	return style

static func focus(padding: float = 14.0, on_light: bool = false) -> StyleBox:
	return box(Color.TRANSPARENT,INK if on_light else ICE,padding,CONTROL_CUT,2.0)

static func create() -> Theme:
	if shared: return shared
	var theme = Theme.new()
	theme.default_font = Art.interface_font()
	theme.default_font_size = 16
	for type in ["Button","OptionButton","ColorPickerButton","MenuButton"]:
		button_styles(theme,type,false,4 if type=="ColorPickerButton" else 14)
	for state in ["normal","hover","pressed","disabled"]:
		theme.set_stylebox(state+"_mirrored","OptionButton",theme.get_stylebox(state,"OptionButton"))
	theme.set_type_variation("AlpinePrimary","Button")
	button_styles(theme,"AlpinePrimary",true)
	theme.set_type_variation("AlpineTextAction","Button")
	button_styles(theme,"AlpineTextAction",false)
	for state in ["normal","disabled"]: theme.set_stylebox(state,"AlpineTextAction",box(Color.TRANSPARENT,Color.TRANSPARENT,12))
	for state in ["hover","pressed","hover_pressed"]: theme.set_stylebox(state,"AlpineTextAction",box(Color(1,1,1,.12),Color.TRANSPARENT,12))
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: theme.set_color(state,"AlpineTextAction",Color.TRANSPARENT)
	theme.set_color("font_disabled_color","AlpineTextAction",Color.TRANSPARENT)
	theme.set_constant("shadow_offset_y","AlpineTextAction",1)
	for type in ["CheckButton","CheckBox"]:
		button_styles(theme,type,false)
		for state in ["normal","pressed"]:
			theme.set_stylebox(state,type,box(Color.TRANSPARENT,Color.TRANSPARENT,8))
		for state in ["hover","hover_pressed"]:
			theme.set_stylebox(state,type,box(HOVER,EDGE,8))
		theme.set_stylebox("disabled",type,box(Color.TRANSPARENT,Color.TRANSPARENT,8))
		theme.set_stylebox("focus",type,focus(8))
		theme.set_color("font_pressed_color",type,WHITE)
		theme.set_color("font_hover_pressed_color",type,WHITE)
		theme.set_constant("h_separation",type,12)
		for checked in [false,true]:
			for disabled in [false,true]:
				var name = ("checked" if checked else "unchecked")+("_disabled" if disabled else "")
				var texture = icon("switch" if type=="CheckButton" else "check",DISABLED if disabled else ICE,checked)
				theme.set_icon(name,type,texture)
				if type=="CheckButton": theme.set_icon(name+"_mirrored",type,texture)
		for name in ["radio_checked","radio_unchecked","radio_checked_disabled","radio_unchecked_disabled"]:
			theme.set_icon(name,type,icon("check",DISABLED if "disabled" in name else ICE,not "unchecked" in name))
	for type in ["TabContainer","TabBar"]:
		theme.set_constant("tab_separation",type,8)
		theme.set_stylebox("panel",type,box(Color.TRANSPARENT,Color.TRANSPARENT,14,Vector2.ZERO))
		theme.set_stylebox("tabbar_background",type,StyleBoxEmpty.new())
		theme.set_stylebox("tab_selected",type,box(HOVER,EDGE,12,CONTROL_CUT,1,ICE))
		theme.set_stylebox("tab_unselected",type,box(FIELD,Color.TRANSPARENT,12))
		theme.set_stylebox("tab_hovered",type,box(HOVER,ICE,12))
		theme.set_stylebox("tab_disabled",type,box(FIELD,Color.TRANSPARENT,12))
		theme.set_stylebox("tab_focus",type,focus(12))
		theme.set_color("font_selected_color",type,ICE)
		theme.set_color("font_unselected_color",type,MUTED)
		theme.set_color("font_hovered_color",type,WHITE)
		theme.set_color("font_disabled_color",type,DISABLED)
		theme.set_font_size("font_size",type,15)
		for name in ["increment","decrement","increment_highlight","decrement_highlight"]:
			theme.set_icon(name,type,icon("right" if name.begins_with("increment") else "left",ICE))
	for type in ["LineEdit","TextEdit","CodeEdit"]:
		theme.set_stylebox("normal",type,box(FIELD,EDGE,10))
		theme.set_stylebox("read_only",type,box(FIELD,Color("bbcbd6"),10))
		theme.set_stylebox("focus",type,focus(10))
		theme.set_color("font_color",type,WHITE)
		theme.set_color("font_placeholder_color",type,MUTED)
		theme.set_color("font_uneditable_color" if type=="LineEdit" else "font_readonly_color",type,DISABLED)
		theme.set_color("caret_color",type,ICE)
		theme.set_color("selection_color",type,Color("b2e8f7"))
		theme.set_color("font_selected_color",type,WHITE)
		theme.set_icon("clear",type,icon("close",MUTED))
	for type in ["Panel","PanelContainer","PopupPanel","PopupMenu","TooltipPanel","AcceptDialog","Window"]:
		theme.set_stylebox("panel",type,box(PANEL,EDGE,14,PANEL_CUT))
	var window_border = box(PANEL,EDGE,8,PANEL_CUT).duplicate()
	window_border.expand_top = ThemeDB.get_default_theme().get_constant("title_height","Window")
	theme.set_stylebox("embedded_border","Window",window_border)
	theme.set_stylebox("embedded_unfocused_border","Window",window_border)
	theme.set_color("title_color","Window",WHITE)
	theme.set_icon("close","Window",icon("close",MUTED))
	theme.set_icon("close_pressed","Window",icon("close",WHITE))
	theme.set_stylebox("hover","PopupMenu",box(HOVER,Color.TRANSPARENT,6,Vector2(8,4)))
	theme.set_stylebox("separator","PopupMenu",box(EDGE,Color.TRANSPARENT,1,Vector2.ZERO))
	theme.set_constant("v_separation","PopupMenu",12)
	for type in ["PopupMenu","ItemList","Tree","Label","TooltipLabel"]:
		theme.set_color("font_color",type,WHITE)
		theme.set_color("font_hover_color",type,WHITE)
		theme.set_color("font_hovered_color",type,WHITE)
		theme.set_color("font_hovered_selected_color",type,WHITE)
		theme.set_color("font_selected_color",type,WHITE)
		theme.set_color("font_disabled_color",type,DISABLED)
	for type in ["ItemList","Tree"]:
		theme.set_stylebox("panel",type,box(FIELD,EDGE,10))
		theme.set_stylebox("focus",type,focus(10))
		for name in ["selected","selected_focus","cursor","cursor_unfocused","hovered","hovered_dimmed","hovered_selected","hovered_selected_focus"]:
			theme.set_stylebox(name,type,box(HOVER,ICE if "focus" in name else Color.TRANSPARENT,2,Vector2(8,4)))
	for name in ["checked","radio_checked","unchecked","radio_unchecked","checked_disabled","radio_checked_disabled","unchecked_disabled","radio_unchecked_disabled"]:
		for type in ["PopupMenu","Tree"]:
			theme.set_icon(name,type,icon("check",DISABLED if "disabled" in name else ICE,not "unchecked" in name))
	for name in ["arrow","select_arrow","scroll_hint"]:
		theme.set_icon(name,"Tree",icon("down",MUTED))
	theme.set_icon("arrow_collapsed","Tree",icon("right",MUTED))
	theme.set_icon("arrow_collapsed_mirrored","Tree",icon("left",MUTED))
	for name in ["button_hover","button_pressed","title_button_normal","title_button_pressed","title_button_hover","custom_button","custom_button_pressed","custom_button_hover"]:
		theme.set_stylebox(name,"Tree",box(HOVER if "hover" in name or "pressed" in name else FIELD,EDGE,4,Vector2(8,4)))
	theme.set_icon("submenu","PopupMenu",icon("right",ICE))
	theme.set_icon("submenu_mirrored","PopupMenu",icon("left",ICE))
	theme.set_icon("arrow","OptionButton",icon("down",ICE))
	theme.set_constant("arrow_margin","OptionButton",14)
	for type in ["HSlider","VSlider"]:
		var rail = box(Color("b7cfdd"),Color.TRANSPARENT,2,Vector2(4,2))
		theme.set_stylebox("slider",type,rail)
		theme.set_stylebox("grabber_area",type,box(ICE,Color.TRANSPARENT,2,Vector2(4,2)))
		theme.set_stylebox("grabber_area_highlight",type,box(WHITE,Color.TRANSPARENT,2,Vector2(4,2)))
		theme.set_icon("grabber",type,icon("handle",ICE))
		theme.set_icon("grabber_highlight",type,icon("handle",WHITE))
		theme.set_icon("grabber_disabled",type,icon("handle",DISABLED))
		theme.set_icon("tick",type,icon("tick",MUTED))
	for type in ["HScrollBar","VScrollBar"]:
		theme.set_stylebox("scroll",type,box(FIELD,Color.TRANSPARENT,5,Vector2(4,2)))
		theme.set_stylebox("scroll_focus",type,box(FIELD,ICE,5,Vector2(4,2)))
		for name in ["grabber","grabber_highlight","grabber_pressed"]:
			theme.set_stylebox(name,type,box(EDGE if name=="grabber" else ICE,Color.TRANSPARENT,5,Vector2(4,2)))
		for name in ["increment","decrement","increment_highlight","decrement_highlight","increment_pressed","decrement_pressed"]:
			var forward = name.begins_with("increment")
			theme.set_icon(name,type,icon(("down" if forward else "up") if type=="VScrollBar" else ("right" if forward else "left"),MUTED))
	theme.set_stylebox("background","ProgressBar",box(Color("b7cfdd"),Color.TRANSPARENT,0,Vector2(6,3)))
	theme.set_stylebox("fill","ProgressBar",box(ICE,Color.TRANSPARENT,0,Vector2(6,3)))
	for type in ["HSeparator","VSeparator"]:
		theme.set_stylebox("separator",type,box(EDGE,Color.TRANSPARENT,1,Vector2.ZERO))
	for name in ["up","down","up_hover","down_hover","up_pressed","down_pressed","up_disabled","down_disabled"]:
		theme.set_icon(name,"SpinBox",icon("up" if name.begins_with("up") else "down",DISABLED if "disabled" in name else ICE))
	theme.set_icon("updown","SpinBox",icon("updown",ICE))
	for direction in ["up","down"]:
		for state in ["","_hovered","_pressed","_disabled"]:
			theme.set_stylebox(direction+"_background"+state,"SpinBox",box(HOVER if state in ["_hovered","_pressed"] else FIELD,Color.TRANSPARENT,2,Vector2(4,2)))
	for name in ["field_and_buttons_separator","up_down_buttons_separator"]:
		theme.set_stylebox(name,"SpinBox",box(EDGE,Color.TRANSPARENT,1,Vector2.ZERO))
	for name in ["sample_focus","picker_focus_rectangle"]:
		theme.set_stylebox(name,"ColorPicker",focus(2))
	theme.set_icon("folded_arrow","ColorPicker",icon("right",ICE))
	theme.set_icon("expanded_arrow","ColorPicker",icon("down",ICE))
	for name in ["back_folder","forward_folder","parent_folder","favorite_up","favorite_down"]:
		var direction = {"back_folder":"left","forward_folder":"right","parent_folder":"up","favorite_up":"up","favorite_down":"down"}[name]
		theme.set_icon(name,"FileDialog",icon(direction,ICE))
	theme.set_color("folder_icon_color","FileDialog",ICE)
	theme.set_color("file_icon_color","FileDialog",MUTED)
	shared = theme
	return shared

static func button_styles(theme: Theme, type: String, primary: bool, padding: float = 14.0) -> void:
	theme.set_stylebox("normal",type,box(Color("60dafa") if primary else FIELD,ICE if primary else EDGE,padding))
	theme.set_stylebox("hover",type,box(Color("a1edff") if primary else HOVER,ICE,padding,CONTROL_CUT,2))
	theme.set_stylebox("pressed",type,box(Color("47c9eb") if primary else Color("b0e4f4"),ICE,padding,CONTROL_CUT,2,ICE))
	theme.set_stylebox("hover_pressed",type,theme.get_stylebox("pressed",type))
	theme.set_stylebox("disabled",type,box(Color("e2e8ee"),Color("c7d3dd"),padding))
	theme.set_stylebox("focus",type,box(Color.TRANSPARENT,ICE,padding,CONTROL_CUT,3,ICE))
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:
		theme.set_color(state,type,INK)
	theme.set_color("font_disabled_color",type,DISABLED)
	theme.set_color("icon_disabled_color",type,DISABLED)
	theme.set_constant("h_separation",type,12)

static func icon(kind: String, tint: Color, checked: bool = false) -> Texture2D:
	var key = [kind,tint,checked]
	if icons.has(key): return icons[key]
	var dimensions = Vector2i(16,16)
	var color = "#"+tint.to_html(false)
	var path = ""
	match kind:
		"down": path = '<path d="M3 5 L8 10 L13 5"/>'
		"up": path = '<path d="M3 10 L8 5 L13 10"/>'
		"right": path = '<path d="M5 3 L10 8 L5 13"/>'
		"left": path = '<path d="M10 3 L5 8 L10 13"/>'
		"close": path = '<path d="M4 4 L12 12 M12 4 L4 12"/>'
		"updown": path = '<path d="M4 6 L8 2 L12 6 M4 10 L8 14 L12 10"/>'
		"tick": path = '<path d="M8 5 V11"/>'
		"chevrons":
			dimensions = Vector2i(24,16)
			path = '<path d="M3 3 L10 8 L3 13 M12 3 L19 8 L12 13"/>'
		"handle":
			dimensions = Vector2i(18,22)
			path = '<path fill="%s" d="M7 2 H16 V16 L10 20 H2 V6 Z"/><path stroke="#102832" d="M8 7 V15 M11 7 V15"/>' % color
		"switch":
			dimensions = Vector2i(44,24)
			var x = 24 if checked else 4
			path = '<path fill="#e4eff6" d="M9 3 H42 V17 L35 21 H2 V7 Z"/><path fill="%s" stroke="none" d="M%d 6 H%d V15 L%d 18 H%d V9 Z"/>' % [color,x+5,x+16,x+11,x]
		"check":
			dimensions = Vector2i(22,22)
			path = '<path fill="#e4eff6" d="M8 2 H20 V16 L14 20 H2 V6 Z"/>'
			if checked: path += '<path d="M6 10 L10 14 L16 7"/>'
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><g fill="none" stroke="%s" stroke-width="1.5" stroke-linejoin="miter">%s</g></svg>' % [dimensions.x,dimensions.y,dimensions.x,dimensions.y,color,path]
	var image = Image.new()
	image.load_svg_from_string(svg,4.0)
	var texture = ImageTexture.create_from_image(image)
	texture.set_size_override(dimensions)
	icons[key] = texture
	return texture
