import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["analysisContainer", "validationContainer", "field"]
  
  connect() {
    console.log("Nested fields controller connected")
  }
  
  addField(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const targetType = button.dataset.nestedFieldsTarget
    
    let container, template, association
    
    if (targetType === "analysisAddButton") {
      container = this.analysisContainerTarget
      association = "analysis_rules"
      template = this.getAnalysisRuleTemplate()
    } else if (targetType === "validationAddButton") {
      container = this.validationContainerTarget
      association = "validation_rules"
      template = this.getValidationRuleTemplate()
    }
    
    if (container && template) {
      const time = new Date().getTime()
      const newField = template.replace(/NEW_RECORD/g, time)
      container.insertAdjacentHTML('beforeend', newField)
    }
  }
  
  removeField(event) {
    event.preventDefault()
    
    const field = event.target.closest('.nested-fields')
    const destroyField = field.querySelector('input[name*="_destroy"]')
    
    if (destroyField) {
      destroyField.value = '1'
      field.style.display = 'none'
    } else {
      field.remove()
    }
  }
  
  getAnalysisRuleTemplate() {
    return `
      <div class="nested-fields border rounded p-3 mb-3" data-nested-fields-target="field">
        <div class="row">
          <div class="col-md-10">
            <div class="mb-2">
              <label class="form-label" for="attachment_requirement_analysis_rules_attributes_NEW_RECORD_prompt_text">프롬프트 텍스트</label>
              <textarea class="form-control" rows="2" placeholder="AI에게 전달할 분석 지시사항" 
                        name="attachment_requirement[analysis_rules_attributes][NEW_RECORD][prompt_text]" 
                        id="attachment_requirement_analysis_rules_attributes_NEW_RECORD_prompt_text"></textarea>
            </div>
            
            <div class="mb-2">
              <label class="form-label" for="attachment_requirement_analysis_rules_attributes_NEW_RECORD_expected_fields">예상 필드 (JSON)</label>
              <textarea class="form-control" rows="2" placeholder='{"field_name": "type", ...}' 
                        name="attachment_requirement[analysis_rules_attributes][NEW_RECORD][expected_fields]" 
                        id="attachment_requirement_analysis_rules_attributes_NEW_RECORD_expected_fields"></textarea>
            </div>
            
            <div class="form-check">
              <input type="hidden" value="0" autocomplete="off" 
                     name="attachment_requirement[analysis_rules_attributes][NEW_RECORD][active]">
              <input class="form-check-input" type="checkbox" value="1" checked="checked" 
                     name="attachment_requirement[analysis_rules_attributes][NEW_RECORD][active]" 
                     id="attachment_requirement_analysis_rules_attributes_NEW_RECORD_active">
              <label class="form-check-label" for="attachment_requirement_analysis_rules_attributes_NEW_RECORD_active">활성화</label>
            </div>
          </div>
          
          <div class="col-md-2 text-end">
            <button type="button" class="btn btn-sm btn-danger" data-action="click->nested-fields#removeField">
              <i class="bi bi-trash"></i> 삭제
            </button>
            <input type="hidden" value="0" autocomplete="off" 
                   name="attachment_requirement[analysis_rules_attributes][NEW_RECORD][_destroy]" 
                   id="attachment_requirement_analysis_rules_attributes_NEW_RECORD__destroy">
          </div>
        </div>
      </div>
    `
  }
  
  getValidationRuleTemplate() {
    return `
      <div class="nested-fields border rounded p-3 mb-3" data-nested-fields-target="field">
        <div class="row">
          <div class="col-md-10">
            <div class="row">
              <div class="col-md-4">
                <div class="mb-2">
                  <label class="form-label" for="attachment_requirement_validation_rules_attributes_NEW_RECORD_rule_type">규칙 타입</label>
                  <select class="form-select" name="attachment_requirement[validation_rules_attributes][NEW_RECORD][rule_type]" 
                          id="attachment_requirement_validation_rules_attributes_NEW_RECORD_rule_type">
                    <option value="">선택하세요</option>
                    <option value="required">필수 검증</option>
                    <option value="amount_match">금액 일치</option>
                    <option value="date_validation">날짜 검증</option>
                    <option value="custom">사용자 정의</option>
                  </select>
                </div>
              </div>
              
              <div class="col-md-4">
                <div class="mb-2">
                  <label class="form-label" for="attachment_requirement_validation_rules_attributes_NEW_RECORD_severity">심각도</label>
                  <select class="form-select" name="attachment_requirement[validation_rules_attributes][NEW_RECORD][severity]" 
                          id="attachment_requirement_validation_rules_attributes_NEW_RECORD_severity">
                    <option value="">선택하세요</option>
                    <option value="error">오류</option>
                    <option value="warning">경고</option>
                    <option value="info">정보</option>
                  </select>
                </div>
              </div>
              
              <div class="col-md-4">
                <div class="mb-2">
                  <label class="form-label" for="attachment_requirement_validation_rules_attributes_NEW_RECORD_position">순서</label>
                  <input class="form-control" min="0" type="number" value="0" 
                         name="attachment_requirement[validation_rules_attributes][NEW_RECORD][position]" 
                         id="attachment_requirement_validation_rules_attributes_NEW_RECORD_position">
                </div>
              </div>
            </div>
            
            <div class="mb-2">
              <label class="form-label" for="attachment_requirement_validation_rules_attributes_NEW_RECORD_prompt_text">검증 프롬프트</label>
              <textarea class="form-control" rows="2" placeholder="검증 규칙 설명" 
                        name="attachment_requirement[validation_rules_attributes][NEW_RECORD][prompt_text]" 
                        id="attachment_requirement_validation_rules_attributes_NEW_RECORD_prompt_text"></textarea>
            </div>
            
            <div class="form-check">
              <input type="hidden" value="0" autocomplete="off" 
                     name="attachment_requirement[validation_rules_attributes][NEW_RECORD][active]">
              <input class="form-check-input" type="checkbox" value="1" checked="checked" 
                     name="attachment_requirement[validation_rules_attributes][NEW_RECORD][active]" 
                     id="attachment_requirement_validation_rules_attributes_NEW_RECORD_active">
              <label class="form-check-label" for="attachment_requirement_validation_rules_attributes_NEW_RECORD_active">활성화</label>
            </div>
          </div>
          
          <div class="col-md-2 text-end">
            <button type="button" class="btn btn-sm btn-danger" data-action="click->nested-fields#removeField">
              <i class="bi bi-trash"></i> 삭제
            </button>
            <input type="hidden" value="0" autocomplete="off" 
                   name="attachment_requirement[validation_rules_attributes][NEW_RECORD][_destroy]" 
                   id="attachment_requirement_validation_rules_attributes_NEW_RECORD__destroy">
          </div>
        </div>
      </div>
    `
  }
}