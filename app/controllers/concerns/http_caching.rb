module HttpCaching
  extend ActiveSupport::Concern
  
  included do
    # 전역 HTTP 캐싱 설정
    before_action :set_cache_headers
  end
  
  private
  
  def set_cache_headers
    # 기본적으로 private 캐시 설정
    response.headers['Cache-Control'] = 'private, no-store'
    
    # 정적 콘텐츠에 대한 캐싱 설정
    if request.get? && stale_content?
      expires_in cache_duration, public: false
    end
  end
  
  def stale_content?
    # 로그인 상태, 권한 등에 따라 캐시 가능 여부 판단
    return false unless logged_in?
    
    # 특정 액션에 대해서만 캐싱 허용
    cacheable_actions = %w[index show]
    cacheable_actions.include?(action_name)
  end
  
  def cache_duration
    # 액션별 캐시 지속 시간 설정
    case action_name
    when 'index'
      5.minutes
    when 'show'
      10.minutes
    else
      0
    end
  end
  
  # 조건부 GET 요청 처리
  def fresh_when_record(record, options = {})
    fresh_when(
      etag: generate_etag(record),
      last_modified: record.updated_at.utc,
      public: false,
      **options
    )
  end
  
  def fresh_when_collection(collection, options = {})
    fresh_when(
      etag: generate_collection_etag(collection),
      last_modified: collection.maximum(:updated_at)&.utc,
      public: false,
      **options
    )
  end
  
  private
  
  def generate_etag(record)
    # 레코드와 사용자 정보를 조합한 ETag 생성
    [
      record.cache_key_with_version,
      current_user.id,
      current_user.updated_at.to_i
    ].join('/')
  end
  
  def generate_collection_etag(collection)
    # 컬렉션에 대한 ETag 생성
    [
      collection.cache_key_with_version,
      current_user.id,
      current_user.updated_at.to_i
    ].join('/')
  end
end