require_relative '../helper'
require 'fluent/test/helpers'
require 'fluent/plugin/storage_leveldb'
require 'fluent/plugin/input'
require 'fileutils'

class RedisStorageTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  TMP_DIR = File.expand_path(File.dirname(__FILE__) + "/tmp/storage_leveldb")

  class MyInput < Fluent::Plugin::Input
    helpers :storage
    config_section :storage do
      config_set_default :@type, 'leveldb'
    end
  end

  def setup_leveldb
    @store = {}
  end

  def teardown_leveldb
    FileUtils.rm_rf(TMP_DIR)
  end

  setup do
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
    Fluent::Test.setup
    @d = MyInput.new
    setup_leveldb
  end

  teardown do
    @d.stop unless @d.stopped?
    @d.before_shutdown unless @d.before_shutdown?
    @d.shutdown unless @d.shutdown?
    @d.after_shutdown unless @d.after_shutdown?
    @d.close unless @d.closed?
    @d.terminate unless @d.terminated?
    teardown_leveldb
  end

  sub_test_case 'without any configuration' do
    test 'raise Fluent::ConfigError' do
      conf = config_element()

      assert_raise(Fluent::ConfigError) do
        @d.configure(conf)
      end
    end
  end

  sub_test_case 'configured with path key' do
    test 'works as storage which stores data into redis' do
      storage_path = TMP_DIR
      expected_storage_path = File.join(TMP_DIR, 'worker0', 'storage.db')
      conf = config_element('ROOT', '', {}, [config_element('storage', '', {'path' => storage_path})])
      @d.configure(conf)
      @d.start
      @p = @d.storage_create()
      assert_true(@p.persistent)

      assert_equal expected_storage_path, @p.path
      assert @p.store.empty?

      assert_nil @p.get('key1')
      assert_equal 'EMPTY', @p.fetch('key1', 'EMPTY')

      @p.put('key1', '1')
      assert_equal '1', @p.get('key1')

      @p.update('key1') do |v|
        (v.to_i * 2).to_s
      end
      assert_equal '2', @p.get('key1')

      @p.save # stores all data into redis

      assert @p.load

      @p.put('key2', 4)

      @d.stop; @d.before_shutdown; @d.shutdown; @d.after_shutdown; @d.close; @d.terminate

      assert_equal({'key1' => '2', 'key2' => 4}, @p.load)
      @p.leveldb.close # Remove DB ownership

      # re-create to reload storage contents
      @d = MyInput.new
      @d.configure(conf)
      @d.start
      @p = @d.storage_create()

      assert_false @p.store.empty?

      assert_equal '2', @p.get('key1')
      assert_equal 4, @p.get('key2')
    end
  end

  sub_test_case 'configured with root-dir and plugin id' do
    test 'works as storage which stores data under root dir' do
      root_dir = File.join(TMP_DIR, 'root')
      expected_storage_path = File.join(root_dir, 'worker0', 'local_storage_test', 'storage.db')
      conf = config_element('ROOT', '', {'@id' => 'local_storage_test'})
      Fluent::SystemConfig.overwrite_system_config('root_dir' => root_dir) do
        @d.configure(conf)
      end
      @d.start
      @p = @d.storage_create()

      assert_equal expected_storage_path, @p.path
      assert @p.store.empty?

      assert_nil @p.get('key1')
      assert_equal 'EMPTY', @p.fetch('key1', 'EMPTY')

      @p.put('key1', '1')
      assert_equal '1', @p.get('key1')

      @p.update('key1') do |v|
        (v.to_i * 2).to_s
      end
      assert_equal '2', @p.get('key1')

      @p.save # stores all data into file

      assert File.exist?(expected_storage_path)
      assert File.directory?(expected_storage_path)

      @p.put('key2', 4)

      @d.stop; @d.before_shutdown; @d.shutdown; @d.after_shutdown; @d.close; @d.terminate

      assert_equal({'key1' => '2', 'key2' => 4}, @p.load)
      @p.leveldb.close # Remove DB ownership

      # re-create to reload storage contents
      @d = MyInput.new
      Fluent::SystemConfig.overwrite_system_config('root_dir' => root_dir) do
        @d.configure(conf)
      end
      @d.start
      @p = @d.storage_create()

      assert_false @p.store.empty?

      assert_equal '2', @p.get('key1')
      assert_equal 4, @p.get('key2')
    end
  end
end
