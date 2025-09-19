class RemoveApprovalRelatedColumns < ActiveRecord::Migration[8.0]
  def change
    # expense_codes 테이블에서 승인 프로세스 설정 컬럼 제거
    remove_column :expense_codes, :approval_process_config, :json
    
    # 승인 관련 테이블 삭제
    drop_table :expense_item_approvals
    drop_table :approval_steps
    drop_table :approval_template_steps
    drop_table :approval_templates
    drop_table :approval_flows
  end
end
