class_name CoralPillarPair
extends Node2D

@export var speed: float = 240.0

# When set (>= 0), this pair only eliminates fish swimming near this lane.
# Prevents one player's pillars from killing the other player's fish.
var lane_center_x: float = -1.0
const LANE_HALF_WIDTH: float = 320.0

@onready var top_pillar: Area2D = $TopPillar
@onready var bottom_pillar: Area2D = $BottomPillar

var pending_gap_center: float = 540.0
var pending_gap_size: float = 240.0

func _ready() -> void:
	if top_pillar:
		top_pillar.body_entered.connect(_on_body_entered)
	if bottom_pillar:
		bottom_pillar.body_entered.connect(_on_body_entered)
	_apply_gap()

func _physics_process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -150.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is FishPlayer:
		# Lane restriction: ignore fish that are not in this pair's lane
		if lane_center_x >= 0.0 and absf(body.global_position.x - lane_center_x) > LANE_HALF_WIDTH:
			return
		body.die("Crashed into a sharp coral column!")

func randomize_gap(gap_center_y: float = 540.0, gap_size: float = 240.0) -> void:
	pending_gap_center = gap_center_y
	pending_gap_size = gap_size
	if is_node_ready():
		_apply_gap()

func _apply_gap() -> void:
	if top_pillar and bottom_pillar:
		top_pillar.position.y = pending_gap_center - (pending_gap_size / 2.0)
		bottom_pillar.position.y = pending_gap_center + (pending_gap_size / 2.0)
