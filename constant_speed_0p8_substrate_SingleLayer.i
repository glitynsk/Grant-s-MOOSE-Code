################################################################################
## Constant Speed Single-Layer Frontal Polymerization Printing WITH SUBSTRATE
## NO PID CONTROL - constant 0.8 mm/s printing speed
##
## Domain:
##   - Glass substrate: 20mm x 3.3mm (y = -3.3mm to 0)
##   - 1 ink layer, 20mm long x 1.6mm thick (y = 0 to 1.6mm)
##   - Total: 20mm x 4.9mm
##
## Initial Conditions:
##   - Substrate: 85°C (heated plate)
##   - Ink: x=0 to x=1.6mm on Layer 1
##   - Nozzle starts at x=1.6mm (right edge of initial ink)
##   - Nozzle is stationary for first 1 second (heat source on left)
##
## Boundary Conditions:
##   - Bottom of glass: 85°C (Dirichlet) - heated plate
##   - Top of ink: convection to ambient (20°C)
##   - Left of ink: 200°C for first 1 second, then convection
##   - No convection on ink bottom (in contact with substrate)
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
##   - substrate_thickness = 0.0033 m (3.3 mm)
##   - num_layers = 1
################################################################################

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    xmax = 0.02           # 20 mm length
    ymin = -0.0033        # Bottom of glass substrate (-3.3 mm)
    ymax = 0.0016         # Top of 1 ink layer (1.6 mm)
    nx = 120              # Same resolution as original
    ny = 37               # 25 elements for substrate (3.3mm) + 12 for ink (1.6mm)
  []

  # Glass substrate region (block 2)
  [substrate]
    type = SubdomainBoundingBoxGenerator
    input = 'gen'
    block_id = 2
    bottom_left = '0 -0.0033 0'
    top_right = '0.02 0 0'
  []

  # Initial ink region (Layer 1, first 1.6mm) - block 1
  [ink]
    type = SubdomainBoundingBoxGenerator
    input = 'substrate'
    block_id = 1
    bottom_left = '0 0 0'
    top_right = '0.0016 0.0016 0'
  []

  # Air region (rest of domain above substrate) - block 0
  [air]
    type = SubdomainBoundingBoxGenerator
    input = 'ink'
    block_id = 0
    bottom_left = '0.0016 0 0'
    top_right = '0.02 0.0016 0'
  []

  # Static sideset for top of initial ink (for convection)
  [./top]
    input = air
    type = SideSetsAroundSubdomainGenerator
    normal = '0 1 0'
    block = 1
    new_boundary = 'ink_top'
  []

  # Create sideset for left boundary of initial ink region (for convection BC)
  # NOTE: ParsedGenerateSideset does NOT export sidesets to Exodus/ParaView.
  #       Use SideSetsAroundSubdomainGenerator instead.
  [left_ink_sideset]
    type = SideSetsAroundSubdomainGenerator
    input = 'top'
    block = 1
    normal = '-1 0 0'
    new_boundary = 'left_ink'
  []

  # Pre-declare moving boundary sideset for top surface of newly activated ink
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
  # Temperature on substrate and ink only (not air - it will be activated as ink)
  [Temperature]
    order = FIRST
    family = LAGRANGE
    block = '1 2'
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
  # Substrate initial temperature: 85°C
  [substrate_temp_ic]
    type = ConstantIC
    variable = Temperature
    value = 85
    block = '2'
  []
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
  # Heat diffusion on all blocks (substrate, ink, and air for continuity)
  [tempdiff_substrate]
    type = TempDiffusion
    block = '2'
    variable = Temperature
  []
  [tempdiff_ink]
    type = TempDiffusion
    block = '1'
    variable = Temperature
  []

  # Heat capacity time derivative on substrate and ink
  [tempderv_substrate]
    type = HeatConductionTimeDerivative
    block = '2'
    variable = Temperature
    lumping = false
  []
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
  # Bottom of glass substrate maintained at 85°C
  [temp_bottom_substrate]
    type = DirichletBC
    variable = Temperature
    boundary = bottom
    value = 85
  []

  # Heat source applied to left boundary of initial ink region (first 1 second)
#  [temp_left]
#    type = DirichletBC
#    variable = Temperature
#    boundary = left_ink
#    value = 200
#  []

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
  # Ink material properties
  [ink]
    block = 1
    type = GenericConstantMaterial
    prop_names = 'specific_heat Hr density TConductivity A'
    prop_values = '1600 340000 980 0.152 3.129e14'
  []

  # Glass (borosilicate) substrate material properties
  [glass]
    block = 2
    type = GenericConstantMaterial
    prop_names = 'specific_heat density TConductivity'
    prop_values = '830 2230 1.14'
  []
[]

[Functions]
  # Constant speed velocity function (single layer - 1s delay then constant)
  [velocity_func]
    type = ParsedFunction
    expression = 'if(t < 2, 0.01, 0.0)'
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
  [front_location_vertical]
    type = FindValueOnLine
    v = Cure
    start_point = '0.01 0 0'
    end_point = '0.02 0.0016 0'
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

  # Substrate temperature monitoring
  [avg_temp_substrate]
    type = ElementAverageValue
    variable = Temperature
    block = 2
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
    # Moving boundary for convection BC on top surface of newly activated ink
    moving_boundaries = 'ink_top_moving'
    moving_boundary_subdomain_pairs = '1 0'
    # Execute at both BEGIN and END to handle elements refined by adaptivity at TIMESTEP_END
    execute_on = 'TIMESTEP_BEGIN TIMESTEP_END'
  []
[]

#[Controls]
  # Disable left BC after 1 second
#  [bcs]
#    type = TimePeriod
#    disable_objects = 'BCs::temp_left'
#    start_time = 1
#    execute_on = 'initial timestep_begin'
#  []
#[]

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
  end_time = 30
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
    file_base = through_thickness/constant_speed_0p8_substrate_SingleLayer_out
    time_step_interval = 10
  []
  [csv]
    type = CSV
    file_base = through_thickness/constant_speed_0p8_substrate_SingleLayer_data
  []
[]
