extends Node

## SceneLoader â€” Asynchronous scene loader & transition screen.
## Features:
##   â€¢ Animated progress bar with smooth interpolation
##   â€¢ Playful rotating status messages ("Feeding the fish, flopping the fins...")
##   â€¢ Fascinating real fish trivia facts at the bottom of the screen
##   â€¢ Smooth fade transitions to prevent jarring screen flashes

const BUBBLE_TEXTURE := preload("res://assets/generated/ui_bubble.png")

const FISH_FACTS : Array[String] = [
	"Flying fish have wing-like pectoral fins that let them glide over 600 feet across open ocean to escape predators!",
	"Channel catfish have taste buds all over their entire body that they can taste food just by touching it with their skin!",
	"Almost all fish sleep with their eyes wide open because they don't have eyelids (except for sharks)!",
	"Fish have been swimming on Earth for over 500 million years, long before dinosaurs ever walked the land!",
	"Mudskippers can walk on land using their pectoral fins and breathe air directly through their skin!",
	"Most fish only swim forward, but triggerfish can swim forwards, backwards, and upside down with ease!",
	"Archerfish shoot high-pressure water jets from their mouths to snipe insects off branches up to 5 feet away!",
	"Clownfish coat themselves in a special mucus shield so that stinging sea anemones don't hurt them!",
	"Sailfish are the fastest fish in the sea, clocking sprint speeds of up to 68 mph (110 km/h)!",
	"Pufferfish inflate their bodies with water or air, blowing up to three times their normal size to scare predators!",
	"Goldfish have a memory span of several monthsm completely busting the old 3-second memory myth!",
	"Electric eels can generate electrical shocks of up to 860 volts, enough power to stun a horse!",
	"Parrotfish secrete a cozy sleeping bag made of mucus every night to mask their scent from hungry moray eels!",
	"Deep-sea anglerfish carry a bioluminescent glowing lure in front of their mouths to attract curious prey in the dark!",
	"Coelacanths were thought to have gone extinct alongside the dinosaurs until a live one was found in 1938!",
	"Seahorses are the only animals in the world where the male carries and gives birth to the babies!",
	"The Greenland shark can live for over 400 years, making it the longest-living vertebrate known to science!",
	"Betta fish are labyrinth breathers, meaning they can gulp air from the surface of stagnant water to survive!"
]

const LOADING_STEPS : Array[String] = [
	"Feeding the fish...",
	"Flopping the fins...",
	"Scaling the gills...",
	"Untangling the seaweed...",
	"Calibrating bubble filters...",
	"Polishing the aquarium pebbles...",
	"Warming up tropical water...",
	"Counting pellet reserves...",
	"Teaching goldfish backflips...",
	"Checking salinity levels...",
	"Arranging sunken treasure...",
	"Readying the tanks..."
]

var _canvas_layer: CanvasLayer
var _root_control: Control
var _bg_rect: ColorRect
var _bubbles_container: Control
var _status_label: Label
var _progress_bar: ProgressBar
var _percent_label: Label
var _fact_label: Label
var _fish_icon: Sprite2D

var _target_path: String = ""
var _is_loading: bool = false
var _load_progress: float = 0.0
var _display_progress: float = 0.0
var _min_display_timer: float = 0.0
var _step_timer: float = 0.0
var _step_index: int = 0
const MIN_DISPLAY_TIME: float = 1.3

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_set_visible(false)

