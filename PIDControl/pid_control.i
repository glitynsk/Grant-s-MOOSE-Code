################################################################################
## PID-Controlled Frontal Polymerization Simulation
## Uses MOOSE built-in PID control instead of external MATLAB loop
################################################################################
##
## CONTROL OBJECTIVE:
##   Maintain constant distance (dmax = 7 mm) between nozzle and polymerization front
##
##       Nozzle (controlled)              Front (propagating)
##           ●─────────────────────────────────→ ◆
##           |←────── target distance ────────→|
##                        (7 mm)
##
################################################################################
## PID VELOCITY UPDATE FORMULA (from MOOSE PIDTransientControl):
##
##   delta = current_distance - target_distance   (NOTE: NOT target - current!)
##
##   velocity_new = velocity_old + K_p * delta
##                               + K_i * integral(delta * dt)
##                               + K_d * d(delta)/dt
##
##   Then clamp: velocity_new = clamp(velocity_new, min_velocity, max_velocity)
##
################################################################################
## EXAMPLE CALCULATION:
##
##   Given: current_distance = 0.005 m (nozzle too close to front)
##          target_distance  = 0.007 m
##          velocity_old     = 0.001 m/s
##          K_p = -3.0, K_i = 0, K_d = 0
##
##   Step 1: delta = 0.005 - 0.007 = -0.002 (negative because distance < target)
##
##   Step 2: velocity_change = K_p * delta = (-3.0) * (-0.002) = +0.006
##
##   Step 3: velocity_new = 0.001 + 0.006 = 0.007 m/s
##
##   Result: Velocity INCREASES -> nozzle speeds up -> distance increases -> OK!
##
################################################################################
## WHY K_proportional IS NEGATIVE:
##
##   MOOSE calculates: delta = measured - target (not target - measured)
##
##   Case 1: Distance too SMALL (need to speed up)
##     delta = small - target = NEGATIVE
##     K_p * delta = (-3.0) * (negative) = POSITIVE -> velocity increases ✓
##
##   Case 2: Distance too LARGE (need to slow down)
##     delta = large - target = POSITIVE
##     K_p * delta = (-3.0) * (positive) = NEGATIVE -> velocity decreases ✓
##
################################################################################
## CONTROL LOOP TIMELINE (each timestep):
##
##   TIMESTEP_BEGIN:
##     1. PIDTransientControl updates velocity_pp based on previous distance
##     2. TimeIntegratedPostprocessor integrates: nozzle_x = 0.007 + integral(velocity_pp)
##     3. ParsedAux computes distance field from nozzle
##     4. MeshModifier activates elements near nozzle
##
##   SOLVE:
##     5. Solve Temperature and Cure equations
##
##   TIMESTEP_END:
##     6. FindValueOnLine locates front (where Cure = 0.5)
##     7. DifferencePostprocessor computes: distance = nozzle_x - front_location
##     8. Output to CSV
##
##   -> Next timestep (back to step 1)
##
################################################################################

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    ymin = 0.0
    xmax = 0.02
    ymax = 0.0016
    nx = 500
    ny = 40
  []
  [ink]
    type = SubdomainBoundingBoxGenerator
    input = 'gen'
    block_id = 1
    bottom_left = '0 0 0'
    top_right = '0.007 0.0016 0'
  []
  [air]
    type = SubdomainBoundingBoxGenerator
    input = 'ink'
    block_id = 0
    bottom_left = '0.007 0 0'
    top_right = '0.02 0.0016 0'
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
  [convective_bottom]
    type = ConvectiveFluxFunction
    boundary = bottom
    variable = Temperature
    coefficient = 20
    T_infinity = 20
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
  # PID-controlled velocity (Receiver allows PID to modify this)
  [velocity_pp]
    type = Receiver
    default = 0.001
  []

  # Integrate velocity to get nozzle displacement from initial position
  [nozzle_displacement]
    type = TimeIntegratedPostprocessor
    value = velocity_pp
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # Nozzle position = initial (0.007) + displacement
  [nozzle_x_value]
    type = ParsedPostprocessor
    expression = '0.007 + nozzle_displacement'
    pp_names = 'nozzle_displacement'
    execute_on = 'INITIAL TIMESTEP_BEGIN TIMESTEP_END'
  []

  # Find front location where Cure = 0.5 along centerline
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

  # Distance = nozzle - front
  [front_nozzle_distance]
    type = DifferencePostprocessor
    value1 = nozzle_x_value
    value2 = front_location
    execute_on = 'INITIAL TIMESTEP_END'
  []

  # Front velocity (change in front_location per timestep)
  [front_velocity]
    type = ChangeOverTimePostprocessor
    postprocessor = front_location
    change_with_respect_to_initial = false
    execute_on = 'TIMESTEP_END'
  []

  # Print velocity (same as velocity_pp, but for clarity in output)
  [print_velocity]
    type = ScalePostprocessor
    value = velocity_pp
    scaling_factor = 1.0
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
    execute_on = 'TIMESTEP_BEGIN'
  []
[]

[Controls]
  [pid_velocity]
    type = PIDTransientControl
    postprocessor = front_nozzle_distance
    target = 0.007                    # dmax - target distance
    parameter_pp = 'velocity_pp'
    K_proportional = -1.0             # Negative because delta = current - target
    K_integral = 0.0
    K_derivative = 0.0
    minimum_output_value = 0.0001     # Prevent negative velocity
    maximum_output_value = 0.1       # Limit maximum velocity
    execute_on = 'TIMESTEP_BEGIN'
  []

  # Disable left BC after initial heating
  [bcs]
    type = TimePeriod
    disable_objects = 'BCs::temp_left'
    start_time = 1
    execute_on = 'initial timestep_begin'
  []
[]

[Executioner]
  automatic_scaling = true
  type = Transient
  num_steps = 80000
  nl_rel_tol = 1e-7
  end_time = 20
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
    file_base = pid_control/pid_control
    execute_on = 'initial timestep_end'
  []
  [csv]
    type = CSV
    file_base = pid_control/pid_data
    execute_on = 'initial timestep_end'
  []
[]
