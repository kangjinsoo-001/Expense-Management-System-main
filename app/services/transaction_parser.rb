class TransactionParser
  attr_reader :card_type, :transactions, :errors

  def initialize(card_type = nil)
    @card_type = card_type
    @transactions = []
    @errors = []
  end

  # 텍스트에서 거래 내역 파싱
  def parse_transactions(text)
    @transactions.clear
    @errors.clear
    
    lines = text.split("\n").map(&:strip).reject(&:blank?)
    
    # 카드사별 파싱 전략 선택
    case @card_type&.to_sym
    when :shinhan
      parse_shinhan_transactions(lines)
    when :samsung
      parse_samsung_transactions(lines)
    when :kb
      parse_kb_transactions(lines)
    else
      # 범용 파싱 로직
      parse_generic_transactions(lines)
    end
    
    {
      success: @transactions.any?,
      transactions: @transactions,
      total_count: @transactions.size,
      total_amount: @transactions.sum { |t| t[:amount] },
      errors: @errors
    }
  end

  # 거래 내역과 경비 항목 매칭
  def match_with_expense_items(expense_items)
    matches = []
    unmatched_transactions = @transactions.dup
    unmatched_items = expense_items.to_a.dup
    
    # 성능 최적화: 경비 항목이 너무 많은 경우 제한
    if unmatched_items.size > 100
      Rails.logger.warn "경비 항목이 #{unmatched_items.size}개로 너무 많습니다. 성능을 위해 최근 100개만 처리합니다."
      unmatched_items = unmatched_items.sort_by(&:expense_date).reverse.first(100)
    end
    
    # 1차: 날짜와 금액이 정확히 일치하는 경우
    unmatched_transactions.each do |transaction|
      matched_item = unmatched_items.find do |item|
        item.expense_date == transaction[:date] && 
        item.amount == transaction[:amount]
      end
      
      if matched_item
        matches << {
          transaction: transaction,
          expense_item: matched_item,
          confidence: 1.0,
          match_type: 'exact'
        }
        unmatched_transactions.delete(transaction)
        unmatched_items.delete(matched_item)
      end
    end
    
    # 2차: 날짜는 같고 금액이 유사한 경우 (±10% 이내)
    unmatched_transactions.each do |transaction|
      matched_item = unmatched_items.find do |item|
        item.expense_date == transaction[:date] && 
        amount_similar?(item.amount, transaction[:amount], 0.1)
      end
      
      if matched_item
        matches << {
          transaction: transaction,
          expense_item: matched_item,
          confidence: 0.8,
          match_type: 'amount_similar'
        }
        unmatched_transactions.delete(transaction)
        unmatched_items.delete(matched_item)
      end
    end
    
    # 3차: 설명 텍스트 유사도 기반 매칭
    unmatched_transactions.each do |transaction|
      best_match = nil
      best_score = 0
      
      unmatched_items.each do |item|
        score = text_similarity(transaction[:description], item.description)
        if score > 0.6 && score > best_score
          best_match = item
          best_score = score
        end
      end
      
      if best_match
        matches << {
          transaction: transaction,
          expense_item: best_match,
          confidence: best_score,
          match_type: 'text_similar'
        }
        unmatched_transactions.delete(transaction)
        unmatched_items.delete(best_match)
      end
    end
    
    {
      matches: matches,
      unmatched_transactions: unmatched_transactions,
      unmatched_items: unmatched_items,
      match_rate: matches.size.to_f / @transactions.size
    }
  end

  private

  # 신한카드 거래 내역 파싱
  def parse_shinhan_transactions(lines)
    # 영어 형식도 지원
    transaction_pattern = /(\d{2}\/\d{2})\s+(.+?)\s+([\d,]+)(?:원)?/
    
    lines.each do |line|
      if match = line.match(transaction_pattern)
        date_str = match[1]
        description = match[2].strip
        amount_str = match[3].gsub(',', '')
        
        begin
          # MM/DD 형식을 현재 연도로 변환
          month, day = date_str.split('/').map(&:to_i)
          date = Date.new(Date.current.year, month, day)
          
          @transactions << {
            date: date,
            description: description,
            amount: amount_str.to_f,
            original_text: line
          }
        rescue => e
          @errors << "거래 파싱 실패: #{line} - #{e.message}"
        end
      end
    end
  end

  # 삼성카드 거래 내역 파싱
  def parse_samsung_transactions(lines)
    # 삼성카드 형식: 2025.01.15 가맹점명 1,234,567
    transaction_pattern = /(\d{4}\.\d{2}\.\d{2})\s+(.+?)\s+([\d,]+)(?:원)?$/
    
    lines.each do |line|
      if match = line.match(transaction_pattern)
        date_str = match[1]
        description = match[2].strip
        amount_str = match[3].gsub(',', '')
        
        begin
          date = Date.parse(date_str.gsub('.', '-'))
          
          @transactions << {
            date: date,
            description: description,
            amount: amount_str.to_f,
            original_text: line
          }
        rescue => e
          @errors << "거래 파싱 실패: #{line} - #{e.message}"
        end
      end
    end
  end

  # KB국민카드 거래 내역 파싱
  def parse_kb_transactions(lines)
    # KB카드 형식: 01.15 가맹점명 승인 1,234,567원 또는 01.15 가맹점명 Approved 1,234,567
    transaction_pattern = /(\d{2}\.\d{2})\s+(.+?)\s+(?:승인|Approved)\s+([\d,]+)(?:원)?/
    
    lines.each do |line|
      if match = line.match(transaction_pattern)
        date_str = match[1]
        description = match[2].strip
        amount_str = match[3].gsub(',', '')
        
        begin
          month, day = date_str.split('.').map(&:to_i)
          date = Date.new(Date.current.year, month, day)
          
          @transactions << {
            date: date,
            description: description,
            amount: amount_str.to_f,
            original_text: line
          }
        rescue => e
          @errors << "거래 파싱 실패: #{line} - #{e.message}"
        end
      end
    end
  end

  # 범용 거래 내역 파싱
  def parse_generic_transactions(lines)
    # 다양한 패턴 시도
    patterns = [
      /(\d{4}[-\.\/]\d{2}[-\.\/]\d{2})\s+(.+?)\s+([\d,]+\.?\d*)/, # 2025-01-15 설명 1234.56
      /(\d{2}[-\.\/]\d{2})\s+(.+?)\s+([\d,]+)원/,                  # 01/15 설명 1,234원
      /(.+?)\s+(\d{4}[-\.\/]\d{2}[-\.\/]\d{2})\s+([\d,]+)/        # 설명 2025-01-15 1,234
    ]
    
    lines.each do |line|
      patterns.each do |pattern|
        if match = line.match(pattern)
          begin
            # 날짜 파싱
            date_str = match[1]
            date = parse_date_string(date_str)
            
            # 설명과 금액 추출
            if pattern.to_s.include?('(.+?)\\s+(\\d{4}')
              description = match[1].strip
              amount_str = match[3].gsub(/[^\d.]/, '')
            else
              description = match[2].strip
              amount_str = match[3].gsub(/[^\d.]/, '')
            end
            
            if date && amount_str.to_f > 0
              @transactions << {
                date: date,
                description: description,
                amount: amount_str.to_f,
                original_text: line
              }
              break # 패턴이 매칭되면 다음 라인으로
            end
          rescue => e
            # 다음 패턴 시도
          end
        end
      end
    end
  end

  # 날짜 문자열 파싱
  def parse_date_string(date_str)
    # 연도가 없는 경우 현재 연도 사용
    if date_str.match(/^\d{2}[-\.\/]\d{2}$/)
      month, day = date_str.split(/[-\.\/]/).map(&:to_i)
      return Date.new(Date.current.year, month, day)
    end
    
    # 다양한 날짜 형식 시도
    formats = ['%Y-%m-%d', '%Y.%m.%d', '%Y/%m/%d']
    formats.each do |format|
      begin
        return Date.strptime(date_str, format)
      rescue
        next
      end
    end
    
    nil
  end

  # 금액 유사도 확인
  def amount_similar?(amount1, amount2, threshold = 0.1)
    return false if amount1 == 0 || amount2 == 0
    
    diff = (amount1 - amount2).abs
    ratio = diff / [amount1, amount2].max
    
    ratio <= threshold
  end

  # 텍스트 유사도 계산 (간단한 구현)
  def text_similarity(text1, text2)
    return 0 if text1.blank? || text2.blank?
    
    # 소문자 변환 및 공백 정규화
    normalized1 = text1.downcase.strip.gsub(/\s+/, ' ')
    normalized2 = text2.downcase.strip.gsub(/\s+/, ' ')
    
    # 정확히 일치
    return 1.0 if normalized1 == normalized2
    
    # 부분 문자열 포함
    if normalized1.include?(normalized2) || normalized2.include?(normalized1)
      return 0.8
    end
    
    # 단어 단위 비교
    words1 = normalized1.split(' ')
    words2 = normalized2.split(' ')
    
    common_words = words1 & words2
    total_words = (words1 + words2).uniq.size
    
    return 0 if total_words == 0
    
    common_words.size.to_f / total_words
  end
end