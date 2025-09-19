class ExpenseApproval < ApplicationRecord
  self.table_name = "approval_histories"
  
  belongs_to :expense_sheet, foreign_key: :approvable_id, optional: true
  belongs_to :approver, class_name: 'User', foreign_key: :approver_id
  belongs_to :approval_request, optional: true
  
  enum :status, { 
    pending: 'pending',
    approved: 'approved',
    rejected: 'rejected'
  }, prefix: true
  
  enum :action, {
    approve: 'approve',
    reject: 'reject',
    view: 'view',
    cancel: 'cancel'
  }, prefix: true
  
  scope :for_expense_sheets, -> { where(approvable_type: 'ExpenseSheet') }
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  
  # 가상 속성으로 order 제공
  def order
    step_order
  end
  
  def comments
    comment
  end
end