# frozen_string_literal: true

module Admin
  module DashboardHelper
    def budget_status_color(status)
      case status
      when 'safe'
        'bg-green-500'
      when 'normal'
        'bg-blue-500'
      when 'warning'
        'bg-yellow-500'
      when 'danger'
        'bg-red-500'
      else
        'bg-gray-500'
      end
    end

    def budget_status_badge_color(status)
      case status
      when 'safe'
        'bg-green-100 text-green-800'
      when 'normal'
        'bg-blue-100 text-blue-800'
      when 'warning'
        'bg-yellow-100 text-yellow-800'
      when 'danger'
        'bg-red-100 text-red-800'
      else
        'bg-gray-100 text-gray-800'
      end
    end

    def budget_status_text(status)
      case status
      when 'safe'
        '안전'
      when 'normal'
        '정상'
      when 'warning'
        '주의'
      when 'danger'
        '위험'
      else
        '알 수 없음'
      end
    end

    def period_text(period)
      case period
      when 'today'
        '오늘'
      when 'this_week'
        '이번 주'
      when 'this_month'
        '이번 달'
      when 'this_quarter'
        '이번 분기'
      when 'this_year'
        '올해'
      when 'last_month'
        '지난 달'
      when 'last_quarter'
        '지난 분기'
      when 'last_year'
        '작년'
      else
        period
      end
    end

    def format_large_number(number)
      if number >= 1_000_000_000
        "#{(number / 1_000_000_000.0).round(1)}B"
      elsif number >= 1_000_000
        "#{(number / 1_000_000.0).round(1)}M"
      elsif number >= 1_000
        "#{(number / 1_000.0).round(1)}K"
      else
        number.to_s
      end
    end

    def trend_icon(current, previous)
      return '' if previous.zero?
      
      percentage = ((current - previous) / previous.to_f * 100).round(1)
      
      if percentage > 0
        content_tag(:span, "▲ #{percentage}%", class: 'text-red-600 text-sm')
      elsif percentage < 0
        content_tag(:span, "▼ #{percentage.abs}%", class: 'text-green-600 text-sm')
      else
        content_tag(:span, "─ 0%", class: 'text-gray-600 text-sm')
      end
    end
  end
end