func _build_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 125
	add_child(_canvas_layer)

	_root_control = Control.new()
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_layer.add_child(_root_control)

	# Deep gradient ocean backdrop
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0.04, 0.12, 0.22, 1.0)
	_root_control.add_child(_bg_rect)

	# Floating bubbles
	_bubbles_container = Control.new()
	_bubbles_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubbles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_bubbles_container)
	if BUBBLE_TEXTURE:
		UIHelpers.spawn_bubbles(_bubbles_container, BUBBLE_TEXTURE, 16, Vector2(1920, 1080))

	# Center Content Container
	var center_box = VBoxContainer.new()
	center_box.anchor_left = 0.5
	center_box.anchor_right = 0.5
	center_box.anchor_top = 0.45
	center_box.anchor_bottom = 0.45
	center_box.offset_left = -380
	center_box.offset_right = 380
	center_box.offset_top = -140
	center_box.offset_bottom = 140
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 18)
	_root_control.add_child(center_box)

	# Fish Icon / Bobbing Visual
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(80, 70)
	center_box.add_child(icon_container)

	_fish_icon = Sprite2D.new()
	_fish_icon.texture = load("res://entities/fish/Fish_Sprite_Sheet_16.png")
	_fish_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fish_icon.hframes = 16
	_fish_icon.vframes = 24
	_fish_icon.frame = 0
	_fish_icon.scale = Vector2(3.5, 3.5)
	_fish_icon.position = Vector2(380, 35)
	_fish_icon.modulate = Color(0.3, 0.9, 1.0)
	icon_container.add_child(_fish_icon)

	# Playful loading text ("Feeding the fish, flopping the fins...")
	_status_label = Label.new()
	_status_label.text = "Feeding the fish..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 28)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	center_box.add_child(_status_label)

	# Progress Bar
	var bar_container = HBoxContainer.new()
	bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_container.add_theme_constant_override("separation", 14)
	center_box.add_child(bar_container)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(560, 24)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false

	# Style progress bar with glowing cyan filling
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.18, 0.32, 0.9)
	bg_sb.corner_radius_top_left = 12
	bg_sb.corner_radius_top_right = 12
	bg_sb.corner_radius_bottom_left = 12
	bg_sb.corner_radius_bottom_right = 12
	bg_sb.border_width_left = 2
	bg_sb.border_width_right = 2
	bg_sb.border_width_top = 2
	bg_sb.border_width_bottom = 2
	bg_sb.border_color = Color(0.2, 0.6, 0.9, 0.5)

	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.2, 0.85, 0.98, 1.0)
	fill_sb.corner_radius_top_left = 12
	fill_sb.corner_radius_top_right = 12
	fill_sb.corner_radius_bottom_left = 12
	fill_sb.corner_radius_bottom_right = 12

	_progress_bar.add_theme_stylebox_override("background", bg_sb)
	_progress_bar.add_theme_stylebox_override("fill", fill_sb)
	bar_container.add_child(_progress_bar)

	_percent_label = Label.new()
	_percent_label.text = "0%"
	_percent_label.custom_minimum_size = Vector2(55, 24)
	_percent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_percent_label.add_theme_font_size_override("font_size", 18)
	_percent_label.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
	bar_container.add_child(_percent_label)

	# Bottom Trivia Banner Panel
	var trivia_panel = PanelContainer.new()
	trivia_panel.anchor_left = 0.5
	trivia_panel.anchor_right = 0.5
	trivia_panel.anchor_top = 1.0
	trivia_panel.anchor_bottom = 1.0
	trivia_panel.offset_left = -500
	trivia_panel.offset_right = 500
	trivia_panel.offset_top = -180
	trivia_panel.offset_bottom = -50

	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.16, 0.28, 0.85)
	panel_sb.border_width_left = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_color = Color(0.3, 0.7, 0.95, 0.4)
	panel_sb.corner_radius_top_left = 16
	panel_sb.corner_radius_top_right = 16
	panel_sb.corner_radius_bottom_left = 16
	panel_sb.corner_radius_bottom_right = 16
	panel_sb.content_margin_left = 28
	panel_sb.content_margin_right = 28
	panel_sb.content_margin_top = 16
	panel_sb.content_margin_bottom = 16
	trivia_panel.add_theme_stylebox_override("panel", panel_sb)
	_root_control.add_child(trivia_panel)

	var trivia_vbox = VBoxContainer.new()
	trivia_vbox.add_theme_constant_override("separation", 6)
	trivia_panel.add_child(trivia_vbox)

	var header_lbl = Label.new()
	header_lbl.text = "DID YOU KNOW?"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 16)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	trivia_vbox.add_child(header_lbl)

	_fact_label = Label.new()
	_fact_label.text = FISH_FACTS[0]
	_fact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fact_label.add_theme_font_size_override("font_size", 18)
	_fact_label.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	trivia_vbox.add_child(_fact_label)

func change_scene(target_path: String) -> void:
	if _is_loading:
		return
	_target_path = target_path
	_is_loading = true
	_load_progress = 0.0
	_display_progress = 0.0
	_min_display_timer = MIN_DISPLAY_TIME
	_step_timer = 0.0
	_step_index = 0

	# Randomize fish trivia
	_fact_label.text = FISH_FACTS.pick_random()
	_status_label.text = LOADING_STEPS[0]
	_progress_bar.value = 0.0
	_percent_label.text = "0%"

	_set_visible(true)
	_root_control.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_root_control, "modulate:a", 1.0, 0.2)

	# Start background threaded loading
	var err = ResourceLoader.load_threaded_request(_target_path)
	if err != OK:
		# Fallback to direct scene switch
		push_warning("SceneLoader: Failed to load_threaded_request for " + _target_path)
		get_tree().change_scene_to_file(_target_path)
		_finish_loading()

func _process(delta: float) -> void:
	if not _is_loading:
		return

	# Rotate playful loading texts smoothly
	_step_timer += delta
	if _step_timer >= 0.38:
		_step_timer = 0.0
		_step_index = (_step_index + 1) % LOADING_STEPS.size()
		_status_label.text = LOADING_STEPS[_step_index]

	# Bob fish sprite
	if _fish_icon:
		var time = Time.get_ticks_msec() / 1000.0
		_fish_icon.position.y = 35.0 + sin(time * 5.0) * 8.0
		_fish_icon.frame = (int(time * 6.0) % 4)

	# Track threaded load progress
	var progress_arr: Array = []
	var status = ResourceLoader.load_threaded_get_status(_target_path, progress_arr)

	if progress_arr.size() > 0:
		_load_progress = progress_arr[0] * 100.0
	else:
		_load_progress = 100.0 if status == ResourceLoader.THREAD_LOAD_LOADED else 50.0

	# Smooth progress bar interpolation
	_display_progress = lerpf(_display_progress, _load_progress, delta * 6.0)
	_progress_bar.value = _display_progress
	_percent_label.text = "%d%%" % int(_display_progress)

	_min_display_timer -= delta

	# Once resource is ready AND minimum display time elapsed, finalize
	if status == ResourceLoader.THREAD_LOAD_LOADED and _min_display_timer <= 0.0:
		_display_progress = 100.0
		_progress_bar.value = 100.0
		_percent_label.text = "100%"

		var packed_scene = ResourceLoader.load_threaded_get(_target_path) as PackedScene
		if packed_scene:
			get_tree().change_scene_to_packed(packed_scene)
		else:
			get_tree().change_scene_to_file(_target_path)

		_finish_loading()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("SceneLoader: Resource loading failed for " + _target_path)
		get_tree().change_scene_to_file(_target_path)
		_finish_loading()

func _finish_loading() -> void:
	_is_loading = false
	var tw = create_tween()
	tw.tween_property(_root_control, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _set_visible(false))

func _set_visible(v: bool) -> void:
	_root_control.visible = v
	_canvas_layer.visible = v
