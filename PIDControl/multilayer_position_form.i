################################################################################
## Multi-Layer Position Form PID-Controlled Frontal Polymerization Printing
## Uses MultiLayerPIDControlDirect: output = Kp*e + Ki*integral(e) + Kd*de/dt
## Optimized gains: Kp=-10.0, Ki=-1.0, Kd=-0.5
##
## Insulative substrate case: No substrate modeled, no BC on bottom (adiabatic)
## Layer length: 20mm
##
## Layer Transition Logic:
##   1. When front reaches within transition_gap (1mm) of layer end
##   2. Nozzle moves up (vertical_delay = 1s)
##   3. Print at initial_velocity (10mm/s) for initial_nozzle_offset (6.2mm)
##   4. Start PID control for new layer
##
## Parameters:
##   - transition_gap = 0.001 m (1 mm)
##   - vertical_delay = 1 s
##   - initial_velocity = 0.01 m/s (10 mm/s)
##   - initial_nozzle_offset = 0.0062 m (6.2 mm) - from 0.8mm to 7mm
##   - target_distance = 0.007 m (7 mm)
##   - layer_height = 0.0016 m (1.6 mm)
##   - num_layers = 4
################################################################################

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    ymin = 0.0
    xmax = 0.02           # 20 mm length
    ymax = 0.0064         # 6.4 mm height (4 layers × 1.6 mm)
    nx = 120              # Same resolution as single layer
    ny = 48               # 12 elements per layer × 4 layers
  []
  # Initial ink region (Layer 1, first 1.6mm)
  [ink]
    type = SubdomainBoundingBoxGenerator
    input = 'gen'
    block_id = 1
    bottom_left = '0 0 0'
    top_right = '0.0016 0.0016 0'
  []
  # Air region (rest of domain, including upper layers)
  [air]
    type = SubdomainBoundingBoxGenerator
    input = 'ink'
    block_id = 0
    bottom_left = '0.0016 0 0'
    top_right = '0.02 0.0064 0'
  []
  # Pre-declare sideset for moving boundary
  add_sideset_names = 'ink_surface'
  add_sideset_ids = '4'
[]

[Problem]
  type = FEProblem
  solve = true
[]

[Variables]
  [Temperature]
    order = FIRST
    family = LAGRANGE
    initial_condition = 20
    block = '0 1'
  []
  [Cure]
    order = FIRST
    family = LAGRANGE
    initial_condition = 0.15
    block = '0 1'
  []
[]

[AuxVariables]
  [dist]
    # Distance from nozzle position
  []
  [bounds_dummy]
  []
  [layer_id]
    # Track which layer each element belongs to
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [compute_dist]
    type = ParsedAux
    variable = dist
    expression = 'sqrt((x-nozzle_x)^2 + (y-nozzle_y)^2)'
    functor_names = 'nozzle_x_value nozzle_y_value'
    functor_symbols = 'nozzle_x nozzle_y'
    use_xyzt = true
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
  [compute_layer_id]
    type = ParsedAux
    variable = layer_id
    expression = 'floor(y / 0.0016) + 1'
    use_xyzt = true
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
[]

[Bounds]
  [C_upper_bound]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = Cure
    bound_type = upper
    bound_value = 1.0
  []
  [C_lower_bound]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = Cure
    bound_type = lower
    bound_value = 0.15
  []
[]

[Kernels]
  [tempdiff]
    type = TempDiffusion
    block = '1'
    variable = Temperature
  []
  [coupledcurederv]
    type = CoupledCureTimeDerivative
    block = '1'
    variable = Temperature
    v = Cure
  []
  [tempderv]
    type = HeatConductionTimeDerivative
    block = '0 1'
    variable = Temperature
    lumping = false
  []
  [curederv]
    type = TimeDerivative
    block = '1 0'
    variable = Cure
    lumping = false
  []
  [cureformula]
    type = DCPDnonDgeneralPT
    block = '1'
    variable = Cure
    v = Temperature
    Ttrig = 1
    Tintl = 0
    _E = 103539
    _n = 1.6754
    _m = 0.8344
    _cd = 28.1163
    _ad = 0.6809
  []
[]

