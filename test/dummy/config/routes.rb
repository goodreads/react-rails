Dummy::Application.routes.draw do
  resources :pages, only: [:show]
  resources :with_store, only: [:show] do
    get :show_ajax
  end
  resources :server_with_store, only: [:show] do
    get :show_ajax
  end
  resources :server, only: [:show] do
    collection do
      get :console_example
      get :console_example_suppressed
    end
  end
end
