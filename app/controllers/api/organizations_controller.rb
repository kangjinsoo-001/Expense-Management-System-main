module Api
  class OrganizationsController < ::ApplicationController
    before_action :require_login

    def search
      query = params[:q]
      
      if query.present? && query.length >= 2
        organizations = Organization.where('name LIKE ? OR code LIKE ?', "%#{query}%", "%#{query}%")
                                  .limit(10)
        
        render json: organizations.map { |org|
          {
            id: org.id,
            name: org.name,
            code: org.code,
            department: org.full_path
          }
        }
      else
        render json: []
      end
    end

    def all
      # 캐시하여 성능 최적화
      organizations = Rails.cache.fetch("api/organizations/all", expires_in: 1.hour) do
        Organization.all.map do |org|
          {
            id: org.id,
            name: org.name,
            code: org.code,
            department: org.full_path
          }
        end
      end
      
      render json: organizations
    end
  end
end