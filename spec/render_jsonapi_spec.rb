require 'rails_helper'

describe ActionController::Base, '#render', type: :controller do
  context 'when calling render jsonapi:' do
    controller do
      def index
        render jsonapi: nil
      end
    end

    subject { JSON.parse(response.body) }

    it 'renders a JSON API success document' do
      get :index

      expect(response.content_type).to eq('application/vnd.api+json')
      expect(subject.key?('data')).to be true
    end
  end

  context 'with extensions' do
    let(:supported_extensions) { ['bulk'] }

    before(:each) do
      JSONAPI::Rails.configure do |config|
        config.jsonapi_extensions = supported_extensions
      end
    end

    after(:each) do
      JSONAPI::Rails.configure do |config|
        config.clear
      end
    end

    controller do
      def create
        render jsonapi: nil, extensions: []
      end

      def create_with_extensions
        render jsonapi: nil, extensions: ['bulk', 'jsonpatch']
      end
    end

    it 'content_type includes supported extension, ignores empty extensions' do
      post :create

      expect(response.content_type).to eq('application/vnd.api+json; supported-ext="bulk"')
    end

    it 'content_type includes supported extensions, and delivered extensions even if not supported' do
      routes.draw { get "create_with_extensions" => "anonymous#create_with_extensions" }
      post :create_with_extensions

      # if the parent application wants to render a response using an extension that is unsupported, let them
      expect(response.content_type).to eq('application/vnd.api+json; supported-ext="bulk"; ext="bulk,jsonpatch"')
    end
  end

  context 'when using a cache' do
    controller do
      def serializer
        Class.new(JSONAPI::Serializable::Resource) do
          type 'users'
          attribute :name

          def jsonapi_cache_key(*)
            'foo'
          end
        end
      end

      def index
        user = OpenStruct.new(id: 1, name: 'Lucas')

        render jsonapi: user,
               class: { OpenStruct: serializer },
               cache: Rails.cache
      end
    end

    subject { JSON.parse(response.body) }

    it 'renders a JSON API success document' do
      get :index
      expect(Rails.cache.exist?('foo')).to be true
      get :index

      expect(response.content_type).to eq('application/vnd.api+json')
      expect(subject.key?('data')).to be true
    end
  end
end
