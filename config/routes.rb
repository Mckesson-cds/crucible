Rails.application.routes.draw do
  mount MagicLamp::Genie, at: "/magic_lamp" if defined?(MagicLamp)

  resources :tests, defaults: { format: :json }, only: [ :index ]
  resources :servers, only: [ :show, :create, :update ] do
    resources :testruns, defaults: { format: :json }, only: [ :show, :create ]
    get 'conformance', defaults: { format: :json }
    get 'summary', defaults: { format: :json }
    get 'oauth_params', defaults: { format: :json }
    get 'aggregate_run', defaults: { format: :json }
    post 'oauth_params'
  end

  root to: "home#index"
  get 'servers/:server_id/past_runs', to: 'servers#past_runs'
  get 'redirect', to: 'servers#oauth_redirect'

end
