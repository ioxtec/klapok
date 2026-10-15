#!/usr/bin/env ruby
require 'json'
require 'open3'

ROOT = File.expand_path('..', __dir__)
def command(*args, input: nil)
  out, err, status = Open3.capture3(*args, stdin_data: input.to_s)
  abort "#{args.first} failed: #{err}" unless status.success?
  out
end
def plist(path)
  JSON.parse(command('/usr/bin/plutil', '-convert', 'json', '-o', '-', path))
end
def require_check(condition, message)
  abort "FAIL: #{message}" unless condition
end

project = File.read(File.join(ROOT, 'Klapok.xcodeproj/project.pbxproj'))
require_check(!project.include?('com.hoxim.klapok'), 'Legacy bundle identifier remains')
require_check(project.scan(/SUPPORTED_PLATFORMS = macosx;/).length == 6, 'All app/test configurations must be macOS-only')
require_check(!project.match?(/RUNTIME_EXCEPTION_.*= YES|ENABLE_RESOURCE_ACCESS_(CAMERA|AUDIO_INPUT) = YES|ENABLE_INCOMING_NETWORK_CONNECTIONS = YES/), 'Unnecessary permissions or runtime exceptions enabled')
catalog = JSON.parse(File.read(File.join(ROOT, 'Klapok/Localizable.xcstrings')))
catalog.fetch('strings').each do |key, entry|
  next if key.empty? || entry['shouldTranslate'] == false
  require_check((entry['localizations'] || {}).keys.all? { |lang| ['en', 'pl'].include?(lang) }, "Unsupported language: #{key}")
  unit = entry.dig('localizations', 'pl', 'stringUnit')
  require_check(unit && unit['state'] == 'translated' && !unit['value'].to_s.empty?, "Missing Polish translation: #{key}")
end

app = ARGV.find { |arg| !arg.start_with?('--') }
abort 'Usage: ruby script/release_preflight.rb /path/Klapok.app [--distribution]' unless app
app = File.expand_path(app)
info = plist(File.join(app, 'Contents/Info.plist'))
require_check(info['CFBundleIdentifier'] == 'com.ioxtec.klapok', 'Wrong app bundle identifier')
require_check(info['CFBundleSupportedPlatforms'] == ['MacOSX'], 'App is not macOS-only')
require_check(info['CFBundleIconFile'] == 'KlapokPaper' &&
              File.file?(File.join(app, 'Contents/Resources/KlapokPaper.icns')),
              'Compiled system-masked paper icon missing')
require_check(!info['NSScreenCaptureDescription'].to_s.empty?, 'Missing screen capture description')
manifest = plist(File.join(app, 'Contents/Resources/PrivacyInfo.xcprivacy'))
require_check(manifest['NSPrivacyTracking'] == false, 'Unexpected tracking declaration')
reasons = manifest.fetch('NSPrivacyAccessedAPITypes').to_h { |item| [item.fetch('NSPrivacyAccessedAPIType'), item.fetch('NSPrivacyAccessedAPITypeReasons')] }
require_check(reasons.fetch('NSPrivacyAccessedAPICategoryUserDefaults', []).include?('CA92.1'), 'Missing UserDefaults reason')
require_check(reasons.fetch('NSPrivacyAccessedAPICategoryFileTimestamp', []).include?('C617.1'), 'Missing file metadata reason')
languages = Dir.glob(File.join(app, 'Contents/Resources/*.lproj')).map { |path| File.basename(path, '.lproj') }
require_check(['en', 'pl'].all? { |lang| languages.include?(lang) }, 'Missing EN/PL resources')
require_check((languages - ['en', 'pl', 'Base']).empty?, 'Unexpected language in bundle')

command('/usr/bin/codesign', '--verify', '--deep', '--strict', app)
signature, details, status = Open3.capture3('/usr/bin/codesign', '-dvv', '--entitlements', ':-', app)
require_check(status.success?, 'Cannot read signature')
require_check(details.include?('runtime'), 'Hardened runtime missing')
require_check(details.match?(/TeamIdentifier=[A-Z0-9]+/), 'Missing signing team')
entitlements = JSON.parse(command('/usr/bin/plutil', '-convert', 'json', '-o', '-', '-', input: signature))
allowed = ['com.apple.security.app-sandbox', 'com.apple.security.files.user-selected.read-write',
           'com.apple.security.get-task-allow', 'com.apple.application-identifier', 'com.apple.developer.team-identifier']
require_check(entitlements['com.apple.security.app-sandbox'] == true, 'App Sandbox missing')
require_check((entitlements.keys - allowed).empty?, "Unexpected entitlements: #{(entitlements.keys - allowed).join(', ')}")
if ARGV.include?('--distribution')
  require_check(entitlements['com.apple.security.get-task-allow'] != true, 'Distribution app permits debugger access')
  require_check(details.match?(/Authority=(Apple Distribution|3rd Party Mac Developer Application):/), 'App Store distribution signature required')
end

executables = Dir.glob(File.join(app, 'Contents/MacOS/*')) + Dir.glob(File.join(app, '**/*.{dylib,framework}'))
executables.each do |binary|
  next unless File.file?(binary)
  dependencies = command('/usr/bin/otool', '-L', binary)
  imports = command('/usr/bin/nm', '-u', binary)
  require_check(!dependencies.include?('/usr/lib/liblzma'), 'System liblzma dependency present')
  require_check(!imports.match?(/\b_lzma_\w+/), 'Rejected LZMA symbol present')
end
puts "PASS: #{info['CFBundleIdentifier']} #{info['CFBundleShortVersionString']} (#{info['CFBundleVersion']}), macOS #{info['LSMinimumSystemVersion']}+"
puts 'PASS: signature, sandbox, runtime, privacy declarations, EN/PL resources and known rejected symbols'
puts 'Manual gates remain: real capture/audio/cursor, oldest supported macOS, final App Store export and store metadata.'
