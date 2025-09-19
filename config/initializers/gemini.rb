# Gemini AI 설정
# require 'gemini-ai' # 직접 HTTP 요청 사용으로 gem 사용 안함

# API 키 설정
Rails.application.config.gemini_api_key = ENV['GEMINI_API_KEY']

# Gemini 클라이언트 초기화는 서비스에서 수행
# 여기서는 전역 설정만 정의
module GeminiConfig
  # Gemini 2.5 Flash 모델 (최신 버전)
  # gemini-2.5-flash-lite는 아직 Generative Language API에서 지원되지 않음
  # gemini-2.5-flash 사용 (더 빠르고 성능 개선됨)
  MODEL = 'gemini-2.5-flash'
  
  # API 설정
  REQUEST_TIMEOUT = 30 # 초
  MAX_RETRIES = 3
  
  # 토큰 제한
  MAX_INPUT_TOKENS = 32000
  MAX_OUTPUT_TOKENS = 8192
  
  # 온도 설정 (0.0 ~ 1.0)
  TEMPERATURE = 0.3 # 더 일관된 결과를 위해 낮은 온도 사용
end