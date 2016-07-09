require "roda/opal_assets/version"
require "roda"
require "opal"
require "uglifier" if ENV['RACK_ENV'] == 'production'

class Roda
  class OpalAssets
    def initialize env: ENV['RACK_ENV']
      @env = env

      Opal::Config.source_map_enabled = !production?
      sprockets
      source_maps unless production?
    end

    def route r
      r.on source_map_prefix[1..-1] do
        r.run source_maps
      end
      r.on 'assets/js' do
        r.run sprockets
      end
      r.on 'assets/css' do
        r.run sprockets
      end
    end

    def js file
      ::Opal::Sprockets.javascript_include_tag(
        file,
        sprockets: sprockets,
        prefix: '/assets/js',
        debug: !production?,
      )
    end

    def stylesheet file, media: :all
      asset = sprockets["#{file}.css"]
      if asset.nil?
        raise "File not found: #{file}.css"
      end

      path = asset.filename.to_s.sub(Dir.pwd, '')
      %{<link href="#{path}" media="#{media}" rel="stylesheet" />}
    end

    def sprockets
      return @sprockets if defined? @sprockets

      sprockets = Sprockets::Environment.new
      Opal.paths.each do |path|
        sprockets.append_path path
      end
      sprockets.append_path 'assets/js'
      sprockets.append_path 'assets/css'

      sprockets.js_compressor = :uglifier if production?

      @sprockets = sprockets
    end

    def source_map_prefix
      '/__OPAL_SOURCE_MAPS__' 
    end

    def source_maps
      return @source_maps if defined? @source_maps

      source_maps = Opal::SourceMapServer.new(sprockets, source_map_prefix)
      unless production?
        ::Opal::Sprockets::SourceMapHeaderPatch.inject!(source_map_prefix)
      end

      @source_maps = Rack::Builder.new do
        use Rack::ConditionalGet
        use Rack::ETag

        run source_maps
      end
    end

    def production?
      @env == 'production'
    end
  end
end
