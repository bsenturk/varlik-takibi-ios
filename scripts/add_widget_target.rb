#!/usr/bin/env ruby
# encoding: UTF-8
#
# MyGoldsWidget (WidgetKit extension) target'ını projeye ekler.
#
# - Target'ı oluşturur, kaynakları bağlar, Info.plist + entitlements ayarlar
# - MyGoldsWidget/Shared/ altındaki dosyaları HER İKİ target'a da ekler
# - .appex'i uygulamaya gömer (Embed Foundation Extensions) ve bağımlılık kurar
#
# Idempotent: target zaten varsa yalnızca eksik dosyaları tamamlar.
#
# Kullanım: ruby scripts/add_widget_target.rb

require "xcodeproj"

PROJECT_PATH = File.expand_path(File.join(__dir__, "..", "MyGolds.xcodeproj"))
ROOT         = File.dirname(PROJECT_PATH)
WIDGET_DIR   = "MyGoldsWidget"
WIDGET_NAME  = "MyGoldsWidget"
APP_NAME     = "MyGolds"
BUNDLE_ID    = "com.xptapps.assetbook.widget"
TEAM         = "ADPP457ME6"
APP_GROUP    = "group.com.xptapps.assetbook"

project = Xcodeproj::Project.open(PROJECT_PATH)
app     = project.targets.find { |t| t.name == APP_NAME }
raise "Target #{APP_NAME} bulunamadı" unless app

widget = project.targets.find { |t| t.name == WIDGET_NAME }
if widget.nil?
  widget = project.new_target(:app_extension, WIDGET_NAME, :ios, "17.0")
  puts "＋ target oluşturuldu: #{WIDGET_NAME}"
else
  puts "= target zaten var: #{WIDGET_NAME}"
end

# --- Gruplar -----------------------------------------------------------------

group = project.main_group[WIDGET_DIR] || project.main_group.new_group(WIDGET_DIR, WIDGET_DIR)
shared_group = group["Shared"] || group.new_group("Shared", "Shared")

def reference(group, name)
  group.files.find { |f| f.display_name == name } || group.new_reference(name)
end

# --- Kaynaklar ---------------------------------------------------------------

widget_only = %w[PortfolioWidget.swift PortfolioWidgetView.swift WidgetPriceFetcher.swift]
shared      = %w[WidgetSharedStore.swift]

added = []

widget_only.each do |name|
  ref = reference(group, name)
  unless widget.source_build_phase.files_references.include?(ref)
    widget.add_file_references([ref])
    added << "#{WIDGET_DIR}/#{name} → #{WIDGET_NAME}"
  end
end

# Paylaşımlı dosyalar iki target'ta da derlenir — tek tanım, kopya yok.
shared.each do |name|
  ref = reference(shared_group, name)
  [widget, app].each do |target|
    next if target.source_build_phase.files_references.include?(ref)
    target.add_file_references([ref])
    added << "#{WIDGET_DIR}/Shared/#{name} → #{target.name}"
  end
end

# Info.plist / entitlements: derlenmez, yalnızca projede görünür.
%w[Info.plist MyGoldsWidget.entitlements].each { |name| reference(group, name) }

# --- Build ayarları ----------------------------------------------------------

settings = {
  "CODE_SIGN_ENTITLEMENTS"        => "#{WIDGET_DIR}/MyGoldsWidget.entitlements",
  "CODE_SIGN_STYLE"               => "Automatic",
  "CURRENT_PROJECT_VERSION"       => "1",
  "DEVELOPMENT_TEAM"              => TEAM,
  "ENABLE_PREVIEWS"               => "YES",
  "GENERATE_INFOPLIST_FILE"       => "YES",
  "INFOPLIST_FILE"                => "#{WIDGET_DIR}/Info.plist",
  "INFOPLIST_KEY_CFBundleDisplayName" => "Varlık Takibi",
  "INFOPLIST_KEY_NSHumanReadableCopyright" => "",
  "IPHONEOS_DEPLOYMENT_TARGET"    => "17.0",
  "LD_RUNPATH_SEARCH_PATHS"       => ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
  "MARKETING_VERSION"             => "3.0.6",
  "PRODUCT_BUNDLE_IDENTIFIER"     => BUNDLE_ID,
  "PRODUCT_NAME"                  => "$(TARGET_NAME)",
  "SKIP_INSTALL"                  => "YES",
  "SUPPORTED_PLATFORMS"           => "iphoneos iphonesimulator",
  "SUPPORTS_MACCATALYST"          => "NO",
  "SWIFT_EMIT_LOC_STRINGS"        => "YES",
  "SWIFT_VERSION"                 => "5.0",
  "TARGETED_DEVICE_FAMILY"        => "1,2"
}

widget.build_configurations.each do |config|
  settings.each { |k, v| config.build_settings[k] = v }
  config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] =
    config.name == "Debug" ? "DEBUG $(inherited)" : "$(inherited)"
end

# Uygulamanın MARKETING_VERSION'ı ile hizala (sürüm uyuşmazlığı App Store
# yüklemesinde reddedilir).
app_version = app.build_configurations.first.build_settings["MARKETING_VERSION"]
widget.build_configurations.each { |c| c.build_settings["MARKETING_VERSION"] = app_version } if app_version

# --- Gömme + bağımlılık ------------------------------------------------------

embed = app.build_phases.find do |phase|
  phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    phase.symbol_dst_subfolder_spec == :plug_ins
end

if embed.nil?
  embed = app.new_copy_files_build_phase("Embed Foundation Extensions")
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.dst_path = ""
  puts "＋ 'Embed Foundation Extensions' fazı eklendi"
end

unless embed.files_references.include?(widget.product_reference)
  build_file = embed.add_file_reference(widget.product_reference)
  build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
  puts "＋ #{WIDGET_NAME}.appex uygulamaya gömüldü"
end

unless app.dependencies.any? { |d| d.target == widget }
  app.add_dependency(widget)
  puts "＋ bağımlılık: #{APP_NAME} → #{WIDGET_NAME}"
end

# Gömme fazı, kaynak/kabuk script fazlarının SONUNDA kalırsa build cycle'a yol
# açıyor (Crashlytics dSYM'i .app'in tamamına bakıyor, .appex ise henüz
# kopyalanmamış oluyor). Xcode'un kendi şablonundaki yere alıyoruz: Resources'ın
# hemen ardı, kabuk scriptlerinden önce.
resources_index = app.build_phases.index { |ph| ph.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
if resources_index
  current = app.build_phases.index(embed)
  target_index = resources_index + 1
  if current && current != target_index
    app.build_phases.delete_at(current)
    app.build_phases.insert(target_index, embed)
    puts "↻ 'Embed Foundation Extensions' fazı Resources'ın ardına taşındı"
  end
end

# --- App Group entitlement'ı uygulamada da açık olmalı ------------------------

app.build_configurations.each do |config|
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] ||= "MyGolds/MyGolds.entitlements"
end

project.save

if added.empty?
  puts "= eklenecek yeni dosya yok"
else
  added.each { |line| puts "＋ #{line}" }
end
puts "\n✅ Kaydedildi: #{PROJECT_PATH}"
puts "   App Group: #{APP_GROUP} — Xcode'da her iki target için Signing & Capabilities'te doğrula."
