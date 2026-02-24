## DRL-controlled curing simulation - controlling cure front velocity

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    ymin = 0.0
    xmax = 0.01
    ymax = 0.0016
    nx = 30
    ny = 12
  []
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
    block = '0'
  []
  [Cure]
    order = FIRST
    family = LAGRANGE
    initial_condition = 0.15
    block = '0'
  []
[]
		
[AuxVariables]
  [bounds_dummy]
    order = FIRST
    family = LAGRANGE
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
    block = '0'
    variable = Temperature
  []
  [coupledcurederv]
    type = CoupledCureTimeDerivative
    block = '0'
    variable = Temperature
    v = Cure
  []
  [tempderv]
    type = HeatConductionTimeDerivative
    block = '0'
    variable = Temperature
    lumping = false
  []
  [curederv]
    type = TimeDerivative
    block = '0'
    variable = Cure
    lumping = false
  []
  [cureformula]
    type = DCPDnonDgeneralPT
    block = '0'
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
    type = FunctionDirichletBC
    variable = Temperature
    boundary = left
    function = temp_control_func
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
  [temp_control_func]
    type = ParsedFunction
    expression = 'min(200, max(20, 110.0 + ctrl))'  # Clamp to [20, 200]°C
    symbol_names = 'ctrl'
    symbol_values = 'ctrl_value'
  []
  
  [ctrl_value]
    type = ConstantFunction
    value = 0.0
  []
  
  [coef_func]
    type = ParsedFunction
    expression = '30 - 10 * if(sin(2*pi*(1/10)*t) > 0, 1, -1)'
  []

  [Tinf_func]
    type = ParsedFunction
    expression = '4.1667e-4*t^3 - 0.0429*t^2 + 1.4226*t + 15'
  []
  
  [target_velocity]
    type = ParsedFunction
    expression = '0.001'
  []
  
  # FIX: Use proper DRL reward function
  [reward_function]
    type = ScaledAbsDifferenceDRLRewardFunction
    design_function = target_velocity
    observed_value = front_velocity
    c1 = 1
    c2 = 10
  []
[]



[Materials]
  [ink]
    block = '0'
    type = GenericConstantMaterial
    prop_names = 'specific_heat Hr density TConductivity A'
    prop_values = '1600 340000 980 0.152 3.129e14'  # polymer attributes
  []
[]

[Postprocessors]
  # Track cure front location
  [front_location]
    type = FindValueOnLine
    v = Cure
    start_point = '0 0.0008 0'
    end_point = '0.01 0.0008 0'
    target = 0.5
    depth = 36
    tol = 1e-4
    error_if_not_found = false
    default_value = 0.0
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []
  
  # Calculate front propagation velocity
  [front_velocity]
    type = ChangeOverTimePostprocessor
    postprocessor = front_location
    change_with_respect_to_initial = false
    execute_on = 'TIMESTEP_END'
  []
  
  [temp_left_bc]
    type = SideAverageValue
    variable = Temperature
    boundary = left
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []
  
  [Tinf_pp]
    type = FunctionValuePostprocessor
    function = Tinf_func
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
  
  [coe_pp]
    type = FunctionValuePostprocessor
    function = coef_func
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
  
  # DRL-specific postprocessors
  [reward]
    type = FunctionValuePostprocessor
    function = reward_function
    execute_on = 'TIMESTEP_END'
    indirect_dependencies = 'front_velocity'
  []
  
  [control_action]
    type = LibtorchControlValuePostprocessor
    control_name = src_control
  []
  
  [log_prob_action]
    type = LibtorchDRLLogProbabilityPostprocessor
    control_name = src_control
  []
[]

[Reporters]
  [data_reporter]
    type = AccumulateReporter
    reporters = 'front_location/value front_velocity/value Tinf_pp/value reward/value control_action/value log_prob_action/value'
  []
[]

[Controls]
  inactive = 'src_control_final'
  
  [src_control]
    type = LibtorchDRLControl
    parameters = "Functions/ctrl_value/value"
    responses = 'front_location front_velocity Tinf_pp'
  
    input_timesteps = 3
    response_scaling_factors = '200 100000 0.01'
    response_shift_factors = '0 0 20'
    action_standard_deviations = '0.4'
    action_scaling_factors = 290  # ±290°C around 110°C baseline (was 90)
  
    execute_on = 'TIMESTEP_BEGIN'
  []
  
  [src_control_final]
    type = LibtorchNeuralNetControl
    filename = 'cure_control.pt'
    num_neurons_per_layer = '32 16'
    activation_function = 'relu'
  
    parameters = "Functions/ctrl_value/value"
    responses = 'front_location front_velocity Tinf_pp'
  
    input_timesteps = 3
    response_scaling_factors = '200 100000 0.01'
    response_shift_factors = '0 0 20'
    action_standard_deviations = '0.4'
    action_scaling_factors = 290  # ±290°C (was 90)
  
    execute_on = 'TIMESTEP_BEGIN'
  []
[]


[Executioner]
  automatic_scaling = true
  type = Transient
  
  end_time = 10
  
  nl_rel_tol = 1e-6
  nl_abs_tol = 1e-8
  nl_max_its = 25
  l_max_its = 50
  
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.05           # Start smaller
    optimal_iterations = 6
    iteration_window = 2
    growth_factor = 1.2  # Grow slowly
    cutback_factor = 0.5

  []
  
  [TimeIntegrator]
    type = ImplicitEuler
  []
  
  solve_type = 'PJFNK'
  line_search = bt  # Backtracking line search
  
  # Add these for better convergence
  petsc_options_iname = '-pc_type -pc_factor_shift_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu NONZERO superlu_dist'
[]

[Preconditioning]
  [pc]
    type = SMP
    full = true
    petsc_options_iname = '-snes_type'
    petsc_options_value = 'vinewtonrsls'
  []
[]

[Outputs]
  execute_on = 'initial timestep_end' # Limit the output to timestep end (removes initial condition)
  #checkpoint = true
    console = true  # CHANGE from false to see what's happening
  print_linear_residuals = false
   [./exodus]																																
    type = Exodus																																
    file_base = ./2D_FP/2D_FP																															
  #  interval = 1          # only output every 10 step																																
  [../]  		
    [./console]
   type = Console
 #  interval = 1
   output_file = true
   file_base = ./single_element_bound_new_opt
     all_variable_norms = true
   print_mesh_changed_info = true
  [../]			
  [pgraph]
    type = PerfGraphOutput
    execute_on = 'initial final'  # Default is "final"
    level = 2                     # Default is 1
    heaviest_branch = true        # Default is false
    heaviest_sections = 7         # Default is 0
  []
    [csv]
    type = CSV
    file_base = './2D_FP/2D_FP'
    execute_on = 'INITIAL TIMESTEP_END FAILED'
  []
[]
