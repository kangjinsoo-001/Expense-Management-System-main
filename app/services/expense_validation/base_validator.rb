module ExpenseValidation
  class BaseValidator
    def validate(expense_item)
      raise NotImplementedError, "Subclasses must implement validate method"
    end
  end
end