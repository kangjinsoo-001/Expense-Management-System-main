class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # 복합 인덱스 추가
    add_index :expense_sheets, [:status, :year, :month], name: 'index_expense_sheets_on_status_year_month'
    add_index :expense_sheets, [:organization_id, :status], name: 'index_expense_sheets_on_org_status'
    add_index :expense_sheets, [:submitted_at], name: 'index_expense_sheets_on_submitted_at'
    
    # ExpenseItem에 대한 복합 인덱스
    add_index :expense_items, [:expense_sheet_id, :is_valid], name: 'index_expense_items_on_sheet_and_valid'
    add_index :expense_items, [:expense_code_id, :expense_date], name: 'index_expense_items_on_code_and_date'
    
    # ApprovalStep에 대한 복합 인덱스
    add_index :approval_steps, [:status, :processed_at], name: 'index_approval_steps_on_status_processed'
    
    # AuditLog에 대한 시간 기반 인덱스
    add_index :audit_logs, [:created_at], name: 'index_audit_logs_on_created_at'
  end
end
