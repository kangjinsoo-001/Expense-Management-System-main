# Gemini API 사용 메트릭 추적 서비스
class GeminiMetricsService
  include Singleton
  
  attr_reader :metrics
  
  def initialize
    reset_metrics
  end
  
  # API 호출 기록
  def track_api_call(success:, duration:, tokens_used: nil, error: nil)
    @metrics[:total_calls] += 1
    
    if success
      @metrics[:successful_calls] += 1
      @metrics[:total_duration] += duration
      @metrics[:total_tokens] += tokens_used if tokens_used
    else
      @metrics[:failed_calls] += 1
      @metrics[:errors] << {
        timestamp: Time.current,
        error: error,
        message: error&.message
      }
    end
    
    @metrics[:last_call_at] = Time.current
    
    # 일일 통계 업데이트
    update_daily_stats(success, tokens_used)
    
    # 로그 기록
    log_api_call(success, duration, tokens_used, error)
  end
  
  # 영수증 분류 추적
  def track_classification(receipt_type)
    @metrics[:classifications][receipt_type] ||= 0
    @metrics[:classifications][receipt_type] += 1
  end
  
  # 요약 성공률 추적
  def track_summary(success)
    @metrics[:summaries][:total] += 1
    @metrics[:summaries][:successful] += 1 if success
  end
  
  # 현재 메트릭 조회
  def current_metrics
    @metrics.merge(
      average_duration: calculate_average_duration,
      success_rate: calculate_success_rate,
      daily_usage: get_daily_usage
    )
  end
  
  # 일일 사용량 조회
  def get_daily_usage
    today = Date.current.to_s
    @daily_stats[today] || { calls: 0, tokens: 0, errors: 0 }
  end
  
  # 메트릭 리셋
  def reset_metrics
    @metrics = {
      total_calls: 0,
      successful_calls: 0,
      failed_calls: 0,
      total_duration: 0,
      total_tokens: 0,
      errors: [],
      last_call_at: nil,
      classifications: {},
      summaries: { total: 0, successful: 0 }
    }
    @daily_stats = {}
  end
  
  private
  
  def update_daily_stats(success, tokens_used)
    today = Date.current.to_s
    @daily_stats[today] ||= { calls: 0, tokens: 0, errors: 0 }
    
    @daily_stats[today][:calls] += 1
    @daily_stats[today][:tokens] += tokens_used if tokens_used
    @daily_stats[today][:errors] += 1 unless success
    
    # 30일 이상 된 통계 삭제
    cleanup_old_stats
  end
  
  def cleanup_old_stats
    cutoff_date = 30.days.ago.to_date.to_s
    @daily_stats.delete_if { |date, _| date < cutoff_date }
  end
  
  def calculate_average_duration
    return 0 if @metrics[:successful_calls] == 0
    @metrics[:total_duration] / @metrics[:successful_calls]
  end
  
  def calculate_success_rate
    total = @metrics[:total_calls]
    return 0 if total == 0
    (@metrics[:successful_calls].to_f / total * 100).round(2)
  end
  
  def log_api_call(success, duration, tokens_used, error)
    log_level = success ? :info : :error
    
    Rails.logger.tagged('GeminiAPI') do
      Rails.logger.send(log_level, {
        success: success,
        duration: "#{duration}ms",
        tokens_used: tokens_used,
        error: error&.message,
        timestamp: Time.current.iso8601
      }.to_json)
    end
  end
end