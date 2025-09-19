class UpdateExpenseCodeValidationRules < ActiveRecord::Migration[8.0]
  def up
    # 기존 데이터를 새 구조로 변환
    ExpenseCode.find_each do |expense_code|
      if expense_code.validation_rules.present? && expense_code.validation_rules['required_fields'].is_a?(Array)
        old_fields = expense_code.validation_rules['required_fields']
        new_fields = {}
        
        old_fields.each do |field_name|
          # 기본 필드 타입 추정
          field_type = case field_name.downcase
                      when /참석자|participant/
                        'participants'
                      when /금액|amount|price|cost/
                        'amount'
                      when /날짜|date/
                        'date'
                      when /조직|organization|org/
                        'organization'
                      when /프로젝트|project/
                        'project'
                      when /장소|location|place/
                        'location'
                      when /목적|purpose/
                        'purpose'
                      else
                        'text'
                      end
          
          new_fields[field_name] = {
            'type' => field_type,
            'label' => field_name,
            'required' => true
          }
        end
        
        expense_code.update_column(:validation_rules, 
          expense_code.validation_rules.merge('required_fields' => new_fields)
        )
      end
    end
  end
  
  def down
    # 새 구조를 기존 구조로 되돌리기
    ExpenseCode.find_each do |expense_code|
      if expense_code.validation_rules.present? && expense_code.validation_rules['required_fields'].is_a?(Hash)
        field_names = expense_code.validation_rules['required_fields'].keys
        expense_code.update_column(:validation_rules,
          expense_code.validation_rules.merge('required_fields' => field_names)
        )
      end
    end
  end
end