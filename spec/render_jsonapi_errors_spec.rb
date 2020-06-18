require 'rails_helper'

describe ActionController::Base, '#render', type: :controller do
  with_model :User, scope: :all do
    table do |t|
      t.string :name
      t.string :email
    end

    model do
      validates :name, presence: true
      validates :email, format: { with: /@/, message: 'must be a valid email' }
    end
  end

  let(:serialized_errors) do
    {
      'errors' => [
        {
          'detail' => 'Name can\'t be blank',
          'title' => 'Invalid name',
          'source' => { 'pointer' => '/data/attributes/name' }
        },
        {
          'detail' => 'Email must be a valid email',
          'title' => 'Invalid email',
          'source' => { 'pointer' => '/data/attributes/email' }
        }
      ],
      'jsonapi' => { 'version' => '1.0' }
    }
  end

  context 'when rendering ActiveModel::Errors' do
    controller do
      def create
        user = User.new(email: 'lucas')

        unless user.valid?
          render jsonapi_errors: user.errors
        end
      end

      def jsonapi_pointers
        {
          name: '/data/attributes/name',
          email: '/data/attributes/email'
        }
      end
    end

    subject { JSON.parse(response.body) }

    it 'renders a JSON API error document' do
      post :create

      expect(response.content_type).to eq('application/vnd.api+json')
      is_expected.to eq(serialized_errors)
    end
  end

  context 'when rendering error hashes' do
    controller do
      def create
        errors = [
          {
            detail: 'Name can\'t be blank',
            title: 'Invalid name',
            source: { pointer: '/data/attributes/name' }
          },
          {
            detail: 'Email must be a valid email',
            title: 'Invalid email',
            source: { pointer: '/data/attributes/email' }
          }
        ]

        render jsonapi_errors: errors
      end
    end

    subject { JSON.parse(response.body) }

    it 'renders a JSON API error document' do
      post :create

      expect(response.content_type).to eq('application/vnd.api+json')
      is_expected.to eq(serialized_errors)
    end
  end

  context 'when rendering ActiveModel::Errors with bulk extension' do
    let(:serialized_bulk_errors) do
      {
        'errors' => [
          {
            'detail' => 'Name can\'t be blank',
            'title' => 'Invalid name',
            'source' => { 'pointer' => '/data/0/attributes/name' }
          },
          {
            'detail' => 'Email must be a valid email',
            'title' => 'Invalid email',
            'source' => { 'pointer' => '/data/0/attributes/email' }
          },
          {
            'detail' => 'Name can\'t be blank',
            'title' => 'Invalid name',
            'source' => { 'pointer' => '/data/1/attributes/name' }
          },
          {
            'detail' => 'Email must be a valid email',
            'title' => 'Invalid email',
            'source' => { 'pointer' => '/data/1/attributes/email' }
          }
        ],
        'jsonapi' => { 'version' => '1.0' }
      }
    end

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
      def create
        users = [User.new(email: 'lucas'), User.new(email: 'fran')]

        unless users.map(&:valid?).all?
          render jsonapi_errors: users.map(&:errors), extensions: ['bulk']
        end
      end

      def jsonapi_pointers
        [
          {
            name: '/data/0/attributes/name',
            email: '/data/0/attributes/email'
          },
          {
            name: '/data/1/attributes/name',
            email: '/data/1/attributes/email'
          }
        ]
      end
    end

    subject { JSON.parse(response.body) }

    it 'renders a JSON API error document' do
      post :create

      expect(response.content_type).to eq('application/vnd.api+json; supported-ext="bulk"; ext="bulk"')
      is_expected.to eq(serialized_bulk_errors)
    end
  end

  context 'when rendering ActiveModel::Errors with bulk extension' do
    let(:serialized_bulk_errors) do
      {
        'errors' => [
          {
            'detail' => 'Name can\'t be blank',
            'title' => 'Invalid name',
            'source' => { 'pointer' => '/data/1/attributes/name' }
          },
          {
            'detail' => 'Email must be a valid email',
            'title' => 'Invalid email',
            'source' => { 'pointer' => '/data/1/attributes/email' }
          },
          {
            'detail' => 'Email must be a valid email',
            'title' => 'Invalid email',
            'source' => { 'pointer' => '/data/3/attributes/email' }
          }
        ],
        'jsonapi' => { 'version' => '1.0' }
      }
    end

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
      def create
        users = [
          User.new(name: 'lucas', email: 'lucas@'),
          User.new(email: 'fran'),
          User.new(name: 'jeff', email: 'jeff@'),
          User.new(name: 'paula', email: 'paula'),
        ]

        unless users.map(&:valid?).all?
          render jsonapi_errors: users.map(&:errors), extensions: ['bulk']
        end
      end

      def jsonapi_pointers
        [
          {
            name: '/data/0/attributes/name',
            email: '/data/0/attributes/email'
          },
          {
            name: '/data/1/attributes/name',
            email: '/data/1/attributes/email'
          },
          {
            name: '/data/2/attributes/name',
            email: '/data/2/attributes/email'
          },
          {
            name: '/data/3/attributes/name',
            email: '/data/3/attributes/email'
          }
        ]
      end
    end

    subject { JSON.parse(response.body) }

    it 'matches sparse errors correctly to the original pointerst' do
      with_config(jsonapi_extensions: ['bulk']) do
        post :create
      end

      is_expected.to eq(serialized_bulk_errors)
    end
  end
end
