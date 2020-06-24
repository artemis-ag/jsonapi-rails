require 'jsonapi/parser'
require 'jsonapi/rails/deserializable_resource'
require 'jsonapi/parser/document'

module JSONAPI
  module Rails
    module Controller
      # Controller class and instance methods for deserialization of incoming
      #   JSON API payloads.
      module Deserialization
        extend ActiveSupport::Concern

        JSONAPI_POINTERS_KEY = 'jsonapi-rails.jsonapi_pointers'.freeze

        class_methods do
          # Declare a deserializable resource.
          #
          # @param key [Symbol] The key under which the deserialized hash will be
          #   available within the `params` hash.
          # @param options [Hash]
          # @option class [Class] A custom deserializer class. Optional.
          # @option only List of actions for which deserialization should happen.
          #   Optional.
          # @option except List of actions for which deserialization should not
          #   happen. Optional.
          # @yieldreturn Optional block for in-line definition of custom
          #   deserializers.
          #
          # @example
          #   class ArticlesController < ActionController::Base
          #     deserializable_resource :article, only: [:create, :update]
          #
          #     def create
          #       article = Article.new(params[:article])
          #
          #       if article.save
          #         render jsonapi: article
          #       else
          #         render jsonapi_errors: article.errors
          #       end
          #     end
          #
          #     # ...
          #   end
          #
          # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          def deserializable_resource(key, options = {}, &block)
            options = options.dup
            klass = options.delete(:class) ||
                    Class.new(JSONAPI::Rails::DeserializableResource, &block)

            before_action(options) do |controller|
              hash = controller.params.to_unsafe_hash[:_jsonapi]
              if hash.nil?
                JSONAPI::Rails.logger.warn do
                  "Unable to deserialize #{key} because no JSON API payload was" \
                  " found. (#{controller.controller_name}##{params[:action]})"
                end
                next
              end

              if extension_request?('bulk')
                resource_pointers = []
                resource_params = []

                ActiveSupport::Notifications
                  .instrument('parse.jsonapi-rails',
                              key: key, payload: hash, class: klass) do
                  hash[:data].each_with_index do |resource, index|
                    JSONAPI::Parser::Document.parse_primary_resource!(resource)
                    resource = klass.new(resource, root: "/data/#{index}")
                    resource_pointers.push resource.reverse_mapping
                    resource_params.push resource.to_hash
                  end
                end

                controller.request.env[JSONAPI_POINTERS_KEY] = resource_pointers
                controller.params[key.to_sym] = resource_params
              else
                ActiveSupport::Notifications
                  .instrument('parse.jsonapi-rails',
                              key: key, payload: hash, class: klass) do
                  JSONAPI::Parser::Resource.parse!(hash)
                  resource = klass.new(hash[:data])
                  controller.request.env[JSONAPI_POINTERS_KEY] =
                    resource.reverse_mapping
                  controller.params[key.to_sym] = resource.to_hash
                end
              end
            end
          end
        end

        def extension_request?(extension)
          supported_extensions = JSONAPI::Rails.config[:jsonapi_extensions]
          return false unless supported_extensions.include?(extension)

          requested_extensions = request.headers['Content-Type']
            .match(/;\sext=["']([^=]*)["']/)
            .try(:[], 1)
            .split(',')
          return (requested_extensions & supported_extensions).include?(extension)
        end

        # JSON pointers for deserialized fields.
        # @return [Hash{Symbol=>String}]
        def jsonapi_pointers
          request.env[JSONAPI_POINTERS_KEY] || {}
        end

        def jsonapi_supported_extensions
          extensions = JSONAPI::Rails.config[:jsonapi_extensions]
          return nil unless extensions&.any?

          "supported-ext=\"#{extensions.join(',')}\""
        end

        def jsonapi_response_extensions(extensions = [])
          return nil unless extensions&.any?

          "ext=\"#{extensions.join(',')}\""
        end
      end
    end
  end
end
