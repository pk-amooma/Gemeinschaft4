Gemeinschaft4::Application.routes.draw do
	
	get "setup/index"
	get "setup/create"
	get "setup/new"
	
	match '/auth/:provider/callback' => 'authentications#create'
	resources :authentications      , :only => [ :index, :create, :destroy ]
	
	devise_for :users
	
	resources :sip_accounts do
		resources :extensions
	end
	resources :sip_phones
	resources :sip_servers          , :only => [ :index, :show, :new, :create, :destroy ]
	resources :sip_proxies          , :only => [ :index, :show, :new, :create, :destroy ]
	resources :nodes                , :only => [ :index, :show ] # for now
	# Remember to comment-in the tests in test/functional/nodes_controller_test.rb
	# once you enable more routes for the nodes.
	resources :voicemail_servers
	resources :extensions
	
	resources :admin                , :only => [ :index ]
	
	resources :kamailio             , :only => [ :index ], :format => 'txt'
	
	resources :subscribers          , :only => [ :index, :show ]
	
	match '/freeswitch-directory-entries/search',
		:via        => [ :get, :post ],
		:controller => :freeswitch_directory_entries,
		:action     => 'search',
		:format     => :'xml'
	
	match '/freeswitch-call-processing/actions',
		:via        => [ :get, :post ],
		:controller => :freeswitch_call_processing,
		:action     => 'actions',
		:format     => :'xml'
	
	namespace :admin do
		resources :users
		resources :setup
	end
	
	# Cantina
	resources :reboot_requests, :only => [:index, :show, :create, :new ]
	
	resources :manufacturer_snom    , :only => [ :index ]
	resources :manufacturer_aastra  , :only => [ :index ]
	resources :manufacturer_tiptel  , :only => [ :index ]
	
	match 'settings-:mac_address' => 'manufacturer_snom#show',
		:format => 'xml',
		:constraints => { :mac_address => /000413.*/ } 
	
	resources :provisioning_log_entries, :only => [ :index, :show ]
	resources :phone_model_mac_addresses
	match 'phones/:id/reboot' => 'phones#reboot', :as => :phone_reboot
	
	# http://guides.rubyonrails.org/routing.html#nested-resources
	resources :phones do
		resources :sip_accounts
	end
	resources :sip_accounts do
		resources :phone_keys
		
	end
	
	resources :codecs
	
	resources :sip_account_codecs
	
	resources :phone_key_function_definitions
	
	resources :phone_model_keys
	
	resources :manufacturers do
		resources :phone_models
	end
	
	resources :phone_models do
		resources :phones
	end
	
	# The priority is based upon order of creation:
	# first created -> highest priority.
	
	# Sample of regular route:
	#	match 'products/:id' => 'catalog#view'
	# Keep in mind you can assign values other than :controller and :action
	
	# Sample of named route:
	#	match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
	# This route can be invoked with purchase_url(:id => product.id)
	
	# Sample resource route (maps HTTP verbs to controller actions automatically):
	#	resources :products
	
	# Sample resource route with options:
	#resources :products do
	#	member do
	#		get 'short'
	#		post 'toggle'
	#	end
	#	
	#	collection do
	#		get 'sold'
	#	end
	#end
	
	# Sample resource route with sub-resources:
	#resources :products do
	#	resources :comments, :sales
	#	resource :seller
	#end
	
	# Sample resource route with more complex sub-resources
	#resources :products do
	#	resources :comments
	#	resources :sales do
	#		get 'recent', :on => :collection
	#	end
	#end
	
	# Sample resource route within a namespace:
	#namespace :admin do
	#	# Directs /admin/products/* to Admin::ProductsController
	#	# (app/controllers/admin/products_controller.rb)
	#	resources :products
	#end
	
	# You can have the root of your site routed with "root"
	# just remember to delete public/index.html.
	# root :to => "welcome#index"
	
	root :to => 'admin#index'
	
	
	# See how all your routes lay out with "rake routes"
	
	# This is a legacy wild controller route that's not recommended for RESTful applications.
	# Note: This route will make all actions in every controller accessible via GET requests.
	# match ':controller(/:action(/:id(.:format)))'
end
