# frozen_string_literal: true

Rails.application.routes.draw do
  resources :leases do
    resources :invoice_templates, except: %i[index show] do
      collection do
        # PATCH because the persisted-template form submits with _method=patch
        match :preview, via: %i[post patch]
      end
    end
    resources :reminder_steps, except: %i[index show]
  end
  resources :invoice_notifications, only: %i[index] do
    member do
      patch :approve
      patch :cancel
      patch :retry
    end
    collection do
      patch :approve_all
    end
  end
  resources :payments, only: %i[index show new create edit update destroy]
  resources :properties
  resources :tenants
  resources :owners
  resources :invoices, except: %i[destroy] do
    collection do
      get :audit
    end
  end
  resources :users
  resources :user_associations, only: %i[create destroy]
  resources :api_tokens, only: %i[create destroy]

  get "/login", to: "sessions#new", as: :login
  match "/auth/:provider/callback", to: "sessions#create", via: %i[get post]
  delete "/logout", to: "sessions#destroy", as: :logout

  resources :versions, only: %i[index show destroy]
  resources :reports, only: [:index] do
    collection do
      get :revenue
      get :outstanding
      get :taxes
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # /up proves the process booted and nothing more — it never touches the
  # database. These two say whether the release can actually serve; see
  # HealthController. They are exempt from host authorization and the
  # http-to-https redirect in production via config.x.health_check_paths, so
  # that a check reaching the container directly (Dokku, bin/verify-release)
  # is answered rather than refused.
  get "health/ready" => "health#ready", as: :health_ready
  get "health/workers" => "health#workers", as: :health_workers

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "reports#index"
end
