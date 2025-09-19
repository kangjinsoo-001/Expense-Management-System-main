# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_07_131244) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "approval_histories", force: :cascade do |t|
    t.integer "approval_request_id", null: false
    t.integer "approver_id", null: false
    t.integer "step_order", null: false
    t.string "role", null: false
    t.string "action", null: false
    t.text "comment"
    t.datetime "approved_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_approval_histories_on_action"
    t.index ["approval_request_id", "approver_id", "step_order"], name: "idx_approval_history_composite"
    t.index ["approval_request_id"], name: "index_approval_histories_on_approval_request_id"
    t.index ["approved_at"], name: "index_approval_histories_on_approved_at"
    t.index ["approver_id"], name: "index_approval_histories_on_approver_id"
  end

  create_table "approval_line_steps", force: :cascade do |t|
    t.integer "approval_line_id", null: false
    t.integer "approver_id", null: false
    t.integer "step_order", null: false
    t.string "role", null: false
    t.string "approval_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_line_id", "approver_id", "step_order"], name: "idx_unique_approver_per_step", unique: true
    t.index ["approval_line_id", "step_order"], name: "index_approval_line_steps_on_approval_line_id_and_step_order"
    t.index ["approval_line_id"], name: "index_approval_line_steps_on_approval_line_id"
    t.index ["approver_id"], name: "index_approval_line_steps_on_approver_id"
  end

  create_table "approval_lines", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_approval_lines_on_deleted_at"
    t.index ["user_id", "name"], name: "index_approval_lines_on_user_id_and_name", unique: true
    t.index ["user_id", "position"], name: "index_approval_lines_on_user_id_and_position"
    t.index ["user_id"], name: "index_approval_lines_on_user_id"
  end

  create_table "approval_request_steps", force: :cascade do |t|
    t.integer "approval_request_id", null: false
    t.integer "approver_id", null: false
    t.integer "step_order", null: false
    t.string "role", default: "approve", null: false
    t.string "approval_type"
    t.string "status", default: "pending"
    t.text "comment"
    t.datetime "actioned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_request_id", "step_order"], name: "idx_approval_request_steps_on_request_and_order"
    t.index ["approval_request_id"], name: "index_approval_request_steps_on_approval_request_id"
    t.index ["approver_id"], name: "index_approval_request_steps_on_approver_id"
    t.index ["status"], name: "index_approval_request_steps_on_status"
  end

  create_table "approval_requests", force: :cascade do |t|
    t.integer "expense_item_id"
    t.integer "approval_line_id"
    t.integer "current_step", default: 1, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "approval_line_name"
    t.json "approval_steps_data", default: []
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.string "approvable_type"
    t.integer "approvable_id"
    t.index ["approvable_type", "approvable_id"], name: "index_approval_requests_on_approvable"
    t.index ["approvable_type", "approvable_id"], name: "index_approval_requests_on_approvable_unique", unique: true
    t.index ["approvable_type"], name: "index_approval_requests_on_approvable_type"
    t.index ["approval_line_id"], name: "index_approval_requests_on_approval_line_id"
    t.index ["status"], name: "index_approval_requests_on_status"
  end

  create_table "approver_group_members", force: :cascade do |t|
    t.integer "approver_group_id", null: false
    t.integer "user_id", null: false
    t.integer "added_by_id", null: false
    t.datetime "added_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_approver_group_members_on_added_by_id"
    t.index ["approver_group_id", "user_id"], name: "index_approver_group_members_on_group_and_user", unique: true
    t.index ["approver_group_id"], name: "index_approver_group_members_on_approver_group_id"
    t.index ["user_id"], name: "index_approver_group_members_on_user_id"
  end

  create_table "approver_groups", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "priority", default: 5, null: false
    t.boolean "is_active", default: true, null: false
    t.integer "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_approver_groups_on_created_by_id"
    t.index ["is_active"], name: "index_approver_groups_on_is_active"
    t.index ["name"], name: "index_approver_groups_on_name", unique: true
    t.index ["priority"], name: "index_approver_groups_on_priority"
  end

  create_table "attachment_analysis_rules", force: :cascade do |t|
    t.integer "attachment_requirement_id", null: false
    t.text "prompt_text", null: false
    t.text "expected_fields"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_attachment_analysis_rules_on_active"
    t.index ["attachment_requirement_id"], name: "index_attachment_analysis_rules_on_attachment_requirement_id"
  end

  create_table "attachment_requirements", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "required", default: false, null: false
    t.text "file_types"
    t.text "condition_expression"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attachment_type", default: "expense_sheet", null: false
    t.index ["active"], name: "index_attachment_requirements_on_active"
    t.index ["attachment_type"], name: "index_attachment_requirements_on_attachment_type"
    t.index ["position"], name: "index_attachment_requirements_on_position"
  end

  create_table "attachment_validation_rules", force: :cascade do |t|
    t.integer "attachment_requirement_id", null: false
    t.string "rule_type", null: false
    t.text "prompt_text", null: false
    t.string "severity", default: "warning", null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_attachment_validation_rules_on_active"
    t.index ["attachment_requirement_id"], name: "index_attachment_validation_rules_on_attachment_requirement_id"
    t.index ["position"], name: "index_attachment_validation_rules_on_position"
    t.index ["rule_type"], name: "index_attachment_validation_rules_on_rule_type"
    t.index ["severity"], name: "index_attachment_validation_rules_on_severity"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "auditable_type", null: false
    t.integer "auditable_id", null: false
    t.integer "user_id", null: false
    t.string "action"
    t.text "changed_from"
    t.text "changed_to"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "cost_centers", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "organization_id", null: false
    t.integer "manager_id"
    t.integer "budget_amount"
    t.integer "fiscal_year"
    t.boolean "active", default: true
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code", "organization_id"], name: "index_cost_centers_on_code_and_organization_id", unique: true
    t.index ["fiscal_year"], name: "index_cost_centers_on_fiscal_year"
    t.index ["manager_id"], name: "index_cost_centers_on_manager_id"
    t.index ["organization_id"], name: "index_cost_centers_on_organization_id"
  end

  create_table "expense_attachments", force: :cascade do |t|
    t.integer "expense_item_id"
    t.string "file_name"
    t.string "file_type"
    t.integer "file_size"
    t.string "status", default: "pending"
    t.text "extracted_text"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "summary_data"
    t.string "receipt_type"
    t.string "processing_stage", default: "pending"
    t.boolean "ai_processed", default: false
    t.datetime "ai_processed_at"
    t.json "validation_result", default: {}
    t.boolean "validation_passed", default: false
    t.index ["ai_processed"], name: "index_expense_attachments_on_ai_processed"
    t.index ["expense_item_id"], name: "index_expense_attachments_on_expense_item_id"
    t.index ["processing_stage"], name: "index_expense_attachments_on_processing_stage"
    t.index ["receipt_type"], name: "index_expense_attachments_on_receipt_type"
    t.index ["status"], name: "index_expense_attachments_on_status"
    t.index ["validation_passed"], name: "index_expense_attachments_on_validation_passed"
  end

  create_table "expense_closing_statuses", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "organization_id", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.integer "status", default: 0, null: false
    t.datetime "closed_at"
    t.integer "closed_by_id"
    t.text "notes"
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0"
    t.integer "item_count", default: 0
    t.integer "expense_sheet_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_by_id"], name: "index_expense_closing_statuses_on_closed_by_id"
    t.index ["expense_sheet_id"], name: "index_expense_closing_statuses_on_expense_sheet_id"
    t.index ["organization_id", "year", "month"], name: "idx_expense_closing_org_year_month"
    t.index ["organization_id"], name: "index_expense_closing_statuses_on_organization_id"
    t.index ["status"], name: "index_expense_closing_statuses_on_status"
    t.index ["user_id", "year", "month"], name: "idx_expense_closing_user_year_month", unique: true
    t.index ["user_id"], name: "index_expense_closing_statuses_on_user_id"
  end

  create_table "expense_code_approval_rules", force: :cascade do |t|
    t.integer "expense_code_id", null: false
    t.string "condition", null: false
    t.integer "approver_group_id", null: false
    t.integer "order", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_group_id"], name: "index_expense_code_approval_rules_on_approver_group_id"
    t.index ["expense_code_id", "order"], name: "index_expense_code_approval_rules_on_expense_code_id_and_order"
    t.index ["expense_code_id"], name: "index_expense_code_approval_rules_on_expense_code_id"
    t.index ["is_active"], name: "index_expense_code_approval_rules_on_is_active"
  end

  create_table "expense_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.string "limit_amount"
    t.json "validation_rules", default: {}
    t.boolean "active", default: true
    t.integer "organization_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description_template"
    t.integer "version", default: 1, null: false
    t.integer "parent_code_id"
    t.date "effective_from"
    t.date "effective_to"
    t.boolean "is_current", default: true
    t.boolean "attachment_required", default: false, null: false
    t.integer "display_order", default: 0
    t.index ["code", "is_current"], name: "index_expense_codes_on_code_and_is_current"
    t.index ["code", "version"], name: "index_expense_codes_on_code_and_version", unique: true
    t.index ["code"], name: "index_expense_codes_on_code"
    t.index ["display_order"], name: "index_expense_codes_on_display_order"
    t.index ["effective_from", "effective_to"], name: "index_expense_codes_on_effective_from_and_effective_to"
    t.index ["organization_id"], name: "index_expense_codes_on_organization_id"
    t.index ["parent_code_id"], name: "index_expense_codes_on_parent_code_id"
  end

  create_table "expense_items", force: :cascade do |t|
    t.integer "expense_sheet_id", null: false
    t.integer "expense_code_id", null: false
    t.integer "cost_center_id"
    t.date "expense_date", null: false
    t.integer "amount", null: false
    t.string "description", null: false
    t.json "custom_fields"
    t.json "validation_errors"
    t.boolean "is_valid", default: false
    t.text "remarks"
    t.string "receipt_number"
    t.string "vendor_name"
    t.string "vendor_tax_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "generated_description"
    t.integer "approval_line_id"
    t.boolean "is_budget", default: false, null: false
    t.decimal "budget_amount", precision: 10, scale: 2
    t.decimal "actual_amount", precision: 10, scale: 2
    t.boolean "budget_exceeded", default: false
    t.text "excess_reason"
    t.datetime "budget_approved_at"
    t.datetime "actual_approved_at"
    t.integer "expense_attachments_count", default: 0, null: false
    t.boolean "is_draft", default: false, null: false
    t.json "draft_data", default: {}
    t.datetime "last_saved_at"
    t.integer "position"
    t.string "validation_status", default: "pending"
    t.text "validation_message"
    t.datetime "validated_at"
    t.boolean "requires_user_confirmation", default: false
    t.boolean "submission_blocked", default: false
    t.index ["approval_line_id"], name: "index_expense_items_on_approval_line_id"
    t.index ["budget_exceeded"], name: "index_expense_items_on_budget_exceeded"
    t.index ["cost_center_id"], name: "index_expense_items_on_cost_center_id"
    t.index ["expense_code_id", "expense_date"], name: "index_expense_items_on_code_and_date"
    t.index ["expense_code_id"], name: "index_expense_items_on_expense_code_id"
    t.index ["expense_date"], name: "index_expense_items_on_expense_date"
    t.index ["expense_sheet_id", "is_draft"], name: "index_expense_items_on_expense_sheet_id_and_is_draft"
    t.index ["expense_sheet_id", "is_valid"], name: "index_expense_items_on_sheet_and_valid"
    t.index ["expense_sheet_id", "position"], name: "index_expense_items_on_expense_sheet_id_and_position"
    t.index ["expense_sheet_id"], name: "index_expense_items_on_expense_sheet_id"
    t.index ["is_budget"], name: "index_expense_items_on_is_budget"
    t.index ["is_draft"], name: "index_expense_items_on_is_draft"
    t.index ["is_valid"], name: "index_expense_items_on_is_valid"
    t.index ["lock_version"], name: "index_expense_items_on_lock_version"
    t.index ["validation_status"], name: "index_expense_items_on_validation_status"
  end

  create_table "expense_sheet_approval_rules", force: :cascade do |t|
    t.integer "organization_id"
    t.integer "approver_group_id", null: false
    t.integer "submitter_group_id"
    t.string "submitter_condition"
    t.string "condition"
    t.string "rule_type"
    t.integer "order"
    t.boolean "is_active", default: true
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_group_id"], name: "index_expense_sheet_approval_rules_on_approver_group_id"
    t.index ["order"], name: "index_expense_sheet_approval_rules_on_order"
    t.index ["organization_id", "is_active"], name: "idx_on_organization_id_is_active_538269e301"
    t.index ["organization_id"], name: "index_expense_sheet_approval_rules_on_organization_id"
    t.index ["submitter_group_id"], name: "index_expense_sheet_approval_rules_on_submitter_group_id"
  end

  create_table "expense_sheet_attachments", force: :cascade do |t|
    t.integer "expense_sheet_id", null: false
    t.integer "attachment_requirement_id"
    t.text "extracted_text"
    t.text "analysis_result"
    t.text "validation_result"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "processing_stage", default: "pending"
    t.index ["attachment_requirement_id"], name: "index_expense_sheet_attachments_on_attachment_requirement_id"
    t.index ["expense_sheet_id", "attachment_requirement_id"], name: "index_expense_sheet_attachments_on_sheet_and_requirement"
    t.index ["expense_sheet_id"], name: "index_expense_sheet_attachments_on_expense_sheet_id"
    t.index ["processing_stage"], name: "index_expense_sheet_attachments_on_processing_stage"
    t.index ["status"], name: "index_expense_sheet_attachments_on_status"
  end

  create_table "expense_sheets", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "organization_id", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.string "status", default: "draft", null: false
    t.integer "total_amount", default: 0
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.integer "approved_by_id"
    t.text "remarks"
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cost_center_id"
    t.integer "expense_items_count", default: 0, null: false
    t.integer "approval_line_id"
    t.json "validation_result", default: {}
    t.string "validation_status", default: "pending"
    t.datetime "validated_at"
    t.boolean "ready_for_submission", default: false
    t.index ["approval_line_id"], name: "index_expense_sheets_on_approval_line_id"
    t.index ["approved_by_id"], name: "index_expense_sheets_on_approved_by_id"
    t.index ["cost_center_id"], name: "index_expense_sheets_on_cost_center_id"
    t.index ["organization_id", "status"], name: "index_expense_sheets_on_org_status"
    t.index ["organization_id"], name: "index_expense_sheets_on_organization_id"
    t.index ["status", "year", "month"], name: "index_expense_sheets_on_status_year_month"
    t.index ["status"], name: "index_expense_sheets_on_status"
    t.index ["submitted_at"], name: "index_expense_sheets_on_submitted_at"
    t.index ["user_id", "year", "month"], name: "index_expense_sheets_on_user_id_and_year_and_month", unique: true
    t.index ["user_id"], name: "index_expense_sheets_on_user_id"
    t.index ["validation_result"], name: "index_expense_sheets_on_validation_result"
    t.index ["validation_status"], name: "index_expense_sheets_on_validation_status"
  end

  create_table "expense_validation_histories", force: :cascade do |t|
    t.integer "expense_sheet_id", null: false
    t.integer "validated_by_id", null: false
    t.text "validation_summary"
    t.boolean "all_valid", default: false
    t.json "validation_details", default: {}
    t.json "issues_found", default: []
    t.json "recommendations", default: []
    t.json "attachment_data", default: {}
    t.json "expense_items_data", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "full_validation_context", default: {}
    t.index ["expense_sheet_id", "created_at"], name: "index_validation_histories_on_sheet_and_created"
    t.index ["expense_sheet_id"], name: "index_expense_validation_histories_on_expense_sheet_id"
    t.index ["validated_by_id"], name: "index_expense_validation_histories_on_validated_by_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.integer "parent_id"
    t.integer "manager_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "users_count", default: 0, null: false
    t.string "path"
    t.index ["code"], name: "index_organizations_on_code", unique: true
    t.index ["deleted_at"], name: "index_organizations_on_deleted_at"
    t.index ["manager_id"], name: "index_organizations_on_manager_id"
    t.index ["parent_id"], name: "index_organizations_on_parent_id"
    t.index ["path"], name: "index_organizations_on_path"
  end

  create_table "pdf_analysis_results", force: :cascade do |t|
    t.integer "expense_sheet_id", null: false
    t.string "attachment_id"
    t.text "extracted_text"
    t.json "analysis_data"
    t.string "card_type"
    t.integer "total_amount"
    t.json "detected_dates"
    t.json "detected_amounts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachment_id"], name: "index_pdf_analysis_results_on_attachment_id"
    t.index ["card_type"], name: "index_pdf_analysis_results_on_card_type"
    t.index ["expense_sheet_id"], name: "index_pdf_analysis_results_on_expense_sheet_id"
  end

  create_table "recurring_reservation_rules", force: :cascade do |t|
    t.string "frequency"
    t.string "days_of_week"
    t.date "end_date"
    t.integer "max_occurrences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "report_exports", force: :cascade do |t|
    t.integer "report_template_id"
    t.integer "user_id", null: false
    t.string "file_path"
    t.string "status"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "total_records"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "file_size"
    t.text "error_message"
    t.index ["report_template_id"], name: "index_report_exports_on_report_template_id"
    t.index ["user_id"], name: "index_report_exports_on_user_id"
  end

  create_table "report_templates", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.text "filter_config"
    t.text "columns_config"
    t.string "export_format"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_report_templates_on_user_id"
  end

  create_table "request_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "display_order", default: 0
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_request_categories_on_display_order"
    t.index ["is_active"], name: "index_request_categories_on_is_active"
    t.index ["name"], name: "index_request_categories_on_name", unique: true
  end

  create_table "request_form_attachments", force: :cascade do |t|
    t.integer "request_form_id", null: false
    t.string "field_key"
    t.string "file_name"
    t.integer "file_size"
    t.string "content_type"
    t.text "description"
    t.integer "uploaded_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_form_id"], name: "index_request_form_attachments_on_request_form_id"
    t.index ["uploaded_by_id"], name: "index_request_form_attachments_on_uploaded_by_id"
  end

  create_table "request_forms", force: :cascade do |t|
    t.integer "request_template_id", null: false
    t.integer "user_id", null: false
    t.integer "organization_id", null: false
    t.string "request_number"
    t.string "title"
    t.text "form_data"
    t.string "status", default: "draft", null: false
    t.integer "approval_line_id"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.boolean "is_draft", default: false, null: false
    t.text "draft_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "request_category_id", null: false
    t.index ["approval_line_id"], name: "index_request_forms_on_approval_line_id"
    t.index ["is_draft"], name: "index_request_forms_on_is_draft"
    t.index ["organization_id"], name: "index_request_forms_on_organization_id"
    t.index ["request_category_id"], name: "index_request_forms_on_request_category_id"
    t.index ["request_number"], name: "index_request_forms_on_request_number", unique: true
    t.index ["request_template_id"], name: "index_request_forms_on_request_template_id"
    t.index ["status"], name: "index_request_forms_on_status"
    t.index ["submitted_at"], name: "index_request_forms_on_submitted_at"
    t.index ["user_id"], name: "index_request_forms_on_user_id"
  end

  create_table "request_template_approval_rules", force: :cascade do |t|
    t.integer "request_template_id", null: false
    t.integer "approver_group_id", null: false
    t.text "condition"
    t.integer "order"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_group_id"], name: "index_request_template_approval_rules_on_approver_group_id"
    t.index ["request_template_id"], name: "index_request_template_approval_rules_on_request_template_id"
  end

  create_table "request_template_fields", force: :cascade do |t|
    t.integer "request_template_id", null: false
    t.string "field_key", null: false
    t.string "field_label", null: false
    t.string "field_type", null: false
    t.text "field_options"
    t.boolean "is_required", default: false, null: false
    t.text "validation_rules"
    t.string "placeholder"
    t.text "help_text"
    t.integer "display_order", default: 0
    t.string "display_width", default: "full"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_request_template_fields_on_display_order"
    t.index ["request_template_id", "field_key"], name: "idx_template_field_key", unique: true
    t.index ["request_template_id"], name: "index_request_template_fields_on_request_template_id"
  end

  create_table "request_templates", force: :cascade do |t|
    t.integer "request_category_id", null: false
    t.string "name", null: false
    t.string "code", null: false
    t.text "description"
    t.text "instructions"
    t.integer "display_order", default: 0
    t.boolean "is_active", default: true, null: false
    t.boolean "attachment_required", default: false, null: false
    t.boolean "auto_numbering", default: true, null: false
    t.integer "version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "fields"
    t.index ["code"], name: "index_request_templates_on_code", unique: true
    t.index ["display_order"], name: "index_request_templates_on_display_order"
    t.index ["is_active"], name: "index_request_templates_on_is_active"
    t.index ["request_category_id", "name"], name: "index_request_templates_on_request_category_id_and_name", unique: true
    t.index ["request_category_id"], name: "index_request_templates_on_request_category_id"
  end

  create_table "room_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "display_order", default: 0
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_room_categories_on_display_order"
    t.index ["name"], name: "index_room_categories_on_name", unique: true
  end

  create_table "room_reservations", force: :cascade do |t|
    t.integer "room_id", null: false
    t.integer "user_id", null: false
    t.date "reservation_date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.text "purpose", null: false
    t.integer "recurring_reservation_rule_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recurring_reservation_rule_id"], name: "index_room_reservations_on_recurring_reservation_rule_id"
    t.index ["reservation_date"], name: "index_room_reservations_on_reservation_date"
    t.index ["room_id", "reservation_date"], name: "index_room_reservations_on_room_id_and_reservation_date"
    t.index ["room_id"], name: "index_room_reservations_on_room_id"
    t.index ["user_id", "reservation_date"], name: "index_room_reservations_on_user_id_and_reservation_date"
    t.index ["user_id"], name: "index_room_reservations_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.integer "room_category_id"
    t.index ["category"], name: "index_rooms_on_category"
    t.index ["name"], name: "index_rooms_on_name", unique: true
    t.index ["room_category_id"], name: "index_rooms_on_room_category_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "transaction_matches", force: :cascade do |t|
    t.integer "pdf_analysis_result_id", null: false
    t.integer "expense_item_id", null: false
    t.json "transaction_data"
    t.integer "confidence"
    t.string "match_type"
    t.boolean "is_confirmed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_item_id"], name: "index_transaction_matches_on_expense_item_id"
    t.index ["is_confirmed"], name: "index_transaction_matches_on_is_confirmed"
    t.index ["match_type"], name: "index_transaction_matches_on_match_type"
    t.index ["pdf_analysis_result_id", "expense_item_id"], name: "index_transaction_matches_on_pdf_and_expense_item"
    t.index ["pdf_analysis_result_id"], name: "index_transaction_matches_on_pdf_analysis_result_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.string "employee_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "organization_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employee_id"], name: "index_users_on_employee_id", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "approval_histories", "approval_requests"
  add_foreign_key "approval_histories", "users", column: "approver_id"
  add_foreign_key "approval_line_steps", "approval_lines"
  add_foreign_key "approval_line_steps", "users", column: "approver_id"
  add_foreign_key "approval_lines", "users"
  add_foreign_key "approval_request_steps", "approval_requests"
  add_foreign_key "approval_request_steps", "users", column: "approver_id"
  add_foreign_key "approval_requests", "expense_items"
  add_foreign_key "approver_group_members", "approver_groups"
  add_foreign_key "approver_group_members", "users"
  add_foreign_key "approver_group_members", "users", column: "added_by_id"
  add_foreign_key "approver_groups", "users", column: "created_by_id"
  add_foreign_key "attachment_analysis_rules", "attachment_requirements"
  add_foreign_key "attachment_validation_rules", "attachment_requirements"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "cost_centers", "organizations"
  add_foreign_key "cost_centers", "users", column: "manager_id"
  add_foreign_key "expense_attachments", "expense_items"
  add_foreign_key "expense_closing_statuses", "organizations"
  add_foreign_key "expense_closing_statuses", "users"
  add_foreign_key "expense_closing_statuses", "users", column: "closed_by_id"
  add_foreign_key "expense_code_approval_rules", "approver_groups"
  add_foreign_key "expense_code_approval_rules", "expense_codes"
  add_foreign_key "expense_codes", "expense_codes", column: "parent_code_id"
  add_foreign_key "expense_codes", "organizations"
  add_foreign_key "expense_items", "approval_lines"
  add_foreign_key "expense_items", "cost_centers"
  add_foreign_key "expense_items", "expense_codes"
  add_foreign_key "expense_items", "expense_sheets"
  add_foreign_key "expense_sheet_approval_rules", "approver_groups"
  add_foreign_key "expense_sheet_approval_rules", "approver_groups", column: "submitter_group_id"
  add_foreign_key "expense_sheet_approval_rules", "organizations"
  add_foreign_key "expense_sheet_attachments", "attachment_requirements"
  add_foreign_key "expense_sheet_attachments", "expense_sheets"
  add_foreign_key "expense_sheets", "approval_lines"
  add_foreign_key "expense_sheets", "cost_centers"
  add_foreign_key "expense_sheets", "organizations"
  add_foreign_key "expense_sheets", "users"
  add_foreign_key "expense_sheets", "users", column: "approved_by_id"
  add_foreign_key "expense_validation_histories", "expense_sheets"
  add_foreign_key "expense_validation_histories", "users", column: "validated_by_id"
  add_foreign_key "organizations", "organizations", column: "parent_id"
  add_foreign_key "organizations", "users", column: "manager_id"
  add_foreign_key "pdf_analysis_results", "expense_sheets"
  add_foreign_key "report_exports", "report_templates"
  add_foreign_key "report_exports", "users"
  add_foreign_key "report_templates", "users"
  add_foreign_key "request_form_attachments", "request_forms"
  add_foreign_key "request_form_attachments", "users", column: "uploaded_by_id"
  add_foreign_key "request_forms", "approval_lines"
  add_foreign_key "request_forms", "organizations"
  add_foreign_key "request_forms", "request_categories"
  add_foreign_key "request_forms", "request_templates"
  add_foreign_key "request_forms", "users"
  add_foreign_key "request_template_approval_rules", "approver_groups"
  add_foreign_key "request_template_approval_rules", "request_templates"
  add_foreign_key "request_template_fields", "request_templates"
  add_foreign_key "request_templates", "request_categories"
  add_foreign_key "room_reservations", "recurring_reservation_rules"
  add_foreign_key "room_reservations", "rooms"
  add_foreign_key "room_reservations", "users"
  add_foreign_key "rooms", "room_categories"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "transaction_matches", "expense_items"
  add_foreign_key "transaction_matches", "pdf_analysis_results"
  add_foreign_key "users", "organizations"
end
