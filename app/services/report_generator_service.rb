class ReportGeneratorService
  def initialize(report_export)
    @report_export = report_export
    @template = report_export.report_template
    @filters = @template&.filters || {}
    @columns = @template&.columns || default_columns
  end

  def generate
    @report_export.update!(status: 'processing', started_at: Time.current)
    
    begin
      data = fetch_data
      file_path = case @template&.export_format || 'excel'
                  when 'excel'
                    generate_excel(data)
                  when 'pdf'
                    generate_pdf(data)
                  when 'csv'
                    generate_csv(data)
                  else
                    raise "지원하지 않는 형식입니다: #{@template.export_format}"
                  end

      # Active Storage에 파일 첨부
      @report_export.export_file.attach(
        io: File.open(file_path),
        filename: File.basename(file_path)
      )

      @report_export.update!(
        status: 'completed',
        completed_at: Time.current,
        total_records: data.size,
        file_path: file_path
      )

      # 임시 파일 삭제
      File.delete(file_path) if File.exist?(file_path)

      @report_export
    rescue => e
      @report_export.update!(status: 'failed', completed_at: Time.current)
      Rails.logger.error "리포트 생성 실패: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def fetch_data
    query = ExpenseItem.joins(expense_sheet: [:user, :organization])
                      .includes(:expense_code, expense_sheet: [:user, :organization])

    # 필터 적용
    query = apply_filters(query)

    # 데이터 변환
    query.map do |item|
      build_row_data(item)
    end
  end

  def apply_filters(query)
    # 기간 필터
    if @filters['date_from'].present?
      query = query.where('expense_sheets.created_at >= ?', @filters['date_from'])
    end
    
    if @filters['date_to'].present?
      query = query.where('expense_sheets.created_at <= ?', @filters['date_to'])
    end

    # 조직 필터
    if @filters['organization_id'].present?
      query = query.where(expense_sheets: { organization_id: @filters['organization_id'] })
    end

    # 사용자 필터
    if @filters['user_id'].present?
      query = query.where(expense_sheets: { user_id: @filters['user_id'] })
    end

    # 경비 코드 필터
    if @filters['expense_code_id'].present?
      query = query.where(expense_code_id: @filters['expense_code_id'])
    end

    # 상태 필터
    if @filters['status'].present?
      query = query.where(expense_sheets: { status: @filters['status'] })
    end

    # Cost Center 필터
    if @filters['cost_center_id'].present?
      query = query.where(expense_sheets: { cost_center_id: @filters['cost_center_id'] })
    end

    query
  end

  def build_row_data(item)
    sheet = item.expense_sheet

    {
      'date' => item.date.strftime('%Y-%m-%d'),
      'user_name' => sheet.user.name,
      'organization_name' => sheet.organization.name,
      'expense_code' => item.expense_code.name,
      'amount' => item.amount,
      'description' => item.description,
      'status' => I18n.t("expense_sheet.status.#{sheet.status}"),
      'year_month' => "#{sheet.year}년 #{sheet.month}월",
      'remarks' => item.remarks,
      'cost_center' => sheet.cost_center&.name
    }
  end

  def generate_excel(data)
    require 'spreadsheet'
    
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet(name: '경비 리포트')

    # 헤더 추가
    headers = @columns.map { |col| column_label(col) }
    sheet.row(0).concat headers

    # 헤더 스타일
    header_format = Spreadsheet::Format.new(
      weight: :bold,
      pattern: 1,
      pattern_fg_color: :silver
    )
    sheet.row(0).default_format = header_format

    # 데이터 추가
    data.each_with_index do |row, idx|
      values = @columns.map { |col| row[col] }
      sheet.row(idx + 1).concat values
    end

    # 컬럼 너비 자동 조정
    @columns.each_with_index do |_, idx|
      sheet.column(idx).width = 15
    end

    # 파일 저장
    file_path = Rails.root.join('tmp', "report_#{Time.current.to_i}.xls")
    book.write file_path.to_s
    file_path.to_s
  end

  def generate_pdf(data)
    require 'prawn'
    require 'prawn/table'

    file_path = Rails.root.join('tmp', "report_#{Time.current.to_i}.pdf")

    Prawn::Document.generate(file_path.to_s, page_layout: :landscape) do |pdf|
      # 제목
      pdf.font Rails.root.join('public', 'fonts', 'NotoSansKR-Regular.ttf').to_s rescue pdf.font('Helvetica')
      pdf.text '경비 리포트', size: 20, style: :bold
      pdf.move_down 10
      pdf.text "생성일: #{Time.current.strftime('%Y-%m-%d %H:%M')}", size: 10
      pdf.move_down 20

      # 테이블 데이터 준비
      headers = @columns.map { |col| column_label(col) }
      rows = data.map do |row|
        @columns.map { |col| format_value(row[col]) }
      end

      # 테이블 생성
      pdf.table([headers] + rows, 
        header: true,
        cell_style: { size: 8, padding: 5 },
        row_colors: ['F0F0F0', 'FFFFFF']
      ) do |table|
        table.row(0).font_style = :bold
        table.row(0).background_color = 'CCCCCC'
      end

      # 요약 정보
      pdf.move_down 20
      pdf.text "총 #{data.size}건", size: 10
      if data.any?
        total_amount = data.sum { |row| row['amount'].to_f }
        pdf.text "총 금액: #{number_to_currency(total_amount)}", size: 10
      end
    end

    file_path.to_s
  end

  def generate_csv(data)
    require 'csv'

    file_path = Rails.root.join('tmp', "report_#{Time.current.to_i}.csv")

    CSV.open(file_path, 'w', encoding: 'UTF-8') do |csv|
      # 헤더
      headers = @columns.map { |col| column_label(col) }
      csv << headers

      # 데이터
      data.each do |row|
        values = @columns.map { |col| format_value(row[col]) }
        csv << values
      end
    end

    file_path.to_s
  end

  def column_label(column)
    labels = {
      'date' => '사용일',
      'user_name' => '사용자',
      'organization_name' => '조직',
      'expense_code' => '경비 코드',
      'amount' => '금액',
      'description' => '설명',
      'status' => '상태',
      'approved_at' => '승인일시',
      'year_month' => '귀속월',
      'remarks' => '비고',
      'cost_center' => 'Cost Center',
      'approver' => '승인자',
      'rejection_reason' => '반려 사유'
    }
    labels[column] || column
  end

  def format_value(value)
    case value
    when nil
      ''
    when Numeric
      value.to_s
    when Date, Time, DateTime
      value.strftime('%Y-%m-%d %H:%M')
    else
      value.to_s
    end
  end

  def number_to_currency(amount)
    return "₩0" if amount.nil? || amount == 0
    
    # 천 단위 구분 쉼표 추가
    formatted = amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    "₩#{formatted}"
  end

  def default_columns
    %w[date user_name organization_name expense_code amount description status]
  end
end