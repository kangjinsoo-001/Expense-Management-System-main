# 조직 구조 생성
puts "Creating organization structure..."

# 조직 매핑을 위한 해시
org_mapping = {}

# 루트 조직 - 휴먼컨설팅그룹
hcg_root = Organization.create!(
  code: "HCG001",
  name: "휴먼컨설팅그룹"
)
org_mapping["C5A4710A375A11EEA69E0A31B96280A2"] = hcg_root

# CPO & Consulting/SaaS COO
cpo_coo = Organization.create!(
  code: "HCG002",
  name: "CPO & Consulting/SaaS COO",
  parent: hcg_root
)
org_mapping["6F70E389884111EE997C0ED793F03E8E"] = cpo_coo

# Consulting BU
consulting_bu = Organization.create!(
  code: "HCG003",
  name: "Consulting BU",
  parent: cpo_coo
)
org_mapping["C5A48186375A11EEA69E0A31B96280A2"] = consulting_bu

# AI x HR R&D Center
ai_hr_rnd = Organization.create!(
  code: "HCG004",
  name: "AI x HR R&D Center",
  parent: cpo_coo
)
org_mapping["FF698398DED2484D9F396D5A654F9609"] = ai_hr_rnd

# talenx BU
talenx_bu = Organization.create!(
  code: "HCG005",
  name: "talenx BU",
  parent: cpo_coo
)
org_mapping["C5A4F45C375A11EEA69E0A31B96280A2"] = talenx_bu

# talenx R&D센터
talenx_rnd = Organization.create!(
  code: "HCG006",
  name: "talenx R&D센터",
  parent: talenx_bu
)
org_mapping["04100DEA1D8B49249EFF7DA7A2CBC1B0"] = talenx_rnd

# talenx R&D팀
talenx_rnd_team = Organization.create!(
  code: "HCG007",
  name: "talenx R&D팀",
  parent: talenx_rnd
)
org_mapping["7B07EDC2D3F94F91AB1B7A72072D31C2"] = talenx_rnd_team

# Payroll R&D팀
payroll_rnd_team = Organization.create!(
  code: "HCG008",
  name: "Payroll R&D팀",
  parent: talenx_rnd
)
org_mapping["65FFA078CDAF4CA2A8F53395085608EA"] = payroll_rnd_team

# 정보보호 R&D팀
security_rnd_team = Organization.create!(
  code: "HCG009",
  name: "정보보호 R&D팀",
  parent: talenx_rnd
)
org_mapping["211809C4C48A46CC8947618CB1C92652"] = security_rnd_team

# CISO
ciso = Organization.create!(
  code: "HCG010",
  name: "CISO",
  parent: hcg_root
)
org_mapping["6F732369884111EE997C0ED793F03E8E"] = ciso

# 정보보호팀
security_team = Organization.create!(
  code: "HCG011",
  name: "정보보호팀",
  parent: ciso
)
org_mapping["6F732D8E884111EE997C0ED793F03E8E"] = security_team

# hunel COO
hunel_coo = Organization.create!(
  code: "HCG012",
  name: "hunel COO",
  parent: hcg_root
)
org_mapping["F29A24E2AA3111EE997C0ED793F03E8E"] = hunel_coo

# hunel BU : Cha
hunel_bu_cha = Organization.create!(
  code: "HCG013",
  name: "hunel BU : Cha",
  parent: hunel_coo
)
org_mapping["C5A4FA97375A11EEA69E0A31B96280A2"] = hunel_bu_cha

# SA Chapter
sa_chapter = Organization.create!(
  code: "HCG014",
  name: "SA Chapter",
  parent: hunel_bu_cha
)
org_mapping["E697C555405611EFAD4F0A5ED9FF2325"] = sa_chapter

# PPA Chapter
ppa_chapter = Organization.create!(
  code: "HCG015",
  name: "PPA Chapter",
  parent: hunel_bu_cha
)
org_mapping["E697C7C0405611EFAD4F0A5ED9FF2325"] = ppa_chapter

# hunel BU : Nel
hunel_bu_nel = Organization.create!(
  code: "HCG016",
  name: "hunel BU : Nel",
  parent: hunel_coo
)
org_mapping["C5A515AA375A11EEA69E0A31B96280A2"] = hunel_bu_nel

# PB Chapter
pb_chapter = Organization.create!(
  code: "HCG017",
  name: "PB Chapter",
  parent: hunel_bu_nel
)
org_mapping["E697C860405611EFAD4F0A5ED9FF2325"] = pb_chapter

# TA Chapter
ta_chapter = Organization.create!(
  code: "HCG018",
  name: "TA Chapter",
  parent: hunel_bu_nel
)
org_mapping["E697C8E0405611EFAD4F0A5ED9FF2325"] = ta_chapter

