################################################################################
## DRL Trainer for Frontal Polymerization Velocity Control
## Trains neural network to maintain target nozzle-front distance
################################################################################

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
    input_files = 'frontal_polymerization_drl_sub.i'
  []
[]

[Transfers]
  # Transfer neural network from trainer to sub-app
  [nn_transfer]
    type = LibtorchNeuralNetControlTransfer
    to_multi_app = runner
    trainer_name = velocity_nn_trainer
    control_name = drl_velocity_control
  []
  
  # Transfer results from sub-app back to trainer
  [data_transfer]
    type = MultiAppReporterTransfer
    from_multi_app = runner
    to_reporters = 'results/distance results/front_vel results/print_vel results/reward results/action results/log_prob'
    from_reporters = 'training_data/front_nozzle_distance:value training_data/front_velocity:value training_data/print_velocity:value training_data/reward:value training_data/velocity_action:value training_data/log_prob_velocity:value'
  []
[]

[Trainers]
  [velocity_nn_trainer]
    type = LibtorchDRLControlTrainer
    
    # State observations (responses) - what the agent observes
    response = 'results/distance results/front_vel results/print_vel'
    
    # Control actions - what the agent outputs
    control = 'results/action'
    
    # Log probability of actions (for policy gradient)
    log_probability = 'results/log_prob'
    
    # Reward signal
    reward = 'results/reward'
    
    # Training hyperparameters
    num_epochs = 1000                    # Total number of training episodes
    update_frequency = 10                # Update networks every 10 episodes
    decay_factor = 0.99                  # Discount factor for future rewards (gamma)
    loss_print_frequency = 10            # Print loss every 10 updates
    
    # Critic network (value function estimator)
    critic_learning_rate = 0.0001
    num_critic_neurons_per_layer = '64 32'  # Two hidden layers: 64, 32 neurons
    
    # Policy network (action selector)
    control_learning_rate = 0.0005
    num_control_neurons_per_layer = '32 16'  # Two hidden layers: 32, 16 neurons
    
    # Input processing (must match sub-app settings)
    input_timesteps = 3
    response_scaling_factors = '0.01 0.01 0.1'
    response_shift_factors = '0.0 0.0 0.0'
    action_standard_deviations = '0.01'
    
    # Training options
    standardize_advantage = true         # Normalize advantage for stable training
    read_from_file = false              # Set true to resume from checkpoint
    # control_net_file = 'trained_velocity_policy.net'  # Uncomment to resume
    # critic_net_file = 'trained_velocity_critic.net'   # Uncomment to resume
    
  []
[]

[Reporters]
  # Storage for results from sub-app
  [results]
    type = ConstantReporter
    real_vector_names = 'distance front_vel print_vel reward action log_prob'
    real_vector_values = '0; 0; 0; 0; 0; 0'
    outputs = csv
    execute_on = timestep_begin
  []
  
  # Track cumulative reward over training
  [reward_tracker]
    type = DRLRewardReporter
    drl_trainer_name = velocity_nn_trainer
  []
[]

[Executioner]
  type = Transient
  num_steps = 600   # Number of training episodes (can increase for better training)
[]

[Outputs]
  file_base = output_fp_second/drl_training
  csv = true
  time_step_interval = 1 # Save every 10 episodes
[]