[BCs]
  [temp_left]
    type = DirichletBC
    variable = Temperature
    boundary = left
    value = 200
  []
  # Moving boundary convection
  [convective_ink_surface]
    type = ConvectiveFluxFunction
    boundary = ink_surface
    variable = Temperature
    coefficient = 20
    T_infinity = 20
  []
  # NOTE: No bottom BC - insulative substrate (adiabatic)
[]

[Materials]
  [ink]
    block = 1
    type = GenericConstantMaterial
    prop_names = 'specific_heat Hr density TConductivity A'
    prop_values = '1600 340000 980 0.152 3.129e14'
  []
  [air]
    block = '0'
    type = GenericConstantMaterial
    prop_names = 'specific_heat density TConductivity'
    prop_values = '1003 1.2041 0.03'
  []
[]

[Functions]
  # Current layer (1-4) based on nozzle_y position
  [current_layer_func]
    type = ParsedFunction
    expression = 'floor(nozzle_y / 0.0016) + 1'
    symbol_names = 'nozzle_y'
    symbol_values = 'nozzle_y_value'
  []
  # Direction: 1 for left-to-right (odd layers), -1 for right-to-left (even layers)
  [direction_func]
    type = ParsedFunction
    expression = 'if((floor(nozzle_y / 0.0016) - 2*floor(floor(nozzle_y / 0.0016)/2)) < 0.5, 1, -1)'
    symbol_names = 'nozzle_y'
    symbol_values = 'nozzle_y_value'
  []
  # Y-coordinate for front tracking (center of current layer)
  [front_tracking_y_func]
    type = ParsedFunction
    expression = '0.0008 + floor(nozzle_y / 0.0016) * 0.0016'
    symbol_names = 'nozzle_y'
    symbol_values = 'nozzle_y_value'
  []
[]

[Postprocessors]
  # ============ Nozzle Position Tracking ============
  # Velocity from PID (or constant during initial phase)
  [velocity_pp]
    type = Receiver
    default = 0.001  # Start at 1 mm/s
  []

  # Nozzle x-displacement (integrated velocity)
  [nozzle_x_displacement]
    type = TimeIntegratedPostprocessor
    value = velocity_pp
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # Nozzle x-position (starts at 0.0008m = 0.8mm, center of initial 1.6mm ink)
  [nozzle_x_value]
    type = ParsedPostprocessor
    expression = '0.0008 + nozzle_x_displacement'
    pp_names = 'nozzle_x_displacement'
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # Current layer number (1-4)
  [current_layer]
    type = Receiver
    default = 1
  []

  # Nozzle y-position (center of current layer)
  [nozzle_y_value]
    type = ParsedPostprocessor
    expression = '0.0008 + (current_layer - 1) * 0.0016'
    pp_names = 'current_layer'
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # ============ Front Tracking ============
  # Front location on Layer 1
  [front_location_L1]
    type = FindValueOnLine
    v = Cure
    start_point = '0 0.0008 0'
    end_point = '0.02 0.0008 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # Front location on Layer 2
  [front_location_L2]
    type = FindValueOnLine
    v = Cure
    start_point = '0 0.0024 0'
    end_point = '0.02 0.0024 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # Front location on Layer 3
  [front_location_L3]
    type = FindValueOnLine
    v = Cure
    start_point = '0 0.0040 0'
    end_point = '0.02 0.0040 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # Front location on Layer 4
  [front_location_L4]
    type = FindValueOnLine
    v = Cure
    start_point = '0 0.0056 0'
    end_point = '0.02 0.0056 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # Active front location (based on current layer)
  [front_location]
    type = ParsedPostprocessor
    expression = 'if(current_layer < 1.5, front_location_L1, if(current_layer < 2.5, front_location_L2, if(current_layer < 3.5, front_location_L3, front_location_L4)))'
    pp_names = 'current_layer front_location_L1 front_location_L2 front_location_L3 front_location_L4'
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # ============ Distance Calculations ============
  # Nozzle-to-front distance (absolute value)
  [front_nozzle_distance]
    type = ParsedPostprocessor
    expression = 'abs(nozzle_x_value - front_location)'
    pp_names = 'nozzle_x_value front_location'
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # Distance from front to layer end (for transition detection)
  # Layer 1,3: end at x=0.02; Layer 2,4: end at x=0
  [front_to_layer_end]
    type = ParsedPostprocessor
    expression = 'if((current_layer - 2*floor(current_layer/2)) > 0.5, 0.02 - front_location, front_location)'
    pp_names = 'current_layer front_location'
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # ============ Velocity and State Tracking ============
  [front_velocity]
    type = ChangeOverTimePostprocessor
    postprocessor = front_location
    change_with_respect_to_initial = false
    execute_on = 'TIMESTEP_END'
  []

  [print_velocity]
    type = ScalePostprocessor
    value = velocity_pp
    scaling_factor = 1.0
    execute_on = 'TIMESTEP_END'
  []

  # ============ Cure Monitoring ============
  [max_cure]
    type = ElementExtremeValue
    variable = Cure
    value_type = max
    execute_on = 'TIMESTEP_END'
  []

  [avg_cure_ink]
    type = ElementAverageValue
    variable = Cure
    block = 1
    execute_on = 'TIMESTEP_END'
  []

  [max_temperature]
    type = ElementExtremeValue
    variable = Temperature
    value_type = max
    execute_on = 'TIMESTEP_END'
  []
