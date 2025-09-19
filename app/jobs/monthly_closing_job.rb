class MonthlyClosingJob < ApplicationJob
  queue_as :default
  
  def perform(year = nil, month = nil)
    # 기본값: 이전 달
    if year.nil? || month.nil?
      date = 1.month.ago
      year = date.year
      month = date.month
    end
    
    Rails.logger.info "월 마감 작업 시작: #{year}년 #{month}월"
    
    # 마감 서비스 호출
    service = MonthlyClosingService.new(year: year, month: month)
    result = service.execute
    
    if result[:success]
      Rails.logger.info "월 마감 작업 완료: #{result[:message]}"
    else
      Rails.logger.error "월 마감 작업 실패: #{result[:message]}"
      raise StandardError, result[:message]
    end
  end
end