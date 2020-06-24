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
        pointers = [controller.jsonapi_pointers].flatten

        # If the errors are ActiveModel::Error objects, we expect errors and pointers
        # to have the same length because each user has one Error object. However, if
        # the errors are hashes, each individual error for each user has a hash
        # and the length may be different.
        if (errors.length != pointers.length) && pointers[0].class != Hash
          raise 'Invariant violation: errors and pointers must have the same length'
        end

        errors = errors.zip(pointers).map do |e, reverse_mapping|
          e.is_a?(::ActiveModel::Errors) ?
            JSONAPI::Rails::ActiveModel::Errors.new(e, reverse_mapping) :
            e
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
                      .merge!(_jsonapi_pointers: controller.jsonapi_pointers)
          opts[:jsonapi] = opts.delete(:jsonapi_object) ||
                           controller.jsonapi_object
        end
      end
    end
  end
end