# hunel BU : Mén
hunel_bu_men = Organization.create!(
  code: "HCG019",
  name: "hunel BU : Mén",
  parent: hunel_coo
)
org_mapping["F29A2383AA3111EE997C0ED793F03E8E"] = hunel_bu_men

# HC Chapter
hc_chapter = Organization.create!(
  code: "HCG020",
  name: "HC Chapter",
  parent: hunel_bu_men
)
org_mapping["E697C959405611EFAD4F0A5ED9FF2325"] = hc_chapter

# TM Chapter
tm_chapter = Organization.create!(
  code: "HCG021",
  name: "TM Chapter",
  parent: hunel_bu_men
)
org_mapping["E697C9CC405611EFAD4F0A5ED9FF2325"] = tm_chapter

# hunel R&D센터
hunel_rnd = Organization.create!(
  code: "HCG022",
  name: "hunel R&D센터",
  parent: hunel_coo
)
org_mapping["C5A53177375A11EEA69E0A31B96280A2"] = hunel_rnd

# Package R&D팀
package_rnd_team = Organization.create!(
  code: "HCG023",
  name: "Package R&D팀",
  parent: hunel_rnd
)
org_mapping["5D2D857B526B46EA942AD1F1E911B54B"] = package_rnd_team

# CS BU
cs_bu = Organization.create!(
  code: "HCG024",
  name: "CS BU",
  parent: hunel_coo
)
org_mapping["F29A1A71AA3111EE997C0ED793F03E8E"] = cs_bu

# hunel CS팀
hunel_cs_team = Organization.create!(
  code: "HCG025",
  name: "hunel CS팀",
  parent: cs_bu
)
org_mapping["F29A2031AA3111EE997C0ED793F03E8E"] = hunel_cs_team

# JaDE CS팀
jade_cs_team = Organization.create!(
  code: "HCG026",
  name: "JaDE CS팀",
  parent: cs_bu
)
org_mapping["F29A220CAA3111EE997C0ED793F03E8E"] = jade_cs_team

# 고도화 개발팀
upgrade_dev_team = Organization.create!(
  code: "HCG027",
  name: "고도화 개발팀",
  parent: cs_bu
)
org_mapping["52377807DFDC44C4B6116EEF9F6F424A"] = upgrade_dev_team

# Package UX팀
package_ux_team = Organization.create!(
  code: "HCG028",
  name: "Package UX팀",
  parent: hunel_coo
)
org_mapping["C5A54338375A11EEA69E0A31B96280A2"] = package_ux_team

# JaDE BU
jade_bu = Organization.create!(
  code: "HCG029",
  name: "JaDE BU",
  parent: hcg_root
)
org_mapping["C5A547A3375A11EEA69E0A31B96280A2"] = jade_bu

# JaDE Front Team
jade_front_team = Organization.create!(
  code: "HCG030",
  name: "JaDE Front Team",
  parent: jade_bu
)
org_mapping["C5A54C52375A11EEA69E0A31B96280A2"] = jade_front_team

# PO BU
po_bu = Organization.create!(
  code: "HCG031",
  name: "PO BU",
  parent: hcg_root
)
org_mapping["C5A56064375A11EEA69E0A31B96280A2"] = po_bu

# Payroll 전략팀
payroll_strategy_team = Organization.create!(
  code: "HCG032",
  name: "Payroll 전략팀",
  parent: po_bu
)
org_mapping["C5A564FC375A11EEA69E0A31B96280A2"] = payroll_strategy_team

# Payroll 서비스팀
payroll_service_team = Organization.create!(
  code: "HCG033",
  name: "Payroll 서비스팀",
  parent: po_bu
)
org_mapping["C5A56BD8375A11EEA69E0A31B96280A2"] = payroll_service_team

# 마케팅본부
marketing_hq = Organization.create!(
  code: "HCG034",
  name: "마케팅본부",
  parent: hcg_root
)
org_mapping["C5A574FD375A11EEA69E0A31B96280A2"] = marketing_hq

# 마케팅 MS Team
marketing_ms_team = Organization.create!(
  code: "HCG035",
  name: "마케팅 MS Team",
  parent: marketing_hq
)
org_mapping["C5A5CF5E375A11EEA69E0A31B96280A2"] = marketing_ms_team

# 마케팅 PF Team
marketing_pf_team = Organization.create!(
  code: "HCG036",
  name: "마케팅 PF Team",
  parent: marketing_hq
)
org_mapping["C5A5D557375A11EEA69E0A31B96280A2"] = marketing_pf_team

