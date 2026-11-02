Rails.application.routes.draw do
  root "pages#home"
  resources :routes, only: :show, param: :route_id
  # The timetable page of a route: the server hands over the measured data,
  # the browser lays the timetable out, so there is only GET.
  get "routes/:route_id/timetable", to: "timetables#show", as: :route_timetable
  # The day dispatch page of a route: the day lives in the browser that keeps
  # it, so there is only GET.
  get "routes/:route_id/dispatch", to: "day_dispatches#show", as: :route_dispatch
  # The printed months of a route.
  get "routes/:route_id/cards", to: "route_cards#index", as: :route_cards
  # The printed month card of a route: one address per month, so that it can be cited.
  get "routes/:route_id/cards/:month.pdf", to: "route_cards#download", as: :route_card_pdf, format: false
  # The month card of a route, the page a month's card is printed from.
  get "routes/:route_id/cards/:month", to: "route_cards#show", as: :route_card
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
