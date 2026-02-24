################################################################################
## Constant Speed Single-Layer Frontal Polymerization Printing - NO SUBSTRATE
## NO PID CONTROL - constant 0.8 mm/s printing speed
##
## Domain:
##   - No substrate domain
##   - 1 ink layer, 20mm long x 1.6mm thick (y = 0 to 1.6mm)
##   - Air buffer at bottom for moving boundary tracking
##   - Total: 20mm x 1.8mm (with 0.2mm bottom buffer)
##
## Initial Conditions:
##   - Ink: x=0 to x=1.6mm on Layer 1, 20°C
##   - Nozzle starts at x=1.6mm (right edge of initial ink)
##   - Nozzle is stationary for first 1 second (heat source on left)
##
## Boundary Conditions:
##   - Bottom of ink: CONVECTION to ambient (20°C) via moving boundary
##   - Top of ink: convection to ambient (20°C)
##   - Left of ink: 200°C for first 1 second, then convection
##
## Printing Process:
##   - After 1 second: nozzle moves at 0.8 mm/s constant speed
##   - Print continues until nozzle reaches end (20mm)
##
## Parameters:
##   - print_speed = 0.0008 m/s (0.8 mm/s)
##   - start_delay = 1 s
##   - layer_length = 0.02 m (20 mm)
##   - layer_height = 0.0016 m (1.6 mm)
##   - num_layers = 1
################################################################################

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    xmax = 0.02           # 20 mm length
    ymin = -0.0002        # Bottom buffer (0.2mm below ink)
    ymax = 0.0016         # Top of 1 ink layer (1.6 mm)
    nx = 120              # Same resolution as original
    ny = 14               # 2 for bottom buffer + 12 for ink (1.6mm)
  []

  # Initial ink region (Layer 1, first 1.6mm) - block 1
  [ink]
    type = SubdomainBoundingBoxGenerator
    input = 'gen'
    block_id = 1
    bottom_left = '0 0 0'
    top_right = '0.0016 0.0016 0'
  []

  # Air region (rest of domain above y=0) - block 0
  [air]
    type = SubdomainBoundingBoxGenerator
    input = 'ink'
    block_id = 0
    bottom_left = '0.0016 0 0'
    top_right = '0.02 0.0016 0'
  []

  # Bottom buffer region (y = -0.2mm to 0) - block 4
  [buffer_bottom]
    type = SubdomainBoundingBoxGenerator
    input = 'air'
    block_id = 4
    block_name = 'buffer'
    bottom_left = '0 -0.0002 0'
    top_right = '0.02 0 0'
  []

  # Static sideset for top of initial ink (for convection)
  [./top]
    input = buffer_bottom
    type = SideSetsAroundSubdomainGenerator
    normal = '0 1 0'
    block = 1
    new_boundary = 'ink_top'
  []

  # Create sideset for left boundary of initial ink region (for convection BC)
  [left_ink_sideset]
    type = SideSetsAroundSubdomainGenerator
    input = 'top'
    block = 1
    normal = '-1 0 0'
    new_boundary = 'left_ink'
  []

  # Pre-declare moving boundary sideset for all ink surfaces (top and bottom)
  # With bottom buffer, moving boundary will capture both top and bottom surfaces
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
  # Temperature on ink only (no substrate)
  [Temperature]
    order = FIRST
    family = LAGRANGE
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

[ICs]
  # Ink region initial temperature: 20°C
  [ink_temp_ic]
    type = ConstantIC
    variable = Temperature
    value = 20
    block = '1'
  []
[]

[AuxVariables]
  [dist]
    # Distance from nozzle position
  []
  [bounds_dummy]
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
  # Heat diffusion on ink only (no substrate)
  [tempdiff_ink]
    type = TempDiffusion
    block = '1'
    variable = Temperature
  []

  # Heat capacity time derivative on ink
  [tempderv_ink]
    type = HeatConductionTimeDerivative
    block = '1'
    variable = Temperature
    lumping = false
  []

  # Cure-related kernels only on ink (block 1)
  [coupledcurederv]
    type = CoupledCureTimeDerivative
    block = '1'
    variable = Temperature
    v = Cure
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
  # Bottom of ink: CONVECTION via moving boundary (ink_top_moving captures both top and bottom)
  # The convective_ink_top_moving BC applies to all ink surfaces touching air/buffer

  # Heat source applied to left boundary of initial ink region (first 1 second)
  [temp_left]
    type = DirichletBC
    variable = Temperature
    boundary = left_ink
    value = 200
  []

  # Convection on moving boundary (top surface of newly activated ink)
  [convective_ink_top_moving]
    type = ConvectiveFluxFunction
    boundary = ink_top_moving
    variable = Temperature
    coefficient = 20
    T_infinity = 20
  []
[]

[Materials]
  # Ink material properties (no substrate)
  [ink]
    block = 1
    type = GenericConstantMaterial
    prop_names = 'specific_heat Hr density TConductivity A'
    prop_values = '1600 340000 980 0.152 3.129e14'
  []
[]

[Functions]
  # Constant speed velocity function (single layer - 1s delay then constant)
  [velocity_func]
    type = ParsedFunction
    expression = 'if(t < 1, 0, 0.0008)'
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

  [nozzle_x_value]
    type = ParsedPostprocessor
    expression = '0.0016 + nozzle_x_displacement'
    pp_names = 'nozzle_x_displacement'
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  [nozzle_y_value]
    type = ConstantPostprocessor
    value = 0.0008  # Middle of single layer (1.6mm / 2 = 0.8mm)
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # ============ Front Tracking ============
  [front_location]
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

  # ============ Distance Calculations ============
  [front_nozzle_distance]
    type = ParsedPostprocessor
    expression = 'abs(nozzle_x_value - front_location)'
    pp_names = 'nozzle_x_value front_location'
    execute_on = 'INITIAL TIMESTEP_END'
  []

  [front_to_layer_end]
    type = ParsedPostprocessor
    expression = '0.02 - front_location'
    pp_names = 'front_location'
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
    # Moving boundary for convection BC on all ink surfaces (top and bottom)
    moving_boundaries = 'ink_top_moving'
    moving_boundary_subdomain_pairs = '1 0; 1 4'  # Track ink-air AND ink-buffer interfaces
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

[Adaptivity]
  marker = errorfrac
  max_h_level = 4
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
  num_steps = 800000
  nl_rel_tol = 1e-7
  end_time = 30  # Single layer: ~24s print time + margin
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
    file_base = constant_speed_0p8_nosubstrate_SingleLayer_out/constant_speed_0p8_nosubstrate_SingleLayer_out
    execute_on = 'initial timestep_end'
  []
  [csv]
    type = CSV
    file_base = constant_speed_0p8_nosubstrate_SingleLayer_out/constant_speed_0p8_nosubstrate_SingleLayer_data
    execute_on = 'initial timestep_end'
  []
[]
