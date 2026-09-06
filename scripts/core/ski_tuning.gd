class_name SkiTuning
extends Resource
## SI units: metres, seconds, radians, acceleration in m/s². No speed cap.
@export_group("Gravity and resistance")
@export_range(0.3, 2.0) var gravity_multiplier: float = 1.0
@export_range(0.001, 0.15) var ski_friction: float = 0.022
@export_range(0.0, 2.0) var snow_resistance: float = 0.08
# Additional passive ploughing through the surface's loose layer (1/m).
@export_range(0.0, 8.0) var snow_ploughing: float = 2.8
# Quadratic drag coefficient in 1/m. Racing speed needs a sustained steep pitch.
@export_range(0.0001, 0.02) var aerodynamic_drag: float = 0.0058
@export_range(0.1, 1.0) var tuck_drag_ratio: float = 0.43
@export var tuck_response: float = 3.5
@export_range(0.1, 1.0) var tuck_grip_ratio: float = 0.76

@export_group("Edges and steering")
@export_range(0.2, 4.0) var edge_grip: float = 1.6
@export_range(1.0, 25.0) var carving_strength: float = 9.0
@export_range(0.0, 3.0) var skidding_friction: float = 0.6
@export_range(20.0, 80.0) var maximum_edge_angle: float = 62.0
@export_range(0.3, 3.0) var steering_sensitivity: float = 1.35
@export var high_speed_steering_reduction: float = 0.032
@export var edge_response: float = 14.0
@export var braking_deceleration: float = 8.2

@export_group("Contact and impacts")
@export var jump_impulse: float = 3.2
@export var landing_tolerance: float = 10.5
@export var landing_absorption: float = 0.25
@export var balance_recovery: float = 0.65
@export var lateral_recovery_distance: float = 5.0
@export var minimum_load: float = 0.0 # m/s²; unilateral support cannot be tensile

@export_group("Articulated rider and separate skis")
@export var rider_mass: float = 80.0 # kg, including equipment carried by the rider
@export var half_stance: float = 0.22 # m
@export var ski_length: float = 1.80 # m
@export var ski_width: float = 0.11 # m
@export var leg_extension: float = 0.28 # m of differential terrain reach
@export var balance_stiffness: float = 1500.0 # N m / rad
@export var balance_damping: float = 700.0 # N m s / rad
@export var balance_max_torque: float = 600.0 # N m
@export var maximum_body_lean: float = 0.85 # rad at low speed
# Blend into a deeper supported bank from 30 to 60 km/h. Existing pressure,
# torque and cuff-rate limits still control engagement and reversals.
@export var high_speed_body_lean: float = 0.98 # rad (56.1 degrees)

@export_group("Presentation")
@export var camera_response: float = 7.5
@export var base_fov: float = 72.0
@export var speed_fov: float = 15.0
@export var vibration_intensity: float = 0.5
@export var speed_thresholds: PackedFloat32Array = PackedFloat32Array([30, 60, 90, 120, 150, 165, 200])
