class RequestTemplatesController < ApplicationController
  before_action :require_login
  
  # 결재선 검증 (Turbo Stream)
  def validate_approval_line
    @template = RequestTemplate.find(params[:id])
    @approval_line = current_user.approval_lines.active.find_by(id: params[:approval_line_id])
    
    # 승인 규칙 확인
    approval_rules = @template.request_template_approval_rules.active.includes(:approver_group)
    
    # 본인이 이미 권한을 가진 규칙은 제외
    required_rules = approval_rules.reject do |rule|
      rule.already_satisfied_by_user?(current_user)
    end
    
    if required_rules.any?
      if @approval_line.blank?
        # 결재선이 필요한데 선택하지 않은 경우
        # 우선순위가 높은 순(priority가 큰 순)으로 정렬하고 이름만 추출
        sorted_group_names = required_rules.map(&:approver_group)
                                          .uniq
                                          .sort_by { |g| -g.priority }
                                          .map(&:name)
        @validation_type = :error
        @validation_message = "승인 필요: #{sorted_group_names.join(', ')}"
      else
        # 계층적 승인 규칙 체크
        missing_groups = []
        
        required_rules.each do |rule|
          # satisfied_with_hierarchy? 메서드 사용 (상위 권한이 있으면 하위도 충족)
          unless rule.satisfied_with_hierarchy?(@approval_line)
            missing_groups << rule.approver_group
          end
        end
        
        if missing_groups.any?
          # 우선순위가 높은 순(priority가 큰 순)으로 정렬하고 이름만 추출
          sorted_missing_group_names = missing_groups.uniq
                                                    .sort_by { |g| -g.priority }
                                                    .map(&:name)
          @validation_type = :error
          @validation_message = "승인 필요: #{sorted_missing_group_names.join(', ')}"
        else
          # 과도한 승인자 체크
          max_required_priority = required_rules.map { |r| r.approver_group.priority }.max || 0
          
          # 결재선의 승인자들이 속한 그룹의 최고 우선순위
          approvers = @approval_line.approval_line_steps.approvers.includes(approver: :approver_groups).map(&:approver)
          highest_groups = approvers.map do |approver|
            approver.approver_groups.max_by(&:priority)
          end.compact.uniq
          
          max_actual_priority = highest_groups.map(&:priority).max || 0
          
          if max_actual_priority > max_required_priority
            # 필요 이상으로 높은 직급이 포함된 경우
            excessive_groups = highest_groups.select { |g| g.priority > max_required_priority }
            sorted_excessive_group_names = excessive_groups.sort_by { |g| -g.priority }
                                                          .map(&:name)
            @validation_type = :warning
            @validation_message = "필수 아님: #{sorted_excessive_group_names.join(', ')}"
          else
            # 정확히 충족되면 메시지 없음 (경비 항목과 동일)
            @validation_type = nil
            @validation_message = nil
          end
        end
      end
    elsif @approval_line.present?
      # 승인이 필요 없는데 결재선을 선택한 경우
      # 결재선의 승인자들이 속한 그룹을 우선순위 순으로 정렬하고 이름만 추출
      approvers = @approval_line.approval_line_steps.approvers.includes(approver: :approver_groups).map(&:approver)
      sorted_group_names = approvers.flat_map(&:approver_groups)
                                   .uniq
                                   .sort_by { |g| -g.priority }
                                   .map(&:name)
      
      if sorted_group_names.any?
        @validation_type = :warning
        @validation_message = "#{sorted_group_names.join(', ')}의 승인 불필요"
      else
        @validation_type = :warning
        @validation_message = "결재선이 필요하지 않습니다"
      end
    end
    
    respond_to do |format|
      format.turbo_stream
    end
  end
end