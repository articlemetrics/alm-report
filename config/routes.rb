AlmReport::Application.routes.draw do

  root :to => "home#index"
  
  match "/add-articles" => "home#add_articles"
  
  match "/update-session" => "home#update_session"
  
  match "/start-over" => "home#start_over"
  
  match "/preview-list" => "home#preview_list"

  match "/reports/generate" => "reports#generate"
  
  match "/reports/metrics" => "reports#metrics"
  
  match "/reports/visualizations" => "reports#visualizations"

end
