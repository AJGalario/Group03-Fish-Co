class_name CoopHUD
extends Control

## Clean, compact top bar HUD for Co-op levels.
## Visible and designer-editable directly in the Godot Editor.

signal restart_requested
signal levels_requested

@onready var title_label: Label = $TopBar/TitleVBox/TitleLabel
@onready var instruction_label: Label = $TopBar/TitleVBox/InstructionLabel
@onready var restart_button: Button = $TopBar/ButtonsRow/RestartButton
@onready var levels_button: Button = $TopBar/ButtonsRow/LevelsButton

func _ready() -> void:
	if restart_button:
		restart_button.pressed.connect(func(): restart_requested.emit())
	if levels_button:
		levels_button.pressed.connect(func(): levels_requested.emit())

func setup_level_info(num: int, title: String, instruction: String) -> void:
	if title_label:
		title_label.text = "LEVEL %d: %s" % [num, title.to_upper()]
	if instruction_label:
		instruction_label.text = instruction
