Rails.application.routes.draw do
  resources :leases do
    member do
      patch :terminate
      get :renew
    end
  end
  resources :properties
  resources :tenants
  resources :owners
  resources :invoices, only: %i[index show] do
    member do
      patch :finalize
    end
    collection do
      post :generate
    end
  end

  resources :payments, only: [:index, :new, :create]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "properties#index"
end
