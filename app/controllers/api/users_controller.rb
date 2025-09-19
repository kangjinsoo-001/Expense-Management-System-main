module Api
  class UsersController < ::ApplicationController
    before_action :require_login

    def search
      query = params[:q]
      
      if query.present? && query.length >= 2
        users = User.where('name LIKE ? OR email LIKE ?', "%#{query}%", "%#{query}%")
                   .includes(:organization)
                   .limit(10)
        
        render json: users.map { |user|
          {
            id: user.id,
            name: user.name,
            email: user.email,
            department: user.organization&.name
          }
        }
      else
        render json: []
      end
    end

    def all
      # 캐시하여 성능 최적화
      users = Rails.cache.fetch("api/users/all", expires_in: 1.hour) do
        User.includes(:organization).map do |user|
          {
            id: user.id,
            name: user.name,
            email: user.email,
            department: user.organization&.name
          }
        end
      end
      
      render json: users
    end
  end
end