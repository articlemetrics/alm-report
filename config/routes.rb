AlmReport::Application.routes.draw do

#  get "home/index"

  root :to => "home#index"
  
  match "/add-articles" => "home#add_articles"

end
