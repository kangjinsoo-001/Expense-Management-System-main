require 'pdf-reader'
require 'rtesseract'
require 'mini_magick'
require 'tempfile'

class ExtractTextFromAttachmentJob < ApplicationJob
  queue_as :default

  def perform(attachment)
    return unless attachment.file.attached?
    
    begin
      # 상태를 처리중으로 변경
      attachment.update(status: 'processing')
      
      # 파일 다운로드
      file_content = attachment.file.download
      
      extracted_text = case attachment.file.content_type
      when 'application/pdf'
        extract_text_from_pdf(file_content)
      when 'image/jpeg', 'image/jpg', 'image/png'
        extract_text_from_image(file_content)
      else
        nil
      end
      
      # 추출된 텍스트와 메타데이터 저장
      if extracted_text && !extracted_text.strip.empty?
        # 주요 정보 추출 (금액, 날짜 등)
        metadata = extract_metadata(extracted_text)
        
        attachment.update(
          extracted_text: extracted_text,
          metadata: metadata,
          status: 'completed'
        )
      else
        attachment.update(
          extracted_text: "텍스트를 추출할 수 없습니다.",
          status: 'completed'
        )
      end
      
    rescue => e
      Rails.logger.error "텍스트 추출 실패: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      attachment.update(
        extracted_text: "오류: #{e.message}",
        status: 'failed'
      )
    end
  end
  
  private
  
  def extract_text_from_pdf(content)
    begin
      # 임시 파일로 저장
      Tempfile.create(['pdf', '.pdf'], binmode: true) do |temp_file|
        temp_file.write(content)
        temp_file.rewind
        
        # PDF Reader로 텍스트 추출 시도
        reader = PDF::Reader.new(temp_file.path)
        text = reader.pages.map(&:text).join("\n")
        
        Rails.logger.info "PDF 페이지 수: #{reader.page_count}"
        Rails.logger.info "추출된 텍스트 길이: #{text.strip.length}"
        Rails.logger.info "텍스트 샘플: #{text[0..100]}" if text
        
        # 텍스트가 없거나 너무 짧은 경우 OCR 시도
        if text.strip.length < 200
          Rails.logger.info "PDF에서 직접 텍스트 추출 실패 또는 불완전 (텍스트 길이: #{text.strip.length}), OCR 시도 중..."
          
          # 임시 파일 경로를 유지하기 위해 파일 복사
          Tempfile.create(['pdf_for_ocr', '.pdf']) do |ocr_pdf|
            ocr_pdf.binmode
            ocr_pdf.write(File.read(temp_file.path, mode: 'rb'))
            ocr_pdf.rewind
            
            ocr_text = extract_text_from_pdf_with_ocr(ocr_pdf.path)
            if ocr_text && !ocr_text.empty?
              Rails.logger.info "OCR 성공, 추출된 텍스트 길이: #{ocr_text.length}"
              return ocr_text
            else
              Rails.logger.warn "OCR도 실패, 원본 텍스트 반환"
            end
          end
        end
        
        return text
      end
    rescue => e
      Rails.logger.error "PDF 텍스트 추출 오류: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      return nil
    end
  end
  
  def extract_text_from_pdf_with_ocr(pdf_path)
    begin
      # PDF 페이지 수 확인
      pdf_reader = PDF::Reader.new(pdf_path)
      total_pages = pdf_reader.page_count
      Rails.logger.info "PDF 총 페이지 수: #{total_pages}"
      
      all_text = []
      
      # 모든 페이지를 처리
      (0...total_pages).each do |page_num|
        Rails.logger.info "페이지 #{page_num + 1}/#{total_pages} OCR 처리 중..."
        
        # 각 페이지를 이미지로 변환
        Tempfile.create(['pdf_page', '.png']) do |temp_png|
          # ImageMagick 명령을 직접 실행하여 특정 페이지만 변환
          # -density는 입력 파일 앞에 와야 함 (200 DPI로 변경하여 속도 개선)
          system("convert -density 200 '#{pdf_path}[#{page_num}]' -quality 90 -contrast -sharpen 0x1 '#{temp_png.path}'")
          
          unless File.exist?(temp_png.path) && File.size(temp_png.path) > 0
            Rails.logger.error "페이지 #{page_num + 1} 이미지 변환 실패"
            next
          end
          
          Rails.logger.info "페이지 #{page_num + 1} 이미지 생성 완료: #{File.size(temp_png.path)} bytes"
          
          # RTesseract로 OCR 수행
          ocr_image = RTesseract.new(temp_png.path, lang: 'kor+eng')
          page_text = ocr_image.to_s
          
          if page_text && !page_text.strip.empty?
            all_text << "=== 페이지 #{page_num + 1} ===\n#{page_text}"
            Rails.logger.info "페이지 #{page_num + 1} OCR 완료: #{page_text.length}자"
          end
        end
      end
      
      combined_text = all_text.join("\n\n")
      Rails.logger.info "전체 OCR 완료: 총 #{combined_text.length}자"
      return combined_text
      
    rescue => e
      Rails.logger.error "PDF OCR 오류: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      return nil
    end
  end
  
  def extract_text_from_image(content)
    begin
      # 임시 파일로 저장
      Tempfile.create(['image', '.png'], binmode: true) do |temp_file|
        temp_file.write(content)
        temp_file.rewind
        
        # RTesseract로 OCR 수행
        # 한국어와 영어 모두 인식
        image = RTesseract.new(temp_file.path, lang: 'kor+eng')
        text = image.to_s
        
        return text
      end
    rescue => e
      Rails.logger.error "이미지 OCR 오류: #{e.message}"
      
      # Tesseract가 설치되어 있지 않은 경우 안내
      if e.message.include?('tesseract') || e.message.include?('not found')
        return <<~TEXT
          Tesseract OCR이 설치되어 있지 않습니다.
          
          설치 방법:
          Ubuntu/Debian: sudo apt-get install tesseract-ocr tesseract-ocr-kor
          macOS: brew install tesseract tesseract-lang
          Windows: https://github.com/UB-Mannheim/tesseract/wiki
          
          한국어 언어 데이터도 설치해야 합니다.
        TEXT
      end
      
      return nil
    end
  end
  
  def extract_metadata(text)
    metadata = {}
    
    # 금액 추출 (숫자,숫자 패턴 또는 숫자원 패턴)
    amount_match = text.match(/(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*원?/)
    if amount_match
      metadata[:amount] = amount_match[1].gsub(',', '').to_i
    end
    
    # 날짜 추출 (YYYY-MM-DD 또는 YYYY.MM.DD 패턴)
    date_match = text.match(/(\d{4}[-\.]\d{1,2}[-\.]\d{1,2})/)
    if date_match
      begin
        metadata[:date] = Date.parse(date_match[1].gsub('.', '-'))
      rescue
        # 날짜 파싱 실패시 무시
      end
    end
    
    # 상호명 추출 (간단한 패턴)
    vendor_match = text.match(/(?:상호|업체|가맹점)\s*[:：]?\s*(.+?)(?:\n|$)/)
    if vendor_match
      metadata[:vendor] = vendor_match[1].strip
    end
    
    metadata
  end
end
