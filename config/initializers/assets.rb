# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# vendor/javascript 디렉토리를 assets path에 추가
Rails.application.config.assets.paths << Rails.root.join("vendor", "javascript")
