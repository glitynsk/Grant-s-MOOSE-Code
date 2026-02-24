# ============================
# DRL TRAINER INPUT FILE
# ============================
[StochasticTools]
[]

# ----------------------------
# Sampler (episodes / rollouts)
# ----------------------------
[Samplers]
  [episode_sampler]
    type = CartesianProduct
    linear_space_items = '0 1 1'
  []
[]

# ----------------------------
# MultiApp: runs the environment
# ----------------------------
[MultiApps]
  [runner]
    type = SamplerFullSolveMultiApp
    sampler = episode_sampler
    input_files = 'pid_control_interval_sub.i'
  []
[]

# ----------------------------
# Transfers
# ----------------------------

# ----------------------------
# DRL Trainer
# ----------------------------
[Trainers]
  [velocity_trainer]
    type = LibtorchDRLControlTrainer
    
    # CHANGED: Must match control - now expects 2 responses
    response = 'results/front_distance results/front_loc'
    control = 'results/velocity'
    log_probability = 'results/log_prob'
    reward = 'results/reward'
    
    num_epochs = 1000
    update_frequency = 10
    decay_factor = 0.95
    loss_print_frequency = 10
    
    critic_learning_rate = 1e-4
    num_critic_neurons_per_layer = '32 16'
    
    control_learning_rate = 5e-4
    num_control_neurons_per_layer = '16 8'
    
    input_timesteps = 1
    # CHANGED: Two response normalization values
    response_scaling_factors = '100 1000'
    response_shift_factors = '0.007 0.001'
    action_standard_deviations = '0.0005'
    
    standardize_advantage = true
    read_from_file = false
  []
[]
# ----------------------------
# Trainer-side reporters
# ----------------------------
[Reporters]
  [results]
    type = ConstantReporter
    real_vector_names = 'front_distance front_loc reward velocity log_prob'  # CHANGED
    real_vector_values = '0; 0; 0; 0; 0'  # CHANGED: Added 0 for front_loc
    outputs = csv
    execute_on = timestep_begin
  []
  
  [reward]
    type = DRLRewardReporter
    drl_trainer_name = velocity_trainer
  []
[]

[Transfers]
  [nn_transfer]
    type = LibtorchNeuralNetControlTransfer
    to_multi_app = runner
    trainer_name = velocity_trainer
    control_name = velocity_control
  []
  
  [rollout_transfer]
    type = MultiAppReporterTransfer
    from_multi_app = runner
    # CHANGED: Add front_location
    to_reporters = 'results/front_distance results/front_loc results/reward results/velocity results/log_prob'
    from_reporters = 'control_reporter/front_nozzle_distance_tend:value control_reporter/front_location:value control_reporter/reward:value control_reporter/velocity_action:value control_reporter/velocity_log_prob:value'
  []
[]

# ----------------------------
# Executioner (trainer loop)
# ----------------------------
[Executioner]
  type = Transient
  num_steps = 500
[]

# ----------------------------
# Outputs
# ----------------------------
[Outputs]
  file_base = output/nozzle_velocity_training
  csv = true
  time_step_interval = 10
[]
