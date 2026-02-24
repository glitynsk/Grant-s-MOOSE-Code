################################################################################
## Constant Speed Multi-Layer Frontal Polymerization Printing - NO SUBSTRATE
## WITH EXTRA INITIATION INK AND AIR BUFFER
## NO PID CONTROL - constant 0.8 mm/s printing speed
##
## Domain:
##   - Extra initiation ink: 1.6mm x 1.6mm (x = -1.6mm to 0, y = 0 to 1.6mm)
##   - 4 ink layers, each 5mm long x 1.6mm thick (x = 0 to 5mm, y = 0 to 6.4mm)
##   - Air buffer layer (block 4): surrounds print area on right, top, left, and bottom
##     (allows ink_top_moving to capture all ink-air interfaces automatically)
##   - Total domain: 6.8mm x 6.8mm (with 0.2mm buffer on all sides except left of extra ink)
##
## Block IDs:
##   - Block 0: Air (converts to ink during printing)
##   - Block 1: Ink (initial extra ink + deposited ink)
##   - Block 4: Air buffer (no solve - just for boundary tracking)
##
## Initial Conditions:
##   - Extra initiation ink: 1.6mm x 1.6mm at x = -1.6mm to 0, 20C
##   - Nozzle starts at x=0 (right edge of extra initiation ink, start of main domain)
##   - Nozzle is stationary for first 1 second (heat source on left initiates front)
##   - Ink deposition starts after 1 second
##
## Boundary Conditions:
##   - Left of extra ink: 200C for first 1 second (heat source)
##   - All exposed ink surfaces: convection to ambient (20C) via ink_top_moving
##   - ink_top_moving automatically captures all ink-buffer interfaces (top AND bottom)
##   - Bottom of first layer ink: CONVECTION (no substrate)
##
## Printing Process:
##   - After 1 second: nozzle moves at 0.8 mm/s constant speed
##   - When nozzle hits layer end (5mm for odd layers, 0mm for even):
##     - Stop for 1 second (vertical move)
##     - Continue at same 0.8 mm/s on next layer
##   - Extra initiation ink (x < 0) will be removed after printing
##
## Parameters:
##   - print_speed = 0.0008 m/s (0.8 mm/s)
##   - start_delay = 1 s
##   - vertical_delay = 1 s
##   - layer_length = 0.005 m (5 mm)
##   - layer_height = 0.0016 m (1.6 mm)
##   - num_layers = 4
##   - extra_ink_length = 0.0016 m (1.6 mm)
##   - buffer_thickness = 0.0002 m (0.2 mm)
##
## Time estimates (nozzle starts at x=0):
##   - Layer 1: t=0-1s (stationary), t=1-7.25s (printing 5mm at 0.8mm/s)
##   - Transition 1->2: t=7.25-8.25s (vertical move)
##   - Layer 2: t=8.25-14.5s (printing 5mm at 0.8mm/s)
##   - Transition 2->3: t=14.5-15.5s
##   - Layer 3: t=15.5-21.75s
##   - Transition 3->4: t=21.75-22.75s
##   - Layer 4: t=22.75-29s
##   - Total: ~29 seconds
################################################################################

[Mesh]
  # Extended rectangular mesh with air buffer layer around print area
  # Buffer allows ink_top_moving to capture all ink-air interfaces
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = -0.0016            # Extra 1.6mm for initiation ink
    xmax = 0.0052             # 5 mm + 0.2mm buffer on right
    ymin = -0.0002            # 0.2mm buffer below ink
    ymax = 0.0066             # Top of 4 ink layers (6.4 mm) + 0.2mm buffer
    nx = 84                   # 2x finer: 20 for extra + 60 for main + 4 for buffer
    ny = 124                  # 2x finer: 4 for bottom buffer + 96 for ink + 4 for top buffer
  []

  # Extra initiation ink region (1.6mm x 1.6mm at x=-1.6mm to 0) - block 1
  [extra_ink]
    type = SubdomainBoundingBoxGenerator
    input = 'gen'
    block_id = 1
    bottom_left = '-0.0016 0 0'
    top_right = '0 0.0016 0'
  []

  # Air region that will be converted to ink (x=0 to 5mm, y=0 to 6.4mm) - block 0
  [air]
    type = SubdomainBoundingBoxGenerator
    input = 'extra_ink'
    block_id = 0
    bottom_left = '0 0 0'
    top_right = '0.005 0.0064 0'
  []

  # Air buffer on right side (x=5mm to 5.2mm, y=-0.2mm to 6.6mm) - block 4
  [buffer_right]
    type = SubdomainBoundingBoxGenerator
    input = 'air'
    block_id = 4
    block_name = 'buffer'
    bottom_left = '0.005 -0.0002 0'
    top_right = '0.0052 0.0066 0'
  []

  # Air buffer on top (x=-1.6mm to 5mm, y=6.4mm to 6.6mm) - block 4
  [buffer_top]
    type = SubdomainBoundingBoxGenerator
    input = 'buffer_right'
    block_id = 4
    block_name = 'buffer'
    bottom_left = '-0.0016 0.0064 0'
    top_right = '0.005 0.0066 0'
  []

  # Air buffer on left above extra ink (x=-1.6mm to 0, y=1.6mm to 6.4mm) - block 4
  [buffer_left]
    type = SubdomainBoundingBoxGenerator
    input = 'buffer_top'
    block_id = 4
    block_name = 'buffer'
    bottom_left = '-0.0016 0.0016 0'
    top_right = '0 0.0064 0'
  []

  # Air buffer on bottom (x=-1.6mm to 5mm, y=-0.2mm to 0) - block 4
  [buffer_bottom]
    type = SubdomainBoundingBoxGenerator
    input = 'buffer_left'
    block_id = 4
    block_name = 'buffer'
    bottom_left = '-0.0016 -0.0002 0'
    top_right = '0.005 0 0'
  []

  # Static sideset for top of initial extra ink (for convection)
  [./top]
    input = buffer_bottom
    type = SideSetsAroundSubdomainGenerator
    normal = '0 1 0'
    block = 1
    new_boundary = 'ink_top'
  []

  # Static sideset for bottom of initial extra ink (for convection - insulative substrate)
  [./bottom_ink]
    input = top
    type = SideSetsAroundSubdomainGenerator
    normal = '0 -1 0'
    block = 1
    new_boundary = 'ink_bottom'
  []

  # Create sideset for left boundary of extra initiation ink region (for heating BC)
  [left_ink_sideset]
    type = SideSetsAroundSubdomainGenerator
    input = 'bottom_ink'
    block = 1
    normal = '-1 0 0'
    new_boundary = 'left_ink'
  []

  # Pre-declare moving boundary sideset for ink-air/ink-buffer interface
  add_sideset_names = 'ink_top_moving'
  add_sideset_ids = '7'
