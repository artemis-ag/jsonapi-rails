require 'jsonapi/serializable/renderer'
require 'jsonapi/rails/active_model/errors'

module JSONAPI
  module Rails
    # @private
    class SuccessRenderer
      def initialize(renderer = JSONAPI::Serializable::Renderer.new)
        @renderer = renderer

        freeze
      end

      def render(resources, options, controller)
        options = default_options(options, controller, resources)

        @renderer.render(resources, options)
      end

      private

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def default_options(options, controller, resources)
        options.dup.tap do |opts|
          opts[:class] ||= controller.jsonapi_class
          opts[:cache] ||= controller.jsonapi_cache
          opts[:links] =
            controller.jsonapi_links
                      .merge!(controller.jsonapi_pagination(resources))
                      .merge!(opts[:links] || {})
          opts[:expose] = controller.jsonapi_expose.merge!(opts[:expose] || {})
          opts[:extensions] = []
          opts[:fields] ||= controller.jsonapi_fields
          opts[:include] ||= controller.jsonapi_include
          opts[:jsonapi] = opts.delete(:jsonapi_object) ||
                           controller.jsonapi_object
          opts[:meta] ||= controller.jsonapi_meta
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end

    # @private
    class ErrorsRenderer
      def initialize(renderer = JSONAPI::Serializable::Renderer.new)
        @renderer = renderer

        freeze
      end

      def render(errors, options, controller)
        options = default_options(options, controller)

        errors = [errors] unless errors.is_a?(Array)
        errors = errors.map.with_index do |e, index|
          # TODO: only wrap ActiveModel::Errors in JSONAPI::RAILS::ActiveModel::Errors
          # also: how does this effect application configuration?
          JSONAPI::Rails::ActiveModel::Errors.new(e, controller.jsonapi_pointers[index])
        end

        @renderer.render_errors(errors, options)
      end

      private

      def default_options(options, controller)
        options.dup.tap do |opts|
          opts[:class] ||= controller.jsonapi_errors_class
          opts[:links] = controller.jsonapi_links.merge!(opts[:links] || {})
          opts[:expose] =
            controller.jsonapi_expose
                      .merge(opts[:expose] || {})
          opts[:jsonapi] = opts.delete(:jsonapi_object) ||
                           controller.jsonapi_object
        end
      end
    end
  end
end
