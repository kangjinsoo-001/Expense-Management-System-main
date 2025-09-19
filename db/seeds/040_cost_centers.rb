# 코스트 센터 생성
puts "Creating cost centers..."

# 조직 데이터 직접 조회
org_data = {}
org_data[:talenx_bu] = Organization.find_by(name: 'talenx BU')
org_data[:hunel_bu_cha] = Organization.find_by(name: 'hunel BU : Cha')
org_data[:hunel_bu_nel] = Organization.find_by(name: 'hunel BU : Nel')
org_data[:hunel_bu_men] = Organization.find_by(name: 'hunel BU : Mén')
org_data[:consulting_bu] = Organization.find_by(name: 'Consulting BU')
org_data[:hcg_root] = Organization.find_by(name: '휴먼컨설팅그룹')
org_data[:ciso] = Organization.find_by(name: 'CISO')
org_data[:security_team] = Organization.find_by(name: '정보보호팀')
org_data[:jade_bu] = Organization.find_by(name: 'JaDE BU')
org_data[:po_bu] = Organization.find_by(name: 'PO BU')
org_data[:marketing_hq] = Organization.find_by(name: 'MKT본부')
org_data[:bss_center] = Organization.find_by(name: 'BSS CENTER')
org_data[:ai_hr_rnd] = Organization.find_by(name: 'AI x HR R&D Center')

# 유지할 조직들의 코스트 센터만 생성
# talenx BU
if org_data[:talenx_bu]
  CostCenter.create!(
    code: "TALX001",
    name: "talenx BU",
    description: "talenx 사업부 예산",
    organization: org_data[:talenx_bu],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 3000000000
  )
end

# hunel BU
if org_data[:hunel_bu_cha] || org_data[:hunel_bu_nel] || org_data[:hunel_bu_men]
  # hunel BU 중 하나를 대표로 사용
  hunel_org = org_data[:hunel_bu_cha] || org_data[:hunel_bu_nel] || org_data[:hunel_bu_men]
  CostCenter.create!(
    code: "HUNL001",
    name: "hunel BU",
    description: "hunel 사업부 예산",
    organization: hunel_org,
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 4000000000
  )
end

# Consulting BU
if org_data[:consulting_bu]
  CostCenter.create!(
    code: "CONS001",
    name: "Consulting BU",
    description: "컨설팅 사업부 예산",
    organization: org_data[:consulting_bu],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 1500000000
  )
end

# HCG
if org_data[:hcg_root]
  CostCenter.create!(
    code: "HQ001",
    name: "HCG",
    description: "휴먼컨설팅그룹 본사 예산",
    organization: org_data[:hcg_root],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 5000000000
  )
end

# CISO
if org_data[:ciso] || org_data[:security_team]
  CostCenter.create!(
    code: "CISO001",
    name: "CISO",
    description: "정보보호 및 보안 예산",
    organization: org_data[:ciso] || org_data[:security_team],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 500000000
  )
end

# JaDE BU
if org_data[:jade_bu]
  CostCenter.create!(
    code: "JADE001",
    name: "JaDE BU",
    description: "JaDE 사업부 예산",
    organization: org_data[:jade_bu],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 1500000000
  )
end

# PO BU
if org_data[:po_bu]
  CostCenter.create!(
    code: "POBU001",
    name: "PO BU",
    description: "Payroll 사업부 예산",
    organization: org_data[:po_bu],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 1300000000
  )
end

# MKT본부
if org_data[:marketing_hq]
  CostCenter.create!(
    code: "MKTG001",
    name: "MKT본부",
    description: "마케팅 본부 예산",
    organization: org_data[:marketing_hq],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 800000000
  )
end

# BSS CENTER
if org_data[:bss_center]
  CostCenter.create!(
    code: "BSS001",
    name: "BSS CENTER",
    description: "경영지원센터 예산",
    organization: org_data[:bss_center],
    active: true,
    fiscal_year: Date.current.year,
    budget_amount: 600000000
  )
end

# 프로젝트별 코스트 센터
CostCenter.create!(
  code: "PROJ001",
  name: "삼성전자 HR 시스템 구축",
  description: "삼성전자 통합 HR 시스템 구축 프로젝트",
  organization: org_data[:consulting_bu],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 5000000000
)

CostCenter.create!(
  code: "PROJ002",
  name: "LG화학 급여 시스템 개선",
  description: "LG화학 급여 시스템 업그레이드 프로젝트",
  organization: org_data[:po_bu],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 2000000000
)

CostCenter.create!(
  code: "PROJ003",
  name: "SK그룹 talenx 도입",
  description: "SK그룹 전사 talenx 플랫폼 도입 프로젝트",
  organization: org_data[:talenx_bu],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 3500000000
)

CostCenter.create!(
  code: "PROJ004",
  name: "현대자동차 AI 채용 시스템",
  description: "현대자동차 AI 기반 채용 시스템 구축",
  organization: org_data[:ai_hr_rnd],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 2500000000
)

CostCenter.create!(
  code: "PROJ005",
  name: "KT 인사평가 시스템 개선",
  description: "KT 차세대 인사평가 시스템 구축",
  organization: org_data[:hunel_bu_cha] || org_data[:hunel_bu_nel] || org_data[:hunel_bu_men],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 1800000000
)

# 공통 코스트 센터 (모든 조직에서 사용 가능)
CostCenter.create!(
  code: "COMMON001",
  name: "공통 경비",
  description: "전사 공통 경비 예산",
  organization: org_data[:hcg_root],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 1000000000
)

CostCenter.create!(
  code: "EDU001",
  name: "교육/훈련비",
  description: "전사 교육 및 훈련 예산",
  organization: org_data[:hcg_root],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 500000000
)

CostCenter.create!(
  code: "WELFARE001",
  name: "복리후생비",
  description: "전사 복리후생 예산",
  organization: org_data[:hcg_root],
  active: true,
  fiscal_year: Date.current.year,
  budget_amount: 700000000
)

puts "Created #{CostCenter.count} cost centers"