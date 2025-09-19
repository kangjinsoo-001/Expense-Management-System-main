class ChangeLimitAmountToStringInExpenseCodes < ActiveRecord::Migration[8.0]
  def up
    # 기존 데이터를 임시 컬럼에 백업
    add_column :expense_codes, :limit_amount_temp, :integer
    
    # 기존 데이터 복사
    ExpenseCode.reset_column_information
    ExpenseCode.update_all("limit_amount_temp = limit_amount")
    
    # 컬럼 타입 변경
    change_column :expense_codes, :limit_amount, :string
    
    # 기존 숫자 데이터를 문자열로 변환
    ExpenseCode.reset_column_information
    ExpenseCode.find_each do |expense_code|
      if expense_code.limit_amount_temp.present?
        expense_code.update_column(:limit_amount, expense_code.limit_amount_temp.to_s)
      end
    end
    
    # 임시 컬럼 제거
    remove_column :expense_codes, :limit_amount_temp
  end
  
  def down
    # 문자열을 다시 정수로 변환 (수식이 아닌 경우만)
    add_column :expense_codes, :limit_amount_temp, :string
    
    ExpenseCode.reset_column_information
    ExpenseCode.update_all("limit_amount_temp = limit_amount")
    
    change_column :expense_codes, :limit_amount, :integer
    
    ExpenseCode.reset_column_information
    ExpenseCode.find_each do |expense_code|
      if expense_code.limit_amount_temp.present?
        # 숫자로만 이루어진 경우만 변환
        if expense_code.limit_amount_temp.match?(/\A\d+\z/)
          expense_code.update_column(:limit_amount, expense_code.limit_amount_temp.to_i)
        else
          expense_code.update_column(:limit_amount, nil)
        end
      end
    end
    
    remove_column :expense_codes, :limit_amount_temp
  end
end
