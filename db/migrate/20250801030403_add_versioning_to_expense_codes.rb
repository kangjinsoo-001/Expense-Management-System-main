class AddVersioningToExpenseCodes < ActiveRecord::Migration[8.0]
  def change
    # 버전 관리를 위한 컬럼 추가
    add_column :expense_codes, :version, :integer, default: 1, null: false
    add_column :expense_codes, :parent_code_id, :integer
    add_column :expense_codes, :effective_from, :date
    add_column :expense_codes, :effective_to, :date
    add_column :expense_codes, :is_current, :boolean, default: true
    
    # 인덱스 추가
    add_index :expense_codes, :parent_code_id
    add_index :expense_codes, [:code, :version], unique: true
    add_index :expense_codes, [:code, :is_current]
    add_index :expense_codes, [:effective_from, :effective_to]
    
    # 외래키 추가
    add_foreign_key :expense_codes, :expense_codes, column: :parent_code_id
    
    # 기존 모든 경비 코드의 effective_from을 오늘로 설정
    reversible do |dir|
      dir.up do
        execute "UPDATE expense_codes SET effective_from = date('now')"
      end
    end
  end
end
