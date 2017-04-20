require 'leveldb'
require 'fluent/plugin/storage'

module Fluent
  module Plugin
    class LevelDBStorage < Storage
      Fluent::Plugin.register_storage('leveldb', self)

      DEFAULT_DIR_MODE = 0755

      config_param :path, :string, default: nil
      config_param :dir_mode, default: DEFAULT_DIR_MODE do |v|
        v.to_i(8)
      end
      config_param :root_key, :string, default: "leveldb"
      # Set persistent true by default
      config_set_default :persistent, true

      attr_reader :store, :leveldb # for test

      def initialize
        super

        @store = {}
      end

      def configure(conf)
        super

        if @path
          if File.exist?(@path) && File.file?(@path)
            raise Fluent::ConfigError, "path for <storage> should be a directory."
          elsif File.exist?(@path) && File.directory?(@path)
            @path = File.join(@path, "worker#{fluentd_worker_id}", "storage.db")
            @multi_workers_available = true
          end
        elsif root_dir = owner.plugin_root_dir
          basename = (conf.arg && !conf.arg.empty?) ? "storage.#{conf.arg}.db" : "storage.db"
          @path = File.join(root_dir, basename)
          @multi_workers_available = true
        else
          raise Fluent::ConfigError, "path for <storage> is required."
        end

        dir = File.dirname(@path)
        FileUtils.mkdir_p(dir, mode: @dir_mode) unless Dir.exist?(dir)
        if File.exist?(@path)
          raise Fluent::ConfigError, "Plugin storage path '#{@path}' is not readable/writable" unless File.readable?(@path) && File.writable?(@path)
        else
          raise Fluent::ConfigError, "Directory is not writable for plugin storage file '#{@path}'" unless File.stat(dir).writable?
        end

        @leveldb = LevelDB::DB.new(@path)
        object = @leveldb.get(@root_key)
        if object
          begin
            data = Yajl::Parser.parse(object)
            raise Fluent::ConfigError, "Invalid contents (not object) in plugin leveldb storage: '#{@path}'" unless data.is_a?(Hash)
          rescue => e
            log.error "failed to read data from plugin redis storage", path: @path, error: e
            raise Fluent::ConfigError, "Unexpected error: failed to read data from plugin leveldb storage: '#{@path}'"
          end
        end
      end

      def multi_workers_ready?
        @multi_workers_available
      end

      def load
        begin
          json_string = @leveldb.get(@root_key)
          json = Yajl::Parser.parse(json_string)
          unless json.is_a?(Hash)
            log.error "broken content for plugin storage (Hash required: ignored)", type: json.class
            log.debug "broken content", content: json_string
            return
          end
          @store = json
        rescue => e
          log.error "failed to load data for plugin storage from leveldb", path: @path, error: e
        end
      end

      def save
        begin
          json_string = Yajl::Encoder.encode(@store)
          @leveldb.batch do
            @leveldb.put(@root_key, json_string)
          end
        rescue => e
          log.error "failed to save data for plugin storage to leveldb", path: @path, error: e
        end
      end

      def get(key)
        @store[key.to_s]
      end

      def fetch(key, defval)
        @store.fetch(key.to_s, defval)
      end

      def put(key, value)
        @store[key.to_s] = value
      end

      def delete(key)
        @store.delete(key.to_s)
      end

      def update(key, &block)
        @store[key.to_s] = block.call(@store[key.to_s])
      end
    end
  end
end
