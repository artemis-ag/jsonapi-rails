module JSONAPI
  module Rails
    module ActiveModel
      Errors = Struct.new(:errors, :reverse_mapping)
    end
  end
end
