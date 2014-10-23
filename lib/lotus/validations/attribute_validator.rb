require 'lotus/validations/coercions'

# Quick fix for non MRI VMs that don't implement Range#size
#
# @since 0.1.0
class Range
  def size
    to_a.size
  end unless instance_methods.include?(:size)
end

module Lotus
  module Validations
    # Validator for a single attribute
    #
    # @since 0.1.0
    # @api private
    class AttributeValidator
      # Attribute naming convention for "confirmation" validation
      #
      # @see Lotus::Validations::AttributeValidator#confirmation
      #
      # @since 0.1.0
      # @api private
      CONFIRMATION_TEMPLATE = '%{name}_confirmation'.freeze

      # Initialize a validator
      #
      # @param validator [Lotus::Validations] an object which included
      #   Lotus::Validations module
      # @param name [Symbol] the name of the attribute
      # @param options [Hash] the set of validations for the attribute
      #
      # @since 0.1.0
      # @api private
      def initialize(validator, name, options)
        @validator, @name, @options = validator, name, options
        @value = _attribute(@name)
      end

      # Validate the attribute
      #
      # @return [void]
      #
      # @since 0.1.0
      # @api private
      def validate!
        presence
        acceptance

        _run_validations
      end

      private
      # Validates presence of the value.
      # This fails with `nil` and "blank" values.
      #
      # An object is blank if it isn't `nil`, but doesn't hold a value.
      # Empty strings and enumerables are an example.
      #
      # @see Lotus::Validations::ClassMethods#attribute
      # @see Lotus::Validations::AttributeValidator#nil_value?
      #
      # @since 0.1.0
      # @api private
      def presence
        _validate(__method__) { !blank_value? }
      end

      # Validates acceptance of the value.
      #
      # This passes if the value is "truthy", it fails if not.
      #
      # Truthy examples: `Object.new`, `1`, `"1"`, `true`.
      # Falsey examples: `nil`, `0`, `"0"`, `false`.
      #
      # @see Lotus::Validations::ClassMethods#attribute
      # @see http://www.rubydoc.info/gems/lotus-utils/Lotus/Utils/Kernel#Boolean-class_method
      #
      # @since 0.1.0
      # @api private
      def acceptance
        _validate(__method__) { Lotus::Utils::Kernel.Boolean(@value) }
      end

      # Validates format of the value.
      #
      # Coerces the value to a string and then check if it satisfies the defined
      # matcher.
      #
      # @see Lotus::Validations::ClassMethods#attribute
      #
      # @since 0.1.0
      # @api private
      def format
        _validate(__method__) {|matcher| @value.to_s.match(matcher) }
      end

      # Validates inclusion of the value in the defined collection.
      #
      # The collection is an objects which implements `#include?`.
      #
      # @see Lotus::Validations::ClassMethods#attribute
      #
      # @since 0.1.0
      # @api private
      def inclusion
        _validate(__method__) {|collection| collection.include?(@value) }
      end

      # Validates exclusion of the value in the defined collection.
      #
      # The collection is an objects which implements `#include?`.
      #
      # @see Lotus::Validations::ClassMethods#attribute
      #
      # @since 0.1.0
      # @api private
      def exclusion
        _validate(__method__) {|collection| !collection.include?(@value) }
      end

      # Validates confirmation of the value with another corresponding value.
      #
      # Given a `:password` attribute, it passes if the corresponding attribute
      # `:password_confirmation` has the same value.
      #
      # @see Lotus::Validations::ClassMethods#attribute
      # @see Lotus::Validations::AttributeValidator::CONFIRMATION_TEMPLATE
      #
      # @since 0.1.0
      # @api private
      def confirmation
        _validate(__method__) do
          _attribute == _attribute(CONFIRMATION_TEMPLATE % { name: @name })
        end
      end

      # Validates if value's size matches the defined quantity.
      #
      # The quantity can be a Ruby Numeric:
      #
      #   * `Integer`
      #   * `Fixnum`
      #   * `Float`
      #   * `BigNum`
      #   * `BigDecimal`
      #   * `Complex`
      #   * `Rational`
      #   * Octal literals
      #   * Hex literals
      #   * `#to_int`
      #
      # The quantity can be also any object which implements `#include?`.
      #
      # If the quantity is a Numeric, the size of the value MUST be exactly the
      # same.
      #
      # If the quantity is a Range, the size of the value MUST be included.
      #
      # The value is an object which implements `#size`.
      #
      # @raise [ArgumentError] if the defined quantity isn't a Numeric or a
      #   collection
      #
      # @see Lotus::Validations::ClassMethods#attribute
      #
      # @since 0.1.0
      # @api private
      def size
        _validate(__method__) do |validator|
          case validator
          when Numeric, ->(v) { v.respond_to?(:to_int) }
            @value.size == validator.to_int
          when Range
            validator.include?(@value.size)
          else
            raise ArgumentError.new("Size validator must be a number or a range, it was: #{ validator }")
          end
        end
      end

      # Coerces the value to the defined type.
      # Built in types are:
      #
      #   * `Array`
      #   * `BigDecimal`
      #   * `Boolean`
      #   * `Date`
      #   * `DateTime`
      #   * `Float`
      #   * `Hash`
      #   * `Integer`
      #   * `Pathname`
      #   * `Set`
      #   * `String`
      #   * `Symbol`
      #   * `Time`
      #
      # If a user defined class is specified, it can be freely used for coercion
      # purposes. The only limitation is that the constructor should have
      # **arity of 1**.
      #
      # @raise [TypeError] if the coercion fails
      # @raise [ArgumentError] if the custom coercer's `#initialize` has a wrong arity.
      #
      # @see Lotus::Validations::ClassMethods#attribute
      # @see Lotus::Validations::Coercions
      #
      # @since 0.1.0
      # @api private
      def coerce
        _validate(:type) do |coercer|
          @value = Lotus::Validations::Coercions.coerce(coercer, @value)
          _attributes[@name] = @value
          true
        end
      end

      # Checks if the value is `nil`.
      #
      # @since 0.1.0
      # @api private
      def nil_value?
        @value.nil?
      end

      alias_method :skip?, :nil_value?

      # Checks if the value is "blank".
      #
      # @see Lotus::Validations::AttributeValidator#presence
      #
      # @since 0.1.0
      # @api private
      def blank_value?
        nil_value? || (@value.respond_to?(:empty?) && @value.empty?)
      end

      # Run the defined validations
      #
      # @since 0.1.0
      # @api private
      def _run_validations
        return if skip?

        format
        coerce
        inclusion
        exclusion
        size
        confirmation
      end

      # Reads an attribute from the validator.
      #
      # @since 0.1.0
      # @api private
      def _attribute(name = @name)
        _attributes[name.to_sym]
      end

      # @since 0.1.0
      # @api private
      def _attributes
        @validator.__send__(:attributes)
      end

      # Run a single validation and collects the results.
      #
      # @since 0.1.0
      # @api private
      def _validate(validation)
        if (validator = @options[validation]) && !(yield validator)
          @validator.errors.add(@name, validation, @options.fetch(validation), @value)
        end
      end
    end
  end
end
