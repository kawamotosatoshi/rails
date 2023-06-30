# frozen_string_literal: true

module ActiveModel
  # = Active \Model \Attributes
  #
  # The Attributes module allows models to define attributes beyond simple Ruby
  # readers and writers. Similar to Active Record attributes, which are
  # typically inferred from the database schema, Active Model Attributes are
  # aware of data types, can have default values, and can handle casting and
  # serialization.
  #
  # To use Attributes, include the module in your model class and define your
  # attributes using the +attribute+ macro. It accepts a name, a type, a default
  # value, and any other options supported by the attribute type.
  #
  # ==== Examples
  #
  #   class Person
  #     include ActiveModel::Attributes
  #
  #     attribute :name, :string
  #     attribute :active, :boolean, default: true
  #   end
  #
  #   person = Person.new
  #   person.name = "Volmer"
  #
  #   person.name # => "Volmer"
  #   person.active # => true
  module Attributes
    extend ActiveSupport::Concern
    include ActiveModel::AttributeRegistration
    include ActiveModel::AttributeMethods

    included do
      attribute_method_suffix "=", parameters: "value"
    end

    module ClassMethods
      ##
      # :call-seq: attribute(name, cast_type = nil, default: nil, **options)
      #
      # Defines a model attribute. In addition to the attribute name, a cast
      # type and default value may be specified, as well as any options
      # supported by the given cast type.
      #
      #   class Person
      #     include ActiveModel::Attributes
      #
      #     attribute :name, :string
      #     attribute :active, :boolean, default: true
      #   end
      #
      #   person = Person.new
      #   person.name = "Volmer"
      #
      #   person.name   # => "Volmer"
      #   person.active # => true
      def attribute(name, ...)
        super
        define_attribute_method(name)
      end

      # Returns an array of attribute names as strings.
      #
      #   class Person
      #     include ActiveModel::Attributes
      #
      #     attribute :name, :string
      #     attribute :age, :integer
      #   end
      #
      #   Person.attribute_names # => ["name", "age"]
      def attribute_names
        attribute_types.keys
      end

      def attribute_names_with_aliases(replace: false)
        attrs = attribute_names.map(&:clone)
        attribute_aliases.each do |k, v|
          next unless (i = attrs.find_index(v))

          attrs[replace ? i : attrs.length] = k
        end
        attrs
      end

      private
        def define_method_attribute=(name, owner:)
          ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
            owner, name, writer: true,
          ) do |temp_method_name, attr_name_expr|
            owner.define_cached_method("#{name}=", as: temp_method_name, namespace: :active_model) do |batch|
              batch <<
                "def #{temp_method_name}(value)" <<
                "  _write_attribute(#{attr_name_expr}, value)" <<
                "end"
            end
          end
        end
    end

    def initialize(*) # :nodoc:
      @attributes = self.class._default_attributes.deep_dup
      super
    end

    def initialize_dup(other) # :nodoc:
      @attributes = @attributes.deep_dup
      super
    end

    # Returns a hash of all the attributes with their names as keys and the
    # values of the attributes as values.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :name, :string
    #     attribute :age, :integer
    #   end
    #
    #   person = Person.new
    #   person.name = "Francesco"
    #   person.age = 22
    #
    #   person.attributes # => { "name" => "Francesco", "age" => 22}
    def attributes
      @attributes.to_hash
    end

    # Returns an array of attribute names as strings.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :name, :string
    #     attribute :age, :integer
    #   end
    #
    #   person = Person.new
    #   person.attribute_names # => ["name", "age"]
    def attribute_names
      @attributes.keys
    end

    def attributes_with_aliases(replace: false)
      attrs = attributes.clone
      attribute_aliases.each do |k, v|
        attrs[k] = replace ? attrs.delete(v) : send(v)
      end
      attrs
    end

    def attribute_names_with_aliases(replace: false)
      attributes_with_aliases(replace: replace).keys
    end

    def freeze # :nodoc:
      @attributes = @attributes.clone.freeze unless frozen?
      super
    end

    private
      def _write_attribute(attr_name, value)
        @attributes.write_from_user(attr_name, value)
      end
      alias :attribute= :_write_attribute

      def attribute(attr_name)
        @attributes.fetch_value(attr_name)
      end
  end
end
