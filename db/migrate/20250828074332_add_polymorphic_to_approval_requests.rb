class AddPolymorphicToApprovalRequests < ActiveRecord::Migration[8.0]
  def change
    # Polymorphic 컬럼 추가
    add_column :approval_requests, :approvable_type, :string
    add_column :approval_requests, :approvable_id, :integer
    
    # 인덱스 추가
    add_index :approval_requests, [:approvable_type, :approvable_id], name: 'index_approval_requests_on_approvable'
    add_index :approval_requests, :approvable_type
    
    # 기존 expense_item_id 데이터를 polymorphic으로 마이그레이션
    reversible do |dir|
      dir.up do
        # 기존 데이터를 polymorphic 형식으로 변환
        execute <<-SQL
          UPDATE approval_requests 
          SET approvable_type = 'ExpenseItem', 
              approvable_id = expense_item_id
          WHERE expense_item_id IS NOT NULL
        SQL
        
        # 기존 unique 인덱스 제거
        remove_index :approval_requests, name: "index_approval_requests_on_expense_item_id"
        
        # expense_item_id 컬럼을 nullable로 변경
        change_column_null :approval_requests, :expense_item_id, true
        
        # 새로운 unique 인덱스 추가 (polymorphic)
        add_index :approval_requests, [:approvable_type, :approvable_id], 
                  unique: true, 
                  name: 'index_approval_requests_on_approvable_unique'
      end
      
      dir.down do
        # polymorphic unique 인덱스 제거
        remove_index :approval_requests, name: 'index_approval_requests_on_approvable_unique'
        
        # expense_item_id 컬럼을 다시 not null로 변경
        change_column_null :approval_requests, :expense_item_id, false
        
        # 기존 unique 인덱스 복원
        add_index :approval_requests, :expense_item_id, unique: true, name: "index_approval_requests_on_expense_item_id"
        
        # polymorphic 데이터를 다시 expense_item_id로 복원
        execute <<-SQL
          UPDATE approval_requests 
          SET expense_item_id = approvable_id
          WHERE approvable_type = 'ExpenseItem' AND approvable_id IS NOT NULL
        SQL
      end
    end
  end
end
