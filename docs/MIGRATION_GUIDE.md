# 컴포넌트 마이그레이션 가이드

## 📋 개요
기존 118개의 partial 컴포넌트를 아토믹 디자인 시스템으로 마이그레이션하는 단계별 가이드입니다.

## 🔍 현재 상황 분석

### 기존 Partial 컴포넌트 분석
```bash
# 기존 컴포넌트 목록 확인
find app/views -name "_*.html.erb" | sort > current_partials.txt

# 컴포넌트 사용 빈도 분석
grep -r "render.*_" app/views --include="*.html.erb" | wc -l
```

### 주요 발견사항
- **총 118개 partial 컴포넌트** 존재
- **중복 기능** 컴포넌트 다수 발견 예상
- **일관성 부족** - 명명 규칙과 구조가 파편화됨
- **재사용성 낮음** - 특정 페이지에 종속된 컴포넌트 다수

## 🎯 마이그레이션 전략

### Phase 1: 분석 및 계획 (1주)

#### 1.1 컴포넌트 인벤토리 작성
```bash
# 스크립트를 실행하여 컴포넌트 분석
./scripts/analyze_components.rb
```

#### 1.2 사용 빈도 분석
```ruby
# 컴포넌트별 사용 빈도 체크 스크립트
component_usage = {}

Dir.glob("app/views/**/_*.html.erb").each do |partial_path|
  component_name = File.basename(partial_path, ".html.erb")
  usage_count = `grep -r "render.*#{component_name}" app/views --include="*.html.erb" | wc -l`.to_i
  component_usage[component_name] = usage_count
end

# 사용 빈도 순으로 정렬
sorted_components = component_usage.sort_by { |name, count| -count }
puts "High Priority Components (used 10+ times):"
sorted_components.select { |name, count| count >= 10 }.each do |name, count|
  puts "#{name}: #{count} times"
end
```

#### 1.3 의존성 맵핑
- 어떤 컴포넌트가 다른 컴포넌트를 참조하는지 분석
- 순환 의존성 확인
- 리팩토링 순서 결정

### Phase 2: 기반 구조 구축 (1주)

#### 2.1 디렉토리 구조 생성
```bash
# 새로운 컴포넌트 디렉토리 구조 생성
mkdir -p app/views/components/{atoms,molecules,organisms,templates}
mkdir -p app/views/components/atoms/{buttons,inputs,badges,icons,indicators}
mkdir -p app/views/components/molecules/{forms,cards,navigation,modals,alerts}
mkdir -p app/views/components/organisms/{layout,tables,forms,dashboard}
mkdir -p app/views/components/templates/{admin,auth,dashboard,form}
```

#### 2.2 헬퍼 메서드 생성
```ruby
# app/helpers/component_helper.rb
module ComponentHelper
  def component(component_path, **options, &block)
    render "components/#{component_path}", **options, &block
  end
  
  def atom(component_name, **options, &block)
    component("atoms/#{component_name}", **options, &block)
  end
  
  def molecule(component_name, **options, &block)
    component("molecules/#{component_name}", **options, &block)
  end
  
  def organism(component_name, **options, &block)
    component("organisms/#{component_name}", **options, &block)
  end
end
```

#### 2.3 컴포넌트 Base Class
```ruby
# app/components/base_component.rb
class BaseComponent
  include ActionView::Helpers
  
  def initialize(**attributes)
    @attributes = attributes
  end
  
  private
  
  attr_reader :attributes
  
  def css_classes(*classes)
    classes.compact.join(' ')
  end
  
  def data_attributes
    attributes.select { |key, _| key.to_s.start_with?('data_') }
              .transform_keys { |key| key.to_s.gsub('data_', 'data-') }
  end
end
```

### Phase 3: 우선순위 컴포넌트 마이그레이션 (2주)

#### 3.1 Week 1: Atoms 마이그레이션

