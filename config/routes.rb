# frozen_string_literal: true

Rails.application.routes.draw do
  resources :leases
  resources :payments, only: %i[index show new create update]
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

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "reports#index"
end