[]

[MeshModifiers]
  [activate_ink]
    type = CoupledVarThresholdElementSubdomainModifier
    coupled_var = dist
    subdomain_id = 1
    threshold = 0.0008
    criterion_type = BELOW
    moving_boundaries = 'ink_surface'
    moving_boundary_subdomain_pairs = '1'
    execute_on = 'TIMESTEP_BEGIN TIMESTEP_END'
  []
[]

[Controls]
  # Multi-layer Position Form PID velocity control
  [multilayer_pid]
    type = MultiLayerPIDControlDirect
    # Postprocessors for control
    front_nozzle_distance_pp = front_nozzle_distance
    front_location_pp = front_location
    nozzle_x_pp = nozzle_x_value
    velocity_pp = 'velocity_pp'

    # PID parameters (Position Form optimized gains)
    target_distance = 0.007       # 7 mm
    K_proportional = -10.0
    K_integral = -1.0
    K_derivative = -0.5
    control_interval = 0.0        # Every timestep for position form

    # Layer transition parameters
    transition_gap = 0.001        # 1 mm
    vertical_delay = 1.0          # 1 s
    initial_velocity = 0.01       # 10 mm/s
    finishing_velocity = 0.005    # 5 mm/s for slow finish
    initial_nozzle_offset = 0.0062 # 6.2 mm (from 0.8mm to 7mm)
    initial_nozzle_x = 0.0008     # 0.8 mm (center of initial 1.6mm ink)
    pid_stop_distance = 0.002     # 2 mm from layer end to stop PID

    # Layer geometry
    layer_length = 0.02           # 20 mm
    layer_height = 0.0016         # 1.6 mm
    num_layers = 4

    # Output limits
    minimum_output_value = 0.0001
    maximum_output_value = 0.1
    reset_integral_windup = true

    execute_on = 'TIMESTEP_BEGIN'
  []
  # Disable left BC after 1 second
  [bcs]
    type = TimePeriod
    disable_objects = 'BCs::temp_left'
    start_time = 1
    execute_on = 'initial timestep_begin'
  []
[]

[Adaptivity]
  marker = errorfrac
  max_h_level = 3
  [Indicators]
    [error]
      type = GradientJumpIndicator
      variable = Cure
      outputs = none
    []
  []
  [Markers]
    [errorfrac]
      type = ErrorFractionMarker
      refine = 0.65
      coarsen = 0.2
      indicator = error
      outputs = none
    []
  []
[]

[Executioner]
  automatic_scaling = true
  type = Transient
  num_steps = 80000
  nl_rel_tol = 1e-7
  end_time = 120  # Extended for 4 layers
  nl_max_its = 10
  l_max_its = 15
  [TimeStepper]
    type = ConstantDT
    dt = 0.01
  []
  [TimeIntegrator]
    type = ImplicitEuler
  []
  solve_type = 'PJFNK'
  petsc_options_iname = '-snes_type'
  petsc_options_value = 'vinewtonrsls'
[]

[Outputs]
  [exodus]
    type = Exodus
    file_base = multilayer_position_form/multilayer_position_form
    execute_on = 'initial timestep_end'
  []
  [csv]
    type = CSV
    file_base = multilayer_position_form/multilayer_position_form_data
    execute_on = 'initial timestep_end'
  []
[]
