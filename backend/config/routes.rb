Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "chat", to: "chats#create"
    post "search", to: "searches#create"
    get "health", to: "health#show"
  end
end
