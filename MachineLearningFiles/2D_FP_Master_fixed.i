# Master app for DRL training of cure velocity control
# This version does NOT require temp_left_bc in sub-app

[StochasticTools]
[]

[Samplers]
  [dummy]
    type = CartesianProduct
    linear_space_items = '0 0.01 1'
  []
[]

[MultiApps]
  [runner]
    type = SamplerFullSolveMultiApp
    sampler = dummy
    input_files = '2D_FP_Sub.i'
  []
[]

[Transfers]
  [nn_transfer]
    type = LibtorchNeuralNetControlTransfer
    to_multi_app = runner
    trainer_name = nn_trainer
    control_name = src_control
  []
  
  [data_transfer]
    type = MultiAppReporterTransfer
    from_multi_app = runner
    to_reporters = 'results/front_location results/front_velocity results/Tinf results/reward results/control_action results/log_prob_action'
    from_reporters = 'data_reporter/front_location:value data_reporter/front_velocity:value data_reporter/Tinf_pp:value data_reporter/reward:value data_reporter/control_action:value data_reporter/log_prob_action:value'
  []
[]

[Trainers]
  [nn_trainer]
    type = LibtorchDRLControlTrainer
    
    response = 'results/front_location results/front_velocity results/Tinf'
    control = 'results/control_action'
    log_probability = 'results/log_prob_action'
    reward = 'results/reward'
    
    num_epochs = 3000
    update_frequency = 5
    decay_factor = 0.95
    loss_print_frequency = 10
    
    critic_learning_rate = 0.002
    num_critic_neurons_per_layer = '64 32'
    
    control_learning_rate = 0.005
    num_control_neurons_per_layer = '32 16'
    
    # MATCH SUB-APP EXACTLY
    input_timesteps = 3
    response_scaling_factors = '200 100000 0.01'
    response_shift_factors = '0 0 20'
    action_standard_deviations = '0.4'
    
    standardize_advantage = true
    read_from_file = false
  []
[]

[Reporters]
  [results]
    type = ConstantReporter
    real_vector_names = 'front_location front_velocity Tinf reward control_action log_prob_action'
    real_vector_values = '0; 0; 0; 0; 0; 0'
    outputs = csv
    execute_on = timestep_begin
  []
  
  [training_progress]
    type = DRLRewardReporter
    drl_trainer_name = nn_trainer
  []
[]

[Executioner]
  type = Transient
  num_steps = 3000
[]

[Outputs]
  file_base = output/cure_train
  csv = true
  time_step_interval = 10
[]
