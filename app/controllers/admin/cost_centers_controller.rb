module Admin
  class CostCentersController < Admin::BaseController
    before_action :set_cost_center, only: %i[show edit update destroy]

    def index
      @cost_centers = CostCenter.includes(:manager, :organization)
                               .order(:code)
    end

    def show
    end

    def new
      @cost_center = CostCenter.new
    end

    def edit
    end

    def create
      @cost_center = CostCenter.new(cost_center_params)
      
      if @cost_center.save
        respond_to do |format|
          format.html { redirect_to admin_cost_centers_path, notice: 'Cost Center가 생성되었습니다.' }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend('cost_centers', 
                partial: 'admin/cost_centers/cost_center',
                locals: { cost_center: @cost_center }),
              turbo_stream.replace('new_cost_center_modal', ''),
              turbo_stream.replace('flash', partial: 'shared/flash')
            ]
          end
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @cost_center.update(cost_center_params)
        respond_to do |format|
          format.html { redirect_to admin_cost_centers_path, notice: 'Cost Center가 수정되었습니다.' }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(@cost_center, 
                partial: 'admin/cost_centers/cost_center',
                locals: { cost_center: @cost_center }),
              turbo_stream.replace('modal', ''),
              turbo_stream.replace('flash', partial: 'shared/flash')
            ]
          end
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @cost_center.destroy

      respond_to do |format|
        format.html { redirect_to admin_cost_centers_path, notice: 'Cost Center가 삭제되었습니다.' }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(@cost_center),
            turbo_stream.replace('flash', partial: 'shared/flash')
          ]
        end
      end
    end

    private

    def set_cost_center
      @cost_center = CostCenter.find(params[:id])
    end

    def cost_center_params
      params.require(:cost_center).permit(
        :code, :name, :description, :manager_id,
        :organization_id, :budget_amount, :fiscal_year, :active
      )
    end
  end
end