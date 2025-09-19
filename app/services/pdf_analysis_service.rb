require 'pdf-reader'

class PdfAnalysisService
  attr_reader :errors

  def initialize
    @errors = []
  end
  
  # PDF 분석 및 거래 내역 파싱
  def analyze_and_parse(pdf_file, expense_sheet)
    start_time = Time.current
    
    # 1. 텍스트 추출
    extraction_result = extract_text(pdf_file)
    return extraction_result unless extraction_result[:success]
    
    full_text = extraction_result[:full_text]
    Rails.logger.info "PDF 텍스트 추출 완료: #{(Time.current - start_time).round(2)}초"
    
    # 2. 카드사 타입 감지
    card_type = detect_card_statement_type(full_text)
    Rails.logger.info "카드사 감지: #{card_type}"
    
    # 3. 거래 내역 파싱
    parser = TransactionParser.new(card_type)
    parsing_start = Time.current
    parsing_result = parser.parse_transactions(full_text)
    Rails.logger.info "거래 내역 파싱 완료: #{parsing_result[:total_count]}건, #{(Time.current - parsing_start).round(2)}초"
    
    # 4. 경비 항목과 매칭
    matching_start = Time.current
    if parsing_result[:success] && expense_sheet.expense_items.any?
      matching_result = parser.match_with_expense_items(expense_sheet.expense_items)
      Rails.logger.info "경비 항목 매칭 완료: #{matching_result[:matches].size}건 매칭, #{(Time.current - matching_start).round(2)}초"
    else
      matching_result = {
        matches: [],
        unmatched_transactions: parsing_result[:transactions] || [],
        unmatched_items: expense_sheet.expense_items.to_a,
        match_rate: 0
      }
    end
    
    Rails.logger.info "PDF 전체 분석 완료: 총 #{(Time.current - start_time).round(2)}초"
    
    {
      success: true,
      extraction: extraction_result,
      card_type: card_type,
      parsing: parsing_result,
      matching: matching_result
    }
  end

  # PDF 파일에서 텍스트 추출
  def extract_text(pdf_file)
    @errors.clear
    
    begin
      reader = PDF::Reader.new(pdf_file)
      extracted_text = []
      
      # 대용량 PDF 최적화: 최대 페이지 수 제한
      max_pages = ENV.fetch('PDF_MAX_PAGES', 50).to_i
      pages_to_process = [reader.page_count, max_pages].min
      
      reader.pages.first(pages_to_process).each_with_index do |page, index|
        begin
          page_text = page.text
          # 한글 인코딩 처리
          page_text = ensure_utf8_encoding(page_text)
          
          # 텍스트가 너무 긴 경우 제한
          if page_text.length > 50_000
            page_text = page_text[0...50_000] + "\n... (텍스트가 잘렸습니다)"
            @errors << "페이지 #{index + 1}: 텍스트가 너무 길어 일부가 잘렸습니다"
          end
          
          extracted_text << {
            page_number: index + 1,
            text: page_text,
            lines: page_text.split("\n").reject(&:blank?)
          }
        rescue => e
          @errors << "페이지 #{index + 1} 읽기 실패: #{e.message}"
          # 오류가 발생해도 계속 진행
        end
      end
      
      if reader.page_count > pages_to_process
        @errors << "PDF가 #{max_pages}페이지를 초과하여 일부만 처리되었습니다 (전체: #{reader.page_count}페이지)"
      end
      
      {
        success: true,
        total_pages: reader.page_count,
        pages: extracted_text,
        full_text: extracted_text.map { |p| p[:text] }.join("\n"),
        errors: @errors
      }
    rescue PDF::Reader::EncryptedPDFError
      @errors << "암호화된 PDF 파일은 처리할 수 없습니다."
      error_result
    rescue PDF::Reader::MalformedPDFError
      @errors << "손상된 PDF 파일입니다."
      error_result
    rescue => e
      @errors << "PDF 처리 중 오류 발생: #{e.message}"
      error_result
    end
  end

  # Active Storage blob에서 텍스트 추출
  def extract_text_from_blob(blob)
    blob.open do |file|
      extract_text(file)
    end
  end

  # 추출된 텍스트에서 금액 찾기
  def find_amounts(text)
    # 다양한 금액 패턴 매칭
    patterns = [
      /[\d,]+원/,                    # 1,000원
      /₩\s*[\d,]+/,                  # ₩ 1,000
      /KRW\s*[\d,]+/,                # KRW 1,000
      /[\d,]+\s*won/i,               # 1000 won
      /[\d]{1,3}(?:,[\d]{3})*(?:\.\d{2})?/ # 1,000.00 또는 1,000
    ]
    
    amounts = []
    patterns.each do |pattern|
      text.scan(pattern) do |match|
        # 숫자만 추출
        amount = match.gsub(/[^\d.]/, '').to_f
        if amount > 0 && !amounts.any? { |a| a[:amount] == amount }
          amounts << {
            original: match,
            amount: amount,
            formatted: number_to_currency(amount)
          }
        end
      end
    end
    
    amounts
  end

  # 추출된 텍스트에서 날짜 찾기
  def find_dates(text)
    # 다양한 날짜 패턴 매칭
    patterns = [
      /\d{4}[년\-\/\.]\d{1,2}[월\-\/\.]\d{1,2}[일]?/, # 2025년 1월 1일, 2025-01-01
      /\d{1,2}[월\-\/\.]\d{1,2}[일]?/,                # 1월 1일, 01/01
      /\d{4}\.\d{2}\.\d{2}/,                          # 2025.01.01
      /\d{2}\.\d{2}\.\d{2}/                           # 25.01.01
    ]
    
    dates = []
    patterns.each do |pattern|
      text.scan(pattern) do |match|
        begin
          # 날짜 파싱 시도
          parsed_date = parse_date_string(match)
          dates << {
            original: match,
            date: parsed_date,
            formatted: parsed_date.strftime("%Y-%m-%d")
          } if parsed_date
        rescue => e
          # 날짜 파싱 실패 시 무시
        end
      end
    end
    
    dates.uniq { |d| d[:formatted] }
  end

  # 카드 명세서 패턴 감지
  def detect_card_statement_type(text)
    # 주요 카드사 패턴 (영어도 지원)
    patterns = {
      shinhan: /신한카드|SHINHAN\s*CARD|shinhan/i,
      samsung: /삼성카드|SAMSUNG\s*CARD|samsung/i,
      kb: /KB국민카드|KB\s*CARD|kb/i,
      woori: /우리카드|WOORI\s*CARD|woori/i,
      hana: /하나카드|HANA\s*CARD|hana/i,
      lotte: /롯데카드|LOTTE\s*CARD|lotte/i,
      bc: /BC카드|BC\s*CARD|bc/i,
      nh: /NH농협카드|NH\s*CARD|nh/i
    }
    
    patterns.each do |card_type, pattern|
      return card_type if text.match?(pattern)
    end
    
    :unknown
  end

  private

  def ensure_utf8_encoding(text)
    # 이미 UTF-8이고 유효한 경우
    return text if text.encoding == Encoding::UTF_8 && text.valid_encoding?
    
    # 원본 인코딩 보존
    original_encoding = text.encoding
    
    # UTF-8로 변환 시도
    begin
      return text.encode('UTF-8', original_encoding)
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      # 변환 실패 시 다른 인코딩 시도
      %w[CP949 EUC-KR ISO-8859-1].each do |encoding|
        begin
          return text.force_encoding(encoding).encode('UTF-8')
        rescue
          next
        end
      end
    end
    
    # 모든 시도 실패 시 강제 변환
    text.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def parse_date_string(date_str)
    # 한글 제거
    cleaned = date_str.gsub(/[년월일]/, '-').gsub(/\s/, '')
    
    # 다양한 형식 시도
    formats = [
      '%Y-%m-%d',
      '%Y.%m.%d',
      '%Y/%m/%d',
      '%y.%m.%d',
      '%m-%d',
      '%m/%d'
    ]
    
    formats.each do |format|
      begin
        date = Date.strptime(cleaned, format)
        # 연도가 없는 경우 현재 연도 사용
        date = Date.new(Date.current.year, date.month, date.day) if format.include?('%m') && !format.include?('%Y')
        return date
      rescue
        next
      end
    end
    
    nil
  end

  def number_to_currency(amount)
    "₩#{amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def error_result
    {
      success: false,
      errors: @errors,
      pages: [],
      full_text: '',
      total_pages: 0
    }
  end
end