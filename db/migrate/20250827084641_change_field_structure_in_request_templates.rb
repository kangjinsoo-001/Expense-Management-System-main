class ChangeFieldStructureInRequestTemplates < ActiveRecord::Migration[8.0]
  def change
    # 기존 필드 제거
    remove_column :request_templates, :required_fields, :text
    remove_column :request_templates, :optional_fields, :text
    
    # 새로운 fields 컬럼 추가
    add_column :request_templates, :fields, :text
  end
end
