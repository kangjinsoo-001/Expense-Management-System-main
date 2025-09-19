Rails.application.routes.draw do
  # 신청서 작성 (사용자)
  resources :request_forms do
    collection do
      get :select_category
      get 'select_template/:category_id', to: 'request_forms#select_template', as: :select_template
    end
    member do
      patch :cancel_approval
    end
  end
  
  # 신청서 템플릿 결재선 검증
  resources :request_templates, only: [] do
    member do
      post :validate_approval_line
    end
  end
  # 회의실 예약
  resources :room_reservations do
    collection do
      get :calendar
    end
  end
  
  resources :organization_expenses, only: [:index, :show]
  
  
  resources :approvals, only: [:index, :show] do
    member do
      post :approve
      post :reject
    end
    collection do
      post :batch_approve
    end
  end
  resources :approval_lines do
    member do
      patch :toggle_active
      get :preview
    end
    collection do
      post :reorder
    end
  end
  
  namespace :admin do
    root 'menu#index'
    get 'menu', to: 'menu#index'
    
    # 경비 마감 대시보드
    namespace :closing do
      resources :dashboard, only: [:index] do
        collection do
          get :organization_members
          post :batch_close
          get :export
        end
      end
    end
    
    # 회의실 관리
    resources :rooms
    resources :room_categories do
      member do
        patch :toggle_active
      end
      collection do
        post :update_order
      end
    end
    
    # 신청서 관리
    resources :request_categories do
      member do
        patch :toggle_active
      end
      collection do
        post :update_order
      end
    end
    
    resources :request_templates do
      member do
        patch :toggle_active
        post :duplicate
        post :add_approval_rule
        delete 'remove_approval_rule/:rule_id', to: 'request_templates#remove_approval_rule', as: :remove_approval_rule
        patch 'toggle_approval_rule/:rule_id', to: 'request_templates#toggle_approval_rule', as: :toggle_approval_rule
        patch :reorder_approval_rules
      end
      resources :request_template_fields do
        collection do
          post :update_order
        end
      end
    end
    
    resources :gemini_metrics, only: [:index] do
      collection do
        post :reset
      end
    end
    
    resources :approver_groups do
      member do
        patch :toggle_active
        post :add_member
        delete :remove_member
        patch :update_members
      end
    end
    
    resources :expense_codes do
      member do
        post :add_approval_rule
        delete 'remove_approval_rule/:rule_id', to: 'expense_codes#remove_approval_rule', as: :remove_approval_rule
        patch 'update_approval_rule_order/:rule_id', to: 'expense_codes#update_approval_rule_order', as: :update_approval_rule_order
        patch :update_approval_rules_order
      end
    end
    resources :cost_centers
    resources :expense_sheets, only: [:index, :show] do
      collection do
        get 'export_all'
      end
    end
    
    resources :attachment_requirements do
      member do
        patch :toggle_active
        patch :update_position
      end
    end
    
    resources :expense_sheet_approval_rules do
      member do
        patch :toggle_active
      end
    end
    
    resources :reports do
      member do
        get 'download'
        get 'status'
      end
      collection do
        post 'export'
      end
    end
  end

  namespace :api do
    resources :expense_codes, only: [] do
      member do
        get 'fields'
        post 'validate'
      end
    end
    
    resources :users, only: [] do
      collection do
        get 'search'
        get 'all'
      end
    end
    
    resources :organizations, only: [] do
      collection do
        get 'search'
        get 'all'
      end
    end
  end
  
  resources :expense_codes, only: [] do
    member do
      get 'custom_fields'
    end
  end

  # 첨부 파일 업로드 (경비 항목 없이도 접근 가능)
  resources :expense_attachments, only: [:destroy] do
    collection do
      get :upload_modal
      post :upload_and_extract
    end
    member do
      get :status
    end
  end
  
  # Root path
  root "home#index"
  
  # Authentication routes
  get "/login", to: "sessions#new", as: :login
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout
  
  resources :users
  resources :organizations do
    member do
      post 'assign_manager'
      delete 'remove_manager'
      get 'manage_users'
      post 'add_user'
      delete 'remove_user'
    end
  end

  resources :expense_sheets do
    collection do
      get 'list'
      get 'check_month_status'
    end
    member do
      # submit 페이지 제거, confirm_submit는 유지 (index에서 직접 제출)
      post 'confirm_submit'
      post 'cancel_submission'
      get 'submission_details'  # 제출 내역 확인
      get 'validate_items'
      post 'validate_sheet'
      post 'validate_all_items'
      post 'validate_with_ai'
      post 'validate_step'
      get 'validation_result'
      get 'validation_history'
      post 'attach_pdf'
      delete 'delete_pdf_attachment'
      get 'export'
      post 'sort_items'
      post 'bulk_sort_items'
    end
    resources :expense_sheet_attachments do
      member do
        get :status
        post :analyze
      end
    end
    resources :expense_items, except: [:index, :show] do
      collection do
        get '/', to: redirect('/expense_sheets')
        post 'validate_approval_line'
        post 'validate_field'
        post 'validate_all'
        post 'save_draft'
        get 'recent_submission'
      end
      member do
        post 'save_draft'
        patch 'save_draft'
        get 'restore_draft'
        post 'restore_draft'
        delete 'delete_draft'
        post 'cancel_approval'
      end
      resources :expense_attachments, only: [:index, :create, :show, :destroy] do
        member do
          get :status
          post :extract_text
          post :summarize
          get :summary_html
        end
      end
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
  # root "posts#index"
end
