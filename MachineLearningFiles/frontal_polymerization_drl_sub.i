################################################################################
## DRL-Controlled Frontal Polymerization Simulation
## Replaces PID control with Deep Reinforcement Learning
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
  
  # Target distance for reward calculation
  [./target_distance]
    type = ParsedFunction
    expression = '0.007'  # Target nozzle-front distance (7mm)
  [../]
  
  # Reward function - penalizes deviation from target distance
  [./reward_function]
    type = ScaledAbsDifferenceDRLRewardFunction
    design_function = target_distance
    observed_value = front_nozzle_distance
    c1 = 10.0      # Scaling for small errors
    c2 = 1000.0    # Heavy penalty for large errors
  [../]
  
  [velocity_func]
    type = ConstantFunction
    value = 0.001
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
  # Velocity controlled by DRL (replaces PID control)
  [velocity_pp]
    type = FunctionValuePostprocessor
    function = velocity_func
    execute_on = 'INITIAL TIMESTEP_BEGIN'
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
  
  # Key state observation: distance between nozzle and front
  [front_nozzle_distance]
    type = DifferencePostprocessor
    value1 = nozzle_x_value
    value2 = front_location
    execute_on = 'INITIAL TIMESTEP_END'
  []
  
  # Additional state observation: front propagation velocity
  [front_velocity]
    type = ChangeOverTimePostprocessor
    postprocessor = front_location
    change_with_respect_to_initial = false
    execute_on = 'TIMESTEP_END'
  []
  
  # Additional state observation: current print velocity
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
  
  # DRL-specific postprocessors
  [reward]
    type = FunctionValuePostprocessor
    function = reward_function
    execute_on = 'INITIAL TIMESTEP_END'
    indirect_dependencies = 'front_nozzle_distance'
  []
  
  [velocity_action]
    type = LibtorchControlValuePostprocessor
    control_name = drl_velocity_control
  []
  
  [log_prob_velocity]
    type = LibtorchDRLLogProbabilityPostprocessor
    control_name = drl_velocity_control
  []
[]

[Reporters]
  # Accumulate data for DRL training
  [training_data]
    type = AccumulateReporter
    reporters = 'front_nozzle_distance/value front_velocity/value print_velocity/value reward/value velocity_action/value log_prob_velocity/value'
  []
[]

[MeshModifiers]
  [activate_ink]
    type = CoupledVarThresholdElementSubdomainModifier
    coupled_var = dist
    subdomain_id = 1
    threshold = 0.0008
    criterion_type = BELOW
    execute_on = 'TIMESTEP_BEGIN'
  []
[]

[Controls]
  inactive = 'drl_velocity_control_final'  # Use this for training phase
  
  # DRL control during training

  [drl_velocity_control]
    type = LibtorchDRLControl
    parameters = 'Functions/velocity_func/value'
    
    # State observations: distance, front velocity, current print velocity
    responses = 'front_nozzle_distance front_velocity print_velocity'
    
    # Use 3 timesteps of history for temporal awareness
    input_timesteps = 3
    
    # Normalize state inputs (divide by these values after shifting)
    # front_nozzle_distance: typical range 0-0.02m, scale by 0.01 -> range 0-2
    # front_velocity: typical range 0-0.01 m/s, scale by 0.01 -> range 0-1
    # print_velocity: typical range 0-0.1 m/s, scale by 0.1 -> range 0-1
    response_scaling_factors = '0.01 0.01 0.1'
    
    # Shift state inputs (subtract these before scaling)
    response_shift_factors = '0.0 0.0 0.0'
    
    # Exploration noise for training (standard deviation of Gaussian noise)
    action_standard_deviations = '0.01'
    
    # Scale actions to appropriate range (actions are centered around 0)
    # action_scaling_factors * action + action_shift gives final velocity
    # With scaling=0.05, actions of [-1,1] give velocities around [0, 0.1]
    action_scaling_factors = '0.05'
    
    execute_on = 'TIMESTEP_BEGIN'
  []
  
  # For deployment after training (inactive during training)
  [drl_velocity_control_final]
    type = LibtorchNeuralNetControl
    filename = 'trained_velocity_policy.net'
    num_neurons_per_layer = '32 16'
    activation_function = 'relu'
    
    parameters = 'Postprocessors/velocity_pp/value'
    responses = 'front_nozzle_distance front_velocity print_velocity'
    
    # Must match training settings
    input_timesteps = 3
    response_scaling_factors = '0.01 0.01 0.1'
    response_shift_factors = '0.0 0.0 0.0'
    action_standard_deviations = '0.01'
    action_scaling_factors = '0.05'
    
    execute_on = 'TIMESTEP_BEGIN'
  []
  
  # Disable initial temperature BC after t=1s (same as original)
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
  console = false
  [csv]
    type = CSV
    file_base = 'episode_data/episode'
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [exodus]
    type = Exodus
    file_base = 'episode_data/episode'
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]
