require "yaml"
require "roda/opal_assets/version"
require "roda"
require "sprockets"
require "opal"
require "opal/sprockets"

class Roda
  class OpalAssets
    def initialize options={}
      @env = options.fetch(:env) { ENV.fetch('RACK_ENV') { 'development' } }.to_sym
      @minify = options.fetch(:minify) { production? }
      @assets = []
      @file_cache = {}

      sprockets
      source_maps

      if @minify
        require "closure-compiler"
      end

      @special_mappings = []
    end

    def route r
      unless production?
        r.on source_map_prefix[1..-1] do
          r.run source_maps
        end
        r.on 'assets/js' do
          r.run sprockets
        end
        r.on 'assets/css' do
          r.run sprockets
        end
        r.on 'assets/images' do
          r.run sprockets
        end
        r.on 'assets' do
          r.run sprockets
        end
      end

      @special_mappings.each do |mapping|
        r.on mapping.path do
          r.run mapping
        end
      end
    end

    def serve(asset_name, as:)
      @special_mappings << Mapping.new(
        path: as.sub(/\/+/, ''),
        asset: asset_name,
        compiler: self,
      )
    end

    def script file
      file << '.js' unless file.end_with? '.js'
      scripts = ''

      if production?
        path = if @special_mappings.any? { |m| m.asset == file }
                 '' # No path prefix for special mappings
               else
                 '/assets/'
               end
        path << manifest[file]
        scripts << %{<script src="#{path}"></script>\n}
      else
        asset = sprockets[file]

        asset.to_a.each { |dependency|
          scripts << %{<script src="/assets/#{dependency.digest_path}?body=1"></script>\n}
        }

        scripts << %{<script>#{opal_boot_code file}</script>}
      end

      scripts
    end
    alias js script

    def stylesheet file, media: :all
      file << '.css' unless file.end_with? '.css'

      %{<link href="#{asset_path(file)}" media="#{media}" rel="stylesheet" />}
    end
    alias css stylesheet

    def image file, options={}
      options = options.merge(src: asset_path(file))

      %{<img#{options.reduce('') { |string, (key, value)| string << " #{key}=#{value.inspect}" }} />}
    end

    def asset_path file
      if production?
        "/assets/#{manifest[file]}"
      else
        asset = sprockets[file]
        raise ArgumentError, "Asset not found: #{file}" if asset.nil?

        asset.filename.to_s.sub(Dir.pwd, '')
      end
    end

    def << asset
      if asset.is_a? Dir
        asset.each do |filename|
          self << File.basename(filename) unless filename.start_with? '.'
        end
      else
        @assets << asset
      end
    end

    def build
      FileUtils.mkdir_p 'public/assets'

      @manifest = @assets.each_with_object({}) do |file, hash|
        print "Compiling #{file}..."
        asset = sprockets[file]
        hash[file] = @special_mappings.find(proc { asset.digest_path }) { |mapping|
          break mapping.path if mapping.asset == file
        }
        compile_file file, "public/assets/#{hash[file]}"
        puts ' done'
      end

      File.write 'assets.yml', YAML.dump(manifest)
    end

    def compile_file file, output_filename
      compiled = compile(file) + opal_boot_code(file)

      File.write output_filename, compiled
      nil
    end

    def compile file
      sprockets[file].to_s
    end

    def sprockets
      return @sprockets if defined? @sprockets

      sprockets = Sprockets::Environment.new
      Opal.paths.each do |path|
        sprockets.append_path path
      end
      sprockets.append_path 'assets/js'
      sprockets.append_path 'assets/css'
      sprockets.append_path 'assets/images'
      sprockets.append_path 'assets/service_workers'

      sprockets.js_compressor = :closure if @minify

      @sprockets = sprockets
    end

    def source_map_prefix
      '/__OPAL_SOURCE_MAPS__' 
    end

    def source_maps
      return @source_maps if defined? @source_maps

      source_map_handler = if supports_opal_config?
                             Opal::Config
                           else
                             Opal::Processor
                           end

      source_map_handler.source_map_enabled = !production? && min_opal_version?('0.8.0')

      if defined? Opal::SourceMapServer
        source_maps = Opal::SourceMapServer.new(sprockets, source_map_prefix)
      end

      if !production? && min_opal_version?('0.8.0')
        ::Opal::Sprockets::SourceMapHeaderPatch.inject!(source_map_prefix)
      end

      @source_maps = Rack::Builder.new do
        use Rack::ConditionalGet
        use Rack::ETag

        run source_maps
      end
    end

    def manifest
      return @manifest if defined? @manifest

      @manifest = YAML.load_file 'assets.yml'
      unless @manifest
        warn 'Assets manifest is broken'
      end

      @manifest
    end

    def production?
      @env == :production
    end

    def opal_boot_code file
      if min_opal_version? '0.9.0'
        Opal::Sprockets.load_asset(file, sprockets)
      elsif min_opal_version? '0.8.0'
        Opal::Processor.load_asset_code(sprockets, file)
      else
        ''
      end
    end

    def supports_opal_config?
      min_opal_version? '0.8.0'
    end

    # Check for minimum Opal version, but do it in a weird way because Array
    # implements <=> but doesn't include Comparable
    def min_opal_version? version
      (Opal::VERSION.split('.').map(&:to_i) <=> version.split('.').map(&:to_i)) >= 0
    end

    class Mapping
      attr_reader :asset, :path, :compiler

      def initialize(asset:, path:, compiler:)
        @asset = asset
        @path = path
        @compiler = compiler
      end

      def call(env)
        body = compiler.compile(asset) + compiler.opal_boot_code(asset)

        [200, { 'Content-Type' => 'text/javascript' }, [body]]
      end
    end
  end
end
