# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/helpers", under: "helpers"

# Rails ActionCable
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"

# Chart.js - vendor 파일 사용
pin "chart.js", to: "chart.js.js", preload: true

# UI Libraries
pin "choices.js", to: "choices.js.js" # @11.1.0
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.6/modular/sortable.esm.js"
