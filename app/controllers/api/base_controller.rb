module Api
  class BaseController < ApplicationController
    # API 컨트롤러 공통 기능
    protect_from_forgery with: :null_session
    
    private
    
    def render_success(data = {}, message = nil)
      response = { success: true }
      response[:message] = message if message
      response[:data] = data if data.present?
      render json: response
    end
    
    def render_error(message, status = :unprocessable_entity)
      render json: { success: false, error: message }, status: status
    end
  end
end