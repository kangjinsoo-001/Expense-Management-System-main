class AuditLog < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :user

  serialize :changed_from, coder: JSON
  serialize :changed_to, coder: JSON
  serialize :metadata, coder: JSON

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_type, ->(type) { where(auditable_type: type) }
end
