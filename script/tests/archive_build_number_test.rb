require 'minitest/autorun'
require 'tmpdir'
require 'open3'

class ArchiveBuildNumberTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  SCRIPT = File.join(ROOT, 'script/increment_archive_build.rb')

  def with_counter(source = "CURRENT_PROJECT_VERSION = 1\n")
    Dir.mktmpdir('archive-number-test') do |directory|
      config = File.join(directory, 'BuildNumber.xcconfig')
      header = File.join(directory, 'KlapokBuildNumber.h')
      File.write(config, source)
      yield config, header
    end
  end

  def run_counter(action, config, header)
    Open3.capture2e({ 'ACTION' => action }, '/usr/bin/ruby', SCRIPT, config, header).last
  end

  def test_build_does_not_increment
    with_counter do |config, header|
      2.times { assert run_counter('build', config, header).success? }
      assert_equal "CURRENT_PROJECT_VERSION = 1\n", File.read(config)
      assert_includes File.read(header), 'KLAPOK_BUILD_NUMBER 1'
    end
  end

  def test_archives_advance_but_marketing_version_is_not_modified
    with_counter do |config, header|
      assert run_counter('install', config, header).success?
      assert_equal "CURRENT_PROJECT_VERSION = 2\n", File.read(config)
      assert_includes File.read(header), 'KLAPOK_BUILD_NUMBER 2'
      assert run_counter('install', config, header).success?
      assert_equal "CURRENT_PROJECT_VERSION = 3\n", File.read(config)
      assert_includes File.read(header), 'KLAPOK_BUILD_NUMBER 3'
      assert run_counter('build', config, header).success?
      assert_equal "CURRENT_PROJECT_VERSION = 3\n", File.read(config)
    end
  end

  def test_invalid_counter_is_preserved
    with_counter('invalid') do |config, header|
      refute run_counter('install', config, header).success?
      assert_equal 'invalid', File.read(config)
      refute File.exist?(header)
    end
  end

  def test_script_sandbox_remains_enabled
    project = File.read(File.join(ROOT, 'Klapok.xcodeproj/project.pbxproj'))
    refute_includes project, 'ENABLE_USER_SCRIPT_SANDBOXING = NO'
    assert_includes project, 'ENABLE_USER_SCRIPT_SANDBOXING = YES'
    assert_includes project, '$(DERIVED_FILE_DIR)/KlapokBuildNumber.h'
  end
end
