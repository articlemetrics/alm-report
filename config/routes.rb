AlmReport::Application.routes.draw do

  root :to => "home#index"
  
  match "/add-articles" => "home#add_articles"
  
  match "/update-session" => "home#update_session"
  
  match "/select-all-search-results" => "home#select_all_search_results"
  
  match "/start-over" => "home#start_over"
  
  match "/preview-list" => "home#preview_list"

  match "/reports/generate" => "reports#generate"
  
  match "/reports/metrics" => "reports#metrics"
  
  match "/reports/visualizations" => "reports#visualizations"
  
  match "/id/" => "id#index"

  match "/about" => "static_pages#about"
  match "/privacy_policy" => "static_pages#privacy_policy"
  match "/terms_of_use" => "static_pages#terms_of_use"

end
