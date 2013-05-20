AlmReport::Application.routes.draw do

  root :to => "home#index"
  
  match "/add-articles" => "home#add_articles"
  match "/update-session" => "home#update_session"
  match "/select-all-search-results" => "home#select_all_search_results"
  match "/start-over" => "home#start_over"
  match "/preview-list" => "home#preview_list"

  match "/reports/generate" => "reports#generate"
  match '/reports/:action/:id', :controller => "reports"

  match "/id" => "id#index", :via => :get
  match "/id" => "id#save", :via => :post
  
  match "/upload" => "id#upload", :via => :get
  match "/upload" => "id#process_upload", :via => :post

  match "/about" => "static_pages#about"
  match "/privacy_policy" => "static_pages#privacy_policy"
  match "/terms_of_use" => "static_pages#terms_of_use"
  match "/samples" => "static_pages#samples"

end
