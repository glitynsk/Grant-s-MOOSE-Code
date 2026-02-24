################################################################################
## PID-Controlled Frontal Polymerization Simulation
## Uses PIDTransientControlInterval with control_interval=0.05s
################################################################################

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    ymin = 0.0
    xmax = 0.02
    ymax = 0.0016
    nx = 120
    ny = 12
  []
  [ink]
    type = SubdomainBoundingBoxGenerator
    input = 'gen'
    block_id = 1
    bottom_left = '0 0 0'
    top_right = '0.0016 0.0016 0'
  []
  [air]
    type = SubdomainBoundingBoxGenerator
    input = 'ink'
    block_id = 0
    bottom_left = '0.0016 0 0'
    top_right = '0.02 0.0016 0'
  []
  # Pre-declare sideset for moving boundary (will be populated by MeshModifier)
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
  []
  [bounds_dummy]
  []
[]

[AuxKernels]
  [compute_dist]
    type = ParsedAux
    variable = dist
    expression = 'sqrt((x-xn)^2+(y-0.0008)^2)'
    functor_names = 'nozzle_x_value'
    functor_symbols = 'xn'
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
  # Moving boundary convection - applied only to external surfaces of active ink
  [convective_ink_surface]
    type = ConvectiveFluxFunction
    boundary = bottom
    variable = Temperature
    coefficient = coef_func
    T_infinity = Tinf_func
  []
[]

[Functions]

  [./coef_func]
    type = ParsedFunction
    expression = '30 - 10 * if(sin(2*pi*(1/10)*t) > 0, 1, -1)'
  [../]

  [./Tinf_func]
    type = ParsedFunction
    expression = '4.1667e-4*t^3 - 0.0429*t^2 + 1.4226*t + 15'
  [../]
  

  [distance_target]
    type = ParsedFunction
    expression = '0.007'
  []

  [distance_reward]
    type = ScaledAbsDifferenceDRLRewardFunction
    design_function = distance_target
    observed_value = front_nozzle_distance
    c1 = 1
    c2 = 10
  []


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

[Postprocessors]
  [velocity_pp]
    type = Receiver
    default = 0.001
  []
  [nozzle_displacement]
    type = TimeIntegratedPostprocessor
    value = velocity_pp
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []
  [nozzle_x_value]
    type = ParsedPostprocessor
    expression = '0.0008 + nozzle_displacement'
    pp_names = 'nozzle_displacement'
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []
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
  [front_nozzle_distance]
    type = DifferencePostprocessor
    value1 = nozzle_x_value
    value2 = front_location
    execute_on = 'INITIAL TIMESTEP_END'
  []
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
  
  [./Tinf_pp]
    type = FunctionValuePostprocessor
    function = Tinf_func
  [../]
  
  [./coe_pp]
    type = FunctionValuePostprocessor
    function = coef_func
  [../]
  

  [reward]
    type = FunctionValuePostprocessor
    function = distance_reward
    execute_on = 'TIMESTEP_END'
  []

  [velocity_action]
    type = LibtorchControlValuePostprocessor
    control_name = velocity_control
  []

  [velocity_log_prob]
    type = LibtorchDRLLogProbabilityPostprocessor
    control_name = velocity_control
  []


[]

[Reporters]
  [control_reporter]
    type = AccumulateReporter
    reporters = 'front_nozzle_distance/value reward/value velocity_action/value velocity_log_prob/value'
  []
[]


[MeshModifiers]
  [activate_ink]
    type = CoupledVarThresholdElementSubdomainModifier
    coupled_var = dist
    subdomain_id = 1
    threshold = 0.0008
    criterion_type = BELOW
    # Moving boundary for convection BC on external ink surfaces
#    moving_boundaries = 'ink_surface'
#    moving_boundary_subdomain_pairs = '1'
    execute_on = 'TIMESTEP_BEGIN'
  []
[]

[Controls]

  [velocity_control]
    type = LibtorchDRLControl

    # Action
    parameters = "Postprocessors/velocity_pp/value"

    # Observations
    responses = 'front_nozzle_distance'

    # Keep consistent with trainer
    input_timesteps = 1
    response_scaling_factors = '100'
    response_shift_factors = '0.007'

    action_standard_deviations = '0.0005'
    action_scaling_factors = 0.01

    execute_on = 'TIMESTEP_BEGIN'
  []


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
  [./Indicators]
    [./error]
      type = GradientJumpIndicator
      variable = Cure
      outputs = none
    [../]
  [../]
  [./Markers]
    [./errorfrac]
      type = ErrorFractionMarker
      refine = 0.65
      coarsen = 0.2
      indicator = error
      outputs = none
    [../]
  [../]
[]

[Executioner]
  automatic_scaling = true
  type = Transient
  num_steps = 80000
  nl_rel_tol = 1e-7
  end_time = 8
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
    file_base = pid_control_new7pos/pid_control
    execute_on = 'initial timestep_end'
  []
  [csv]
    type = CSV
    file_base = pid_control_new7pos/pid_data
    execute_on = 'initial timestep_end'
  []
[]
