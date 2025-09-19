require 'prawn'

# 테스트용 PDF 생성
Prawn::Document.generate(File.join(__dir__, "test.pdf")) do
  text "Test PDF Document"
  text "This is a test PDF for uploading"
  text "Date: 2025-01-15"
  text "Amount: 10,000 KRW"
end

puts "test.pdf created successfully"