[]

[Problem]
  type = FEProblem
  solve = true
  kernel_coverage_check = false
  material_coverage_check = false
[]

[Variables]
  # Temperature only on ink block
  # Block 0 (air) and block 4 (buffer) have no variables - nothing solved there
  # Air elements are converted to ink (block 1) during printing
  [Temperature]
    order = FIRST
    family = LAGRANGE
    initial_condition = 20
    block = '1'
  []
  # Cure only on ink block
  [Cure]
    order = FIRST
    family = LAGRANGE
    initial_condition = 0.15
    block = '1'
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
    block = '1'
    variable = Temperature
    lumping = false
  []
  [curederv]
    type = TimeDerivative
    block = '1'
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
  # Heat source applied to left boundary of extra initiation ink region
  [temp_left]
    type = DirichletBC
    variable = Temperature
    boundary = left_ink
    value = 200
  []

  # Convection on top of initial extra ink (static)
  [convective_ink_top]
    type = ConvectiveFluxFunction
    boundary = ink_top
    variable = Temperature
    coefficient = 20
    T_infinity = 20
  []


  # Convection on moving boundary (all ink-air and ink-buffer interfaces)
  # This now automatically captures:
  #   - Top surface of deposited ink as it's laid down
  #   - Bottom surface of deposited ink (insulative substrate)
  #   - Right edge of ink when it reaches x=5mm (ink-buffer interface)
  #   - Left edge of ink for layers 2-4 at x=0 (ink-buffer interface)
  #   - Top of layer 4 at y=6.4mm (ink-buffer interface)
  [convective_ink_top_moving]
    type = ConvectiveFluxFunction
    boundary = ink_top_moving
    variable = Temperature
    coefficient = 20
    T_infinity = 20
  []
[]

[Materials]
  # Only ink material needed - no solve in air/buffer domains
  [ink]
    block = 1
    type = GenericConstantMaterial
    prop_names = 'specific_heat Hr density TConductivity A'
    prop_values = '1600 340000 980 0.152 3.129e14'
  []
[]

[Functions]
  # Constant speed velocity function with layer transitions
  # Nozzle starts at x=0 (right edge of extra initiation ink, start of main domain)
  # Ink deposition starts after 1 second (heat source initiates front during t=0 to t=1)
  # Layer 1: x=0 to x=5mm (5mm travel)
  # Time for Layer 1: 5mm / 0.8mm/s = 6.25s, so t=1 to t=7.25
  # Vertical move: t=7.25 to t=8.25
  # Layer 2: x=5mm to x=0 (5mm travel), t=8.25 to t=14.5
  # Vertical move: t=14.5 to t=15.5
  # Layer 3: x=0 to x=5mm, t=15.5 to t=21.75
  # Vertical move: t=21.75 to t=22.75
  # Layer 4: x=5mm to x=0, t=22.75 to t=29
  [velocity_func]
    type = ParsedFunction
    expression = 'if(t < 1, 0, if(t < 7.25, 0.0008, if(t < 8.25, 0, if(t < 14.5, -0.0008, if(t < 15.5, 0, if(t < 21.75, 0.0008, if(t < 22.75, 0, if(t < 29, -0.0008, 0))))))))'
  []

  # Current layer function based on time
  [current_layer_func]
    type = ParsedFunction
    expression = 'if(t < 8.25, 1, if(t < 15.5, 2, if(t < 22.75, 3, 4)))'
  []
