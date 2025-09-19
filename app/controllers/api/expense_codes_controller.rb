class Api::ExpenseCodesController < ApplicationController
  before_action :require_login
  before_action :set_expense_code, only: [:fields, :validate]

  def fields
    required_fields = @expense_code.validation_rules['required_fields'] || []
    render json: {
      expense_code: @expense_code.as_json(only: [:id, :code, :name, :description, :limit_amount]),
      required_fields: required_fields,
      field_definitions: field_definitions_for(@expense_code),
      auto_approval_conditions: @expense_code.validation_rules['auto_approval_conditions'] || {},
      existing_custom_fields: params[:existing_custom_fields] || {}
    }
  end

  def validate
    expense_item = build_expense_item_for_validation
    engine = ExpenseValidation::RuleEngine.new(@expense_code)
    result = engine.validate(expense_item)

    render json: {
      valid: result.valid?,
      errors: result.errors,
      warnings: []  # 향후 경고 기능 추가 시 구현
    }
  end

  private

  def set_expense_code
    @expense_code = ExpenseCode.find(params[:id])
  end

  def build_expense_item_for_validation
    ExpenseItem.new(
      expense_code: @expense_code,
      amount: params[:amount],
      expense_date: params[:expense_date],
      description: params[:description],
      custom_fields: params[:custom_fields] || {},
      vendor_name: params[:vendor_name],
      receipt_number: params[:receipt_number]
    )
  end

  def field_definitions_for(expense_code)
    # 경비 코드별 추가 필드 정의
    required_fields = expense_code.validation_rules['required_fields'] || {}
    
    field_definitions = []
    
    # 새로운 해시 구조 처리
    if required_fields.is_a?(Hash)
      required_fields.each do |field_key, field_config|
        field_definitions << {
          name: field_key,
          label: field_config['label'] || field_key,
          type: field_config['type'] || 'text',
          required: field_config['required'] != false
        }
      end
    else
      # 이전 배열 구조 호환성 유지
      required_fields.each do |field|
        case field
        when '출발지', 'departure'
          field_definitions << { name: 'departure', label: '출발지', type: 'text', required: true }
        when '도착지', 'destination'
          field_definitions << { name: 'destination', label: '도착지', type: 'text', required: true }
        when '이동목적', 'purpose'
          field_definitions << { name: 'purpose', label: '이동 목적', type: 'text', required: true }
        when '참석자', 'attendees'
          field_definitions << { name: 'attendees', label: '참석자', type: 'text', required: true }
        when '인원수', 'attendee_count'
          field_definitions << { name: 'attendee_count', label: '인원수', type: 'number', required: true }
        when '품목명', 'item_name'
          field_definitions << { name: 'item_name', label: '품목명', type: 'text', required: true }
        when '수량', 'quantity'
          field_definitions << { name: 'quantity', label: '수량', type: 'number', required: true }
        when '프로젝트명', 'project_name'
          field_definitions << { name: 'project_name', label: '프로젝트명', type: 'text', required: true }
        else
          # 기본적으로 텍스트 필드로 처리
          field_definitions << { name: field.parameterize.underscore, label: field, type: 'text', required: true }
        end
      end
    end
    
    field_definitions
  end
end