# BSS CENTER
bss_center = Organization.create!(
  code: "HCG037",
  name: "BSS CENTER",
  parent: hcg_root
)
org_mapping["C5A5D9B1375A11EEA69E0A31B96280A2"] = bss_center

# Admin Team
admin_team = Organization.create!(
  code: "HCG038",
  name: "Admin Team",
  parent: bss_center
)
org_mapping["C5A5DDE3375A11EEA69E0A31B96280A2"] = admin_team

# Design Team
design_team = Organization.create!(
  code: "HCG039",
  name: "Design Team",
  parent: bss_center
)
org_mapping["C5A5E201375A11EEA69E0A31B96280A2"] = design_team

# P&C Team
pc_team = Organization.create!(
  code: "HCG040",
  name: "P&C Team",
  parent: bss_center
)
org_mapping["C5A5E629375A11EEA69E0A31B96280A2"] = pc_team

puts "Created #{Organization.count} organizations"

# 조직 매핑 정보를 다른 시드 파일에서 사용할 수 있도록 Rails 캐시에 저장
Rails.cache.write('org_mapping', org_mapping)
Rails.cache.write('organization_data', {
  hcg_root: hcg_root,
  cpo_coo: cpo_coo,
  consulting_bu: consulting_bu,
  ai_hr_rnd: ai_hr_rnd,
  talenx_bu: talenx_bu,
  talenx_rnd: talenx_rnd,
  talenx_rnd_team: talenx_rnd_team,
  payroll_rnd_team: payroll_rnd_team,
  security_rnd_team: security_rnd_team,
  ciso: ciso,
  security_team: security_team,
  hunel_coo: hunel_coo,
  hunel_bu_cha: hunel_bu_cha,
  sa_chapter: sa_chapter,
  ppa_chapter: ppa_chapter,
  hunel_bu_nel: hunel_bu_nel,
  pb_chapter: pb_chapter,
  ta_chapter: ta_chapter,
  hunel_bu_men: hunel_bu_men,
  hc_chapter: hc_chapter,
  tm_chapter: tm_chapter,
  hunel_rnd: hunel_rnd,
  package_rnd_team: package_rnd_team,
  cs_bu: cs_bu,
  hunel_cs_team: hunel_cs_team,
  jade_cs_team: jade_cs_team,
  upgrade_dev_team: upgrade_dev_team,
  package_ux_team: package_ux_team,
  jade_bu: jade_bu,
  jade_front_team: jade_front_team,
  po_bu: po_bu,
  payroll_strategy_team: payroll_strategy_team,
  payroll_service_team: payroll_service_team,
  marketing_hq: marketing_hq,
  marketing_ms_team: marketing_ms_team,
  marketing_pf_team: marketing_pf_team,
  bss_center: bss_center,
  admin_team: admin_team,
  design_team: design_team,
  pc_team: pc_team
})

# Path 검증
puts "\n=== Organization Path 검증 ==="
invalid_paths = []
Organization.all.each do |org|
  # Path 형식 검증
  if org.path.blank?
    invalid_paths << "#{org.name} (ID: #{org.id}): Path가 비어있음"
  elsif org.path.include?('..')
    invalid_paths << "#{org.name} (ID: #{org.id}): Path에 연속된 점 포함 (#{org.path})"
  elsif !org.path.match?(/\A\d+(\.\d+)*\z/)
    invalid_paths << "#{org.name} (ID: #{org.id}): Path 형식 오류 (#{org.path})"
  end
  
  # Path 논리 검증 (parent와 일치하는지)
  if org.parent
    expected_path = "#{org.parent.path}.#{org.id}"
    if org.path != expected_path
      invalid_paths << "#{org.name} (ID: #{org.id}): Path 불일치 (예상: #{expected_path}, 실제: #{org.path})"
    end
  end
end

if invalid_paths.any?
  puts "⚠️ 잘못된 Path 발견:"
  invalid_paths.each { |msg| puts "  - #{msg}" }
  puts "\nPath 자동 수정 중..."
  
  # Path 재구성
  Organization.where(parent_id: nil).each do |root|
    def rebuild_org_path(org, parent_path = nil)
      if parent_path.nil?
        new_path = org.id.to_s
      else
        new_path = "#{parent_path}.#{org.id}"
      end
      
      if org.path != new_path
        org.update_column(:path, new_path)
        puts "  수정: #{org.name} - #{org.path} -> #{new_path}"
      end
      
      org.children.each { |child| rebuild_org_path(child, new_path) }
    end
    
    rebuild_org_path(root)
  end
  
  puts "✅ Path 수정 완료"
else
  puts "✅ 모든 조직의 Path가 정상입니다"
end