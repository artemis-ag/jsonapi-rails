require 'rails_helper'

describe ActionController::Base, '.deserializable_resource',
         type: :controller do
  let(:payload) do
    {
      _jsonapi: {
        'data' => {
          'type' => 'users',
          'attributes' => { 'name' => 'Lucas' }
        }
      }
    }
  end

  let(:array_payload) do
    {
      _jsonapi: {
        'data' => [
          {
            'type' => 'users',
            'attributes' => { 'name' => 'Lucas' }
          },
          {
            'type' => 'users',
            'attributes' => { 'name' => 'Fran' }
          }
        ]
      }
    }
  end

  context 'when using default deserializer' do
    controller do
      deserializable_resource :user

      def create
        render plain: 'ok'
      end
    end

    it 'makes the deserialized resource available in params' do
      post :create, params: payload

      expected = { 'type' => 'users', 'name' => 'Lucas' }
      expect(controller.params[:user]).to eq(expected)
    end

    it 'makes the deserialization mapping available via #jsonapi_pointers' do
      post :create, params: payload

      expected = { name: '/data/attributes/name',
                   type: '/data/type' }
      expect(controller.jsonapi_pointers).to eq(expected)
    end
  end

  context 'when using a customized deserializer' do
    controller do
      deserializable_resource :user do
        attribute(:name) do |val|
          { 'first_name'.to_sym => val }
        end
      end

      def create
        render plain: 'ok'
      end
    end

    it 'makes the deserialized resource available in params' do
      post :create, params: payload

      expected = { 'type' => 'users', 'first_name' => 'Lucas' }
      expect(controller.params[:user]).to eq(expected)
    end

    it 'makes the deserialization mapping available via #jsonapi_pointers' do
      post :create, params: payload

      expected = { first_name: '/data/attributes/name',
                   type: '/data/type' }
      expect(controller.jsonapi_pointers).to eq(expected)
    end
  end

  context 'when using a customized deserializer with key_format' do
    controller do
      deserializable_resource :user do
        key_format(&:capitalize)
      end

      def create
        render plain: 'ok'
      end
    end

    it 'makes the deserialized resource available in params' do
      post :create, params: payload

      expected = { 'type' => 'users', 'Name' => 'Lucas' }
      expect(controller.params[:user]).to eq(expected)
    end

    it 'makes the deserialization mapping available via #jsonapi_pointers' do
      post :create, params: payload

      expected = { Name: '/data/attributes/name',
                   type: '/data/type' }
      expect(controller.jsonapi_pointers).to eq(expected)
    end
  end

  context 'when deserializing multiple resources with default deserializer' do
    before(:each) do
      request.headers['Content-Type'] = 'application/vnd.api+json; ext="bulk"'
      JSONAPI::Rails.configure do |config|
        config.jsonapi_extensions = ['bulk']
      end
    end

    after(:each) do
      JSONAPI::Rails.configure do |config|
        config.clear
      end
    end

    controller do
      deserializable_resource :user

      def create
        render jsonapi: nil, extensions: ['bulk']
      end
    end

    it 'indexes the pointers to match the correct path in the document' do
      post :create, params: array_payload

      expected = [
        { name: '/data/0/attributes/name',
          type: '/data/0/type' },
        { name: '/data/1/attributes/name',
          type: '/data/1/type' }
      ]
      expect(controller.jsonapi_pointers).to eq(expected)
    end

    it 'makes the deserialized resources available in params' do
      post :create, params: array_payload

      expected = [
        { 'type' => 'users', 'name' => 'Lucas' },
        { 'type' => 'users', 'name' => 'Fran' }
      ]
      expect(controller.params[:user]).to eq(expected)
    end
  end
end

describe ActionController::Base, '#extension_request?', type: :controller do
  describe '#extension_request?' do
    subject { controller.extension_request?(inquired_extension) }

    before(:each) do
      request.headers['Content-Type'] = "application/vnd.api+json; ext=\"#{requested_extensions.join(',')}\""
      JSONAPI::Rails.configure do |config|
        config.jsonapi_extensions = supported_extensions
      end
    end

    after(:each) do
      JSONAPI::Rails.configure do |config|
        config.clear
      end
    end


    context 'when no extensions are supported' do
      let(:inquired_extension) { 'bulk' }
      let(:supported_extensions) { [] }
      let(:requested_extensions) { ['bulk', 'jsonpatch'] }

      it { is_expected.to be_falsey }
    end

    context 'when the inquired extension is not supported' do
      let(:inquired_extension) { 'jsonpatch' }
      let(:supported_extensions) { ['bulk'] }
      let(:requested_extensions) { ['bulk', 'jsonpatch'] }

      it { is_expected.to be_falsey }
    end

    context 'when the extension is supported but not requested' do
      let(:inquired_extension) { 'bulk' }
      let(:supported_extensions) { ['bulk', 'jsonpatch'] }
      let(:requested_extensions) { ['jsonpatch'] }

      it { is_expected.to be_falsey }
    end

    context 'when the extension is supported and requested' do
      let(:inquired_extension) { 'bulk' }
      let(:supported_extensions) { ['bulk', 'jsonpatch'] }
      let(:requested_extensions) { ['bulk'] }

      it { is_expected.to be_truthy }
    end

    context 'when multiple extensions are requested' do
      let(:inquired_extension) { 'bulk' }
      let(:supported_extensions) { ['bulk', 'jsonpatch'] }
      let(:requested_extensions) { ['bulk', 'jsonpatch'] }

      it 'detects the inquired extension' do
        expect(subject).to be_truthy
      end
    end
  end
end