[]

[Postprocessors]
  # ============ Velocity Control ============
  [velocity_pp]
    type = FunctionValuePostprocessor
    function = velocity_func
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # ============ Nozzle Position Tracking ============
  [nozzle_x_displacement]
    type = TimeIntegratedPostprocessor
    value = velocity_pp
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # Nozzle starts at x=0 (right edge of extra initiation ink)
  [nozzle_x_value]
    type = ParsedPostprocessor
    expression = '0 + nozzle_x_displacement'
    pp_names = 'nozzle_x_displacement'
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  [current_layer]
    type = FunctionValuePostprocessor
    function = current_layer_func
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  [nozzle_y_value]
    type = ParsedPostprocessor
    expression = '0.0008 + (current_layer - 1) * 0.0016'
    pp_names = 'current_layer'
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # ============ Front Tracking ============
  [front_location_L1]
    type = FindValueOnLine
    v = Cure
    start_point = '-0.0016 0.0008 0'
    end_point = '0.005 0.0008 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = -0.0016
    execute_on = 'INITIAL TIMESTEP_END'
  []

  [front_location_L2]
    type = FindValueOnLine
    v = Cure
    start_point = '0.0002 0.0024 0'
    end_point = '0.005 0.0024 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_END'
  []

  [front_location_L3]
    type = FindValueOnLine
    v = Cure
    start_point = '0.0002 0.0040 0'
    end_point = '0.005 0.0040 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_END'
  []

  [front_location_L4]
    type = FindValueOnLine
    v = Cure
    start_point = '0.0002 0.0056 0'
    end_point = '0.005 0.0056 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_END'
  []

  [front_location]
    type = ParsedPostprocessor
    expression = 'if(current_layer < 1.5, front_location_L1, if(current_layer < 2.5, front_location_L2, if(current_layer < 3.5, front_location_L3, front_location_L4)))'
    pp_names = 'current_layer front_location_L1 front_location_L2 front_location_L3 front_location_L4'
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # ============ Distance Calculations ============
  [front_nozzle_distance]
    type = ParsedPostprocessor
    expression = 'abs(nozzle_x_value - front_location)'
    pp_names = 'nozzle_x_value front_location'
    execute_on = 'INITIAL TIMESTEP_END'
  []

  [front_to_layer_end]
    type = ParsedPostprocessor
    expression = 'if((current_layer - 2*floor(current_layer/2)) > 0.5, 0.005 - front_location, front_location)'
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
    block = 1
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
    block = 1
    value_type = max
    execute_on = 'TIMESTEP_END'
  []
[]

[MeshModifiers]
  [activate_ink]
    type = CoupledVarThresholdElementSubdomainModifier
    coupled_var = dist
    block = 0                 # Only convert air (block 0) to ink, NOT buffer (block 4)
    subdomain_id = 1
    threshold = 0.0008
    criterion_type = BELOW
    # Moving boundary for convection BC on ink-air and ink-buffer interfaces
    # This captures all exposed ink surfaces automatically
    moving_boundaries = 'ink_top_moving'
    moving_boundary_subdomain_pairs = '1 0; 1 4'
    # Execute at both BEGIN and END to handle elements refined by adaptivity at TIMESTEP_END
    execute_on = 'TIMESTEP_BEGIN TIMESTEP_END'
  []
[]

[Controls]
  # Disable left BC after 1 second
  [bcs]
    type = TimePeriod
    disable_objects = 'BCs::temp_left'
    start_time = 1
    execute_on = 'initial timestep_begin'
  []
[]

# v3: Adaptivity DISABLED - using 2x finer base mesh instead
# [Adaptivity]
# []

[Executioner]
  automatic_scaling = true
  type = Transient
  num_steps = 800000
  nl_rel_tol = 1e-6
  nl_abs_tol = 1e-8
  end_time = 35  # Enough time for 4 layers (~29s) plus margin
  nl_max_its = 15
  l_max_its = 30
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.01
    optimal_iterations = 8
    iteration_window = 2
    growth_factor = 1.2
    cutback_factor = 0.5
  []
  [TimeIntegrator]
    type = ImplicitEuler
  []
  solve_type = 'PJFNK'
  petsc_options_iname = '-snes_type -snes_linesearch_type'
  petsc_options_value = 'vinewtonrsls basic'
[]

[Outputs]
  [exodus]
    type = Exodus
    file_base = constant_speed_0p8_nosubstrate_MultiLayer_out/constant_speed_0p8_nosubstrate_MultiLayer_out
    time_step_interval = 5
    execute_on = 'initial timestep_end'
  []
  [csv]
    type = CSV
    file_base = constant_speed_0p8_nosubstrate_MultiLayer_out/constant_speed_0p8_nosubstrate_MultiLayer_data
    execute_on = 'initial timestep_end'
  []
[]
