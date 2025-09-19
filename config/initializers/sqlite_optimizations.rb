# SQLite 성능 최적화 설정
Rails.application.config.after_initialize do
  if ActiveRecord::Base.connection.adapter_name == 'SQLite'
    # WAL 모드 활성화 - 성능과 동시성 향상
    ActiveRecord::Base.connection.execute('PRAGMA journal_mode = WAL')
    ActiveRecord::Base.connection.execute('PRAGMA synchronous = NORMAL')
    ActiveRecord::Base.connection.execute('PRAGMA cache_size = -64000')  # 64MB
    ActiveRecord::Base.connection.execute('PRAGMA temp_store = MEMORY')
    ActiveRecord::Base.connection.execute('PRAGMA mmap_size = 268435456')  # 256MB
    ActiveRecord::Base.connection.execute('PRAGMA busy_timeout = 5000')
    # WAL 체크포인트 설정 - 1000 페이지마다 자동 체크포인트
    ActiveRecord::Base.connection.execute('PRAGMA wal_autocheckpoint = 1000')
    # 저널 크기 제한 - 64MB
    ActiveRecord::Base.connection.execute('PRAGMA journal_size_limit = 67108864')
  end
end