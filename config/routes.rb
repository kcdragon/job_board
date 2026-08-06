JobBoard::Engine.routes.draw do
  root to: "queues#index"

  get "queues", to: "queues#index", as: :queues
  scope "queues/:queue_name", constraints: { queue_name: /[^\/]+/ }, format: false do
    post   "pause", to: "queues/pauses#create", as: :queue_pause
    delete "pause", to: "queues/pauses#destroy"
  end

  resources :jobs, only: [:index, :show] do
    member do
      post :retry
      delete :discard
    end
    collection do
      post :retry_all
      post :discard_all
    end
  end

  resources :processes, only: :index
  resources :recurring_tasks, only: :index
  scope "recurring_tasks/:key", constraints: { key: /[^\/]+/ }, format: false do
    post "run", to: "recurring_tasks/runs#create", as: :recurring_task_run
  end

  get "assets/:name", to: "assets#show", as: :static_asset, constraints: { name: /[a-z_]+\.(css|js)/ }
end
