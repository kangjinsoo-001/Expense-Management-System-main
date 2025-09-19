module ExpenseSheetsHelper
  def expense_sheet_status_text(status)
    case status
    when 'draft'
      '작성 중'
    when 'submitted'
      '제출됨'
    when 'approved'
      '승인됨'
    when 'rejected'
      '반려됨'
    else
      status
    end
  end

  def expense_sheet_status_class(status)
    case status
    when 'draft'
      'bg-gray-100 text-gray-800'
    when 'submitted'
      'bg-blue-100 text-blue-800'
    when 'approved'
      'bg-green-100 text-green-800'
    when 'rejected'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  def expense_sheet_status_icon(status)
    case status
    when 'draft'
      'edit'
    when 'submitted'
      'schedule'
    when 'approved'
      'check_circle'
    when 'rejected'
      'cancel'
    else
      'help'
    end
  end

  def format_currency(amount)
    number_to_currency(amount, unit: "₩", format: "%u%n", precision: 0, delimiter: ",")
  end
end