**Day 1-2: Buttons**
```erb
<!-- AS-IS: 기존 버튼들 -->
app/views/shared/_button_primary.html.erb
app/views/shared/_button_secondary.html.erb
app/views/forms/_submit_button.html.erb

<!-- TO-BE: 통합된 버튼 컴포넌트 -->
app/views/components/atoms/buttons/_primary.html.erb
app/views/components/atoms/buttons/_secondary.html.erb
app/views/components/atoms/buttons/_icon.html.erb
```

**마이그레이션 스크립트:**
```ruby
# scripts/migrate_buttons.rb
class ButtonMigrator
  def migrate!
    # 1. 기존 버튼 컴포넌트들 찾기
    old_buttons = find_button_partials
    
    # 2. 새로운 버튼 컴포넌트 생성
    create_new_button_components(old_buttons)
    
    # 3. 사용처 업데이트
    update_button_usage
    
    # 4. 기존 파일 백업 후 삭제
    backup_and_remove_old_files(old_buttons)
  end
  
  private
  
  def find_button_partials
    Dir.glob("app/views/**/_*button*.html.erb")
  end
  
  def create_new_button_components(old_buttons)
    # 기존 버튼들을 분석하여 새로운 컴포넌트 생성
  end
  
  def update_button_usage
    # 모든 view 파일에서 버튼 사용법 업데이트
    Dir.glob("app/views/**/*.html.erb").each do |file|
      content = File.read(file)
      updated_content = content.gsub(/render\s+['"]shared\/button_primary['"]/, 
                                     "atom('buttons/primary')")
      File.write(file, updated_content) if content != updated_content
    end
  end
end
```

**Day 3-4: Form Elements**
```erb
<!-- AS-IS -->
app/views/shared/_form_field.html.erb
app/views/forms/_text_input.html.erb
app/views/forms/_select_input.html.erb

<!-- TO-BE -->
app/views/components/atoms/inputs/_text.html.erb
app/views/components/atoms/inputs/_select.html.erb
app/views/components/atoms/inputs/_textarea.html.erb
```

**Day 5: Status Indicators**
```erb
<!-- AS-IS -->
app/views/shared/_status_badge.html.erb
app/views/shared/_loading_spinner.html.erb

<!-- TO-BE -->
app/views/components/atoms/badges/_status.html.erb
app/views/components/atoms/indicators/_spinner.html.erb
```

#### 3.2 Week 2: Molecules 마이그레이션

**Day 1-2: Form Components**
```erb
<!-- AS-IS -->
app/views/shared/_form_group.html.erb
app/views/shared/_search_form.html.erb

<!-- TO-BE -->
app/views/components/molecules/forms/_field.html.erb
app/views/components/molecules/forms/_search.html.erb
```

**Day 3-4: Card Components**
```erb
<!-- AS-IS -->
app/views/expense_sheets/_expense_card.html.erb
app/views/dashboard/_stats_card.html.erb

<!-- TO-BE -->
app/views/components/molecules/cards/_expense.html.erb
app/views/components/molecules/cards/_stats.html.erb
```

**Day 5: Navigation Components**
```erb
<!-- AS-IS -->
app/views/shared/_breadcrumb.html.erb
app/views/shared/_pagination.html.erb

<!-- TO-BE -->
app/views/components/molecules/navigation/_breadcrumb.html.erb
app/views/components/molecules/navigation/_pagination.html.erb
```

### Phase 4: 복잡한 컴포넌트 마이그레이션 (2주)

#### 4.1 Organisms 마이그레이션
- Layout Components (Header, Sidebar, Footer)
- Data Tables
- Complex Forms
- Dashboard Components

#### 4.2 Templates 구성
- Page Templates
- Layout Templates
- Form Templates

### Phase 5: 테스트 및 최적화 (1주)

