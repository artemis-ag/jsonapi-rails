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
        errors = format_errors(errors, options, controller)

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
          opts[:extensions] = opts[:extensions] || []
        end
      end

      # when rendering bulk errors, each item in the errors argument represents
      # errors for the corresponding resource in the payload.
      #
      # if the payload looks like
      #   {
      #     data: [
      #       {
      #         id: 1,
      #         attributes: { ... }
      #       },
      #       {
      #         id: 2,
      #         attributes: { ... }
      #       },
      #       {
      #         id: 3,
      #         attributes: { ... }
      #       }
      #     ]
      #   }
      #
      # then the ErrorsRenderer must be invoked with 3 errors objects
      #
      #   render :jsonapi_errors [errors_for_1, errors_for_2, errors_for_3],
      #          extensions: ['bulk']
      #
      # Errors can be any class that is registered in the jsonapi_errors_class
      # configuration, or an array of any such classes. However, there *must*
      # be an object to represent errors for each resource from the request.
      #
      # If there are no errors for a given object, an empty array will serve
      # fine to indicate so. Note that an instance of ActiveModel::Errors will
      # still exist even if there are no current errors for a given model in rails.
      def format_errors(errors, options, controller)
        errors = [errors] unless errors.is_a?(Array)

        if options[:extensions].include? 'bulk'
          pointers = [controller.jsonapi_pointers].flatten

          if (errors.length != pointers.length)
            raise ArgumentError, 'Mismatch between number of resources submitted and errors reported. If there are no errors for a given record please provide an empty array.'
          end

          errors.zip(pointers).map do |e, reverse_mapping|
            wrap_errors(e, reverse_mapping)
          end
        else
          errors.map do |e|
            wrap_errors(e, controller.jsonapi_pointers)
          end
        end.flatten.compact
      end

      def wrap_errors(errors, reverse_mapping)
        errors.is_a?(::ActiveModel::Errors) ?
          JSONAPI::Rails::ActiveModel::Errors.new(errors, reverse_mapping) :
          errors
      end
    end
  end
end
