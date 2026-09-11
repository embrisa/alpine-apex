extends RefCounted
## Completed-tick, read-only view of the physical rider. A switch pose never
## enters COM, inertia, load transfer, friction, or collision severity.
const Body = preload("res://scripts/core/rider_body.gd")
var scratch = Body.new()
var frame = Transform3D.IDENTITY
var previous_frame = Transform3D.IDENTITY
var joints: Dictionary = {}
var previous_joints: Dictionary = {}
var rotations: Dictionary = {}
var previous_rotations: Dictionary = {}
var positions: Array[Vector3] = []
var previous_positions: Array[Vector3] = []
var orientations: Array[Basis] = []
var previous_orientations: Array[Basis] = []
var initialized = false
class PoseInput extends RefCounted:
	var effective_tuck = 0.0
	var edge_angle = 0.0
	var grounded = true
	var landing_force = 0.0
	var acceleration = 0.0
	var position = Vector3.ZERO
	var frame = Basis.IDENTITY
	var skis: Array = []
	func support_basis() -> Basis: return frame
var input = PoseInput.new()

func capture(sim, collapse: bool = false) -> void:
	previous_frame = frame
	previous_joints = joints
	previous_rotations = rotations
	previous_positions = positions
	previous_orientations = orientations
	var reverse: bool = sim.facing_backward
	var turn = Basis(Vector3.UP,PI) if reverse else Basis.IDENTITY
	frame = Transform3D(sim.body.pose_frame.basis*turn,sim.body.pose_frame.origin)
	positions = []
	orientations = []
	input.skis = []
	for i in range(2):
		var ski = sim.skis[1-i if reverse else i]
		positions.append(ski.position)
		orientations.append(ski.orientation*turn)
		input.skis.append({"position":positions[i],"orientation":orientations[i]})
	if reverse:
		input.position = sim.position
		input.frame = frame.basis
		input.effective_tuck = sim.effective_tuck
		input.edge_angle = -sim.edge_angle
		input.grounded = sim.grounded
		input.landing_force = sim.landing_force
		input.acceleration = sim.acceleration
		scratch.roll = -sim.body.roll
		scratch.pitch = -sim.body.pitch
		scratch.pelvis_height = sim.body.pelvis_height
		scratch.recovery = sim.body.recovery
		scratch.hands = sim.body.hands.duplicate()
		scratch._pose(input,0.0)
		joints = scratch.joints.duplicate()
		rotations = scratch.rotations.duplicate()
	else:
		joints = sim.body.joints.duplicate()
		rotations = sim.body.rotations.duplicate()
	if collapse or not initialized: hold()
	initialized = true

func hold() -> void:
	previous_frame = frame
	previous_joints = joints
	previous_rotations = rotations
	previous_positions = positions
	previous_orientations = orientations