#### 5.1 컴포넌트 테스트
```ruby
# test/components/atoms/buttons/primary_test.rb
require 'test_helper'

class PrimaryButtonTest < ActionView::TestCase
  test "renders with default attributes" do
    html = atom('buttons/primary', text: 'Click me')
    
    assert_includes html, 'Click me'
    assert_includes html, 'btn-primary'
  end
  
  test "accepts custom classes" do
    html = atom('buttons/primary', text: 'Click me', class: 'custom-class')
    
    assert_includes html, 'custom-class'
  end
end
```

#### 5.2 성능 최적화
- 렌더링 성능 측정
- 불필요한 의존성 제거
- 컴포넌트 번들 최적화

## 🛠 마이그레이션 도구

### 1. 컴포넌트 분석 스크립트
```ruby
# scripts/analyze_components.rb
#!/usr/bin/env ruby

class ComponentAnalyzer
  def analyze
    puts "=== Component Analysis Report ==="
    puts "Total partials: #{total_partials}"
    puts "Most used partials:"
    most_used_partials.each do |name, count|
      puts "  #{name}: #{count} times"
    end
    
    puts "\nDuplicate functionality detected:"
    find_duplicates.each do |group|
      puts "  Similar: #{group.join(', ')}"
    end
  end
  
  private
  
  def total_partials
    Dir.glob("app/views/**/_*.html.erb").count
  end
  
  def most_used_partials
    # Implementation here
  end
  
  def find_duplicates
    # Implementation here
  end
end

ComponentAnalyzer.new.analyze if __FILE__ == $0
```

### 2. 자동 마이그레이션 스크립트
```ruby
# scripts/auto_migrate.rb
class AutoMigrator
  def migrate_component(old_path, new_path, usage_pattern)
    # 1. 새 컴포넌트 생성
    create_new_component(old_path, new_path)
    
    # 2. 사용처 업데이트
    update_usage_pattern(usage_pattern, new_path)
    
    # 3. 기존 파일 백업
    backup_old_file(old_path)
  end
end
```

### 3. 검증 스크립트
```ruby
# scripts/validate_migration.rb
class MigrationValidator
  def validate
    puts "Checking for broken renders..."
    broken_renders = find_broken_renders
    
    if broken_renders.empty?
      puts "✅ All renders are working correctly"
    else
      puts "❌ Found broken renders:"
      broken_renders.each { |render| puts "  #{render}" }
    end
  end
end
```

## 📋 마이그레이션 체크리스트

### Pre-Migration
- [ ] 현재 컴포넌트 인벤토리 완성
- [ ] 사용 빈도 분석 완료
- [ ] 의존성 맵핑 완료
- [ ] 백업 계획 수립

### During Migration
- [ ] 새 컴포넌트 구조 생성
- [ ] 헬퍼 메서드 구현
- [ ] 우선순위 컴포넌트 마이그레이션
- [ ] 사용처 업데이트
- [ ] 테스트 케이스 작성

### Post-Migration
- [ ] 모든 렌더링 오류 해결
- [ ] 성능 테스트 통과
- [ ] 문서 업데이트
- [ ] 팀 교육 완료
- [ ] 기존 파일 정리

## 🔄 롤백 계획

### 문제 발생 시
1. **즉시 롤백**: 백업된 파일로 복원
2. **부분 롤백**: 문제 컴포넌트만 이전 버전으로 복원
3. **점진적 수정**: 문제를 수정하면서 마이그레이션 계속

### 백업 전략
- 매일 자동 백업
- 각 Phase 완료 시 스냅샷
- Git 브랜치로 마이그레이션 과정 추적

## 📊 성공 지표

### 정량적 지표
- [ ] 컴포넌트 수 감소 (118개 → 목표 50개 이하)
- [ ] 코드 중복 제거 (목표 80% 감소)
- [ ] 렌더링 성능 개선 (목표 20% 향상)
- [ ] 번들 크기 최적화 (목표 15% 감소)

### 정성적 지표
- [ ] 개발자 경험 개선
- [ ] 코드 가독성 향상
- [ ] 유지보수성 개선
- [ ] 디자인 일관성 확보