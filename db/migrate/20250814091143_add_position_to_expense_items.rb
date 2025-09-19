class AddPositionToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :position, :integer
    add_index :expense_items, [:expense_sheet_id, :position]
    
    # 기존 데이터에 position 값 설정
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE expense_items 
          SET position = (
            SELECT COUNT(*) 
            FROM expense_items ei2 
            WHERE ei2.expense_sheet_id = expense_items.expense_sheet_id 
            AND ei2.id <= expense_items.id
          )
          WHERE position IS NULL
        SQL
      end
    end
  end
end
