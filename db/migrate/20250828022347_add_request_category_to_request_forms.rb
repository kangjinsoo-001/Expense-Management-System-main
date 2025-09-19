class AddRequestCategoryToRequestForms < ActiveRecord::Migration[8.0]
  def change
    add_reference :request_forms, :request_category, null: true, foreign_key: true
    
    # 기존 데이터가 있다면 템플릿의 카테고리로 업데이트
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE request_forms 
          SET request_category_id = (
            SELECT request_category_id 
            FROM request_templates 
            WHERE request_templates.id = request_forms.request_template_id
          )
        SQL
        
        # 이제 null: false 제약 추가
        change_column_null :request_forms, :request_category_id, false
      end
    end
  end
end
