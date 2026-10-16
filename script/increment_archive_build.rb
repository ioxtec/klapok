#!/usr/bin/env ruby
# Generates the Info.plist prefix header; only Archive/install advances the counter.
config, header = ARGV.map { |path| File.expand_path(path) }
abort 'Expected build-number configuration and generated header paths.' unless config && header

File.open(config, File::RDWR) do |file|
  file.flock(File::LOCK_EX)
  source = file.read
  match = source.match(/\ACURRENT_PROJECT_VERSION = ([1-9]\d*)\s*\z/)
  abort 'Build number must be a positive integer.' unless match
  number = match[1].to_i
  if ENV['ACTION'] == 'install'
    number += 1
    file.rewind
    file.write("CURRENT_PROJECT_VERSION = #{number}\n")
    file.truncate(file.pos)
    file.flush
    file.fsync
  end
  definition = "#define KLAPOK_BUILD_NUMBER #{number}\n"
  File.write(header, definition) unless File.exist?(header) && File.read(header) == definition
  puts "Build number: #{number} (#{ENV.fetch('ACTION', 'build')})"
end
