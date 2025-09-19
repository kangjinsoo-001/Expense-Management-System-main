class ChangeAmountColumnsToInteger < ActiveRecord::Migration[8.0]
  def change
    # 경비 항목 금액
    change_column :expense_items, :amount, :integer, null: false
    
    # 경비 시트 총액
    change_column :expense_sheets, :total_amount, :integer, default: 0
    
    # 경비 코드 한도액
    change_column :expense_codes, :limit_amount, :integer
    
    # 코스트 센터 예산액
    change_column :cost_centers, :budget_amount, :integer
    
    # PDF 분석 결과 총액
    change_column :pdf_analysis_results, :total_amount, :integer
    
    # 트랜잭션 매칭 신뢰도 (0-100 정수로 변경)
    change_column :transaction_matches, :confidence, :integer
  end
end
