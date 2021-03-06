# encoding: utf-8

#  Copyright (C) 2012  Jan Bujak <j+cdata@jabster.pl>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#  As a special exception, you may create a larger work that contains part or
#  all of the C/C++ code generated by CData and distribute that work under
#  terms of your choice. If you modify this library, you may extend this
#  exception to your version of the library, but you are not obliged to do so.
#  If you do not wish to do so, delete this exception statement from your
#  version.

module CData

    class Type

        def native_name

            throw "internal error: unimplemented"

        end

        def embeddable_native_name

            return native_name.gsub( ' ', '_' ).gsub( '*', 'p' ).sub( /_t\Z/, '' ).sub( /\Acdata_/, '' )

        end

        def reference_name

            return 'const bool' if self == @bool_type

            type_name = native_name.dup
            type_name << " *" if instance_of?( ClassType ) || instance_of?( ArrayType ) || instance_of?( HashType ) || instance_of?( GenericType )
            type_name.gsub!( '*', '* const' ) if type_name.include? "*"
            type_name = "const #{type_name}" unless type_name.start_with? 'const'

            return type_name

        end

        def declaration_name

            type_name = native_name.dup
            type_name.gsub!( '*', '* const' ) if type_name.include? "*"
            type_name = "const #{type_name}" unless type_name.start_with? 'const'

            return type_name

        end

        def type_identifier

            return "cdata_type_#{embeddable_native_name}"

        end

        def hash

            return native_name.hash

        end

        def to_s

            return native_name

        end

        def eql?( another )

            return true  if another.instance_of?( self.class ) && another.native_name == native_name
            return false

        end

        def ==( another )

            return eql?( another )

        end

        def directly_embeddable?

            return false

        end

        def resolve_type( new_type )

            if new_type == nil

                throw "internal error: new_type == nil"

            end

            return self                  if new_type.instance_of?( NilType )
            return new_type              if self.instance_of?( NilType )     || self == new_type
            return GenericType::instance if self.instance_of?( GenericType ) || new_type.instance_of?( GenericType )

            if self.instance_of?( ArrayType ) && new_type.instance_of?( ArrayType )

                return self     if new_type.has_nil_type_at_the_bottom?
                return new_type if self.has_nil_type_at_the_bottom?

            end

            if self.instance_of?( HashType ) && new_type.instance_of?( HashType )

                # TODO

            end

            if self.instance_of?( IntType ) && new_type.instance_of?( IntType )

                return self if self.size_tier >= new_type.size_tier && self.unsigned? == new_type.unsigned?

                needs_signed = false
                needs_signed = true  if self.signed? || new_type.signed?

                promote_to_signed = false
                promote_to_signed = true  if needs_signed == true && self.signed? == false

                promote_by = [ new_type.size_tier - self.size_tier, 0 ].max
                promote_by += 1 if promote_to_signed == true && promote_by <= 1

                promote_to = self.size_tier + promote_by

                if promote_to > 4
                    throw "integer overflow"
                end

                case [ needs_signed, promote_to ]

                    when [ true, 1 ]; return IntType.signed_char_instance
                    when [ true, 2 ]; return IntType.signed_short_instance
                    when [ true, 3 ]; return IntType.signed_int_instance
                    when [ true, 4 ]; return IntType.signed_long_long_instance
                    when [ false, 1 ]; return IntType.unsigned_char_instance
                    when [ false, 2 ]; return IntType.unsigned_short_instance
                    when [ false, 3 ]; return IntType.unsigned_int_instance
                    when [ false, 4 ]; return IntType.unsigned_long_long_instance

                end

            elsif self.instance_of?( ClassType ) && new_type.instance_of?( ClassType )

                a_tree = self.superclass_tree_from_bottom
                b_tree = new_type.superclass_tree_from_bottom

                found = nil
                a_tree.each do |a|

                    b_tree.each do |b|

                        if a == b
                            found = a
                            break
                        end

                    end

                    break if found != nil

                end

                if found == nil

                    # TODO: FIXME: BUG: This shouldn't be done by default.
                    return GenericType::instance


                end

                return found

            else

                return GenericType::instance

            end

        end

        def is_arraylike

            return false

        end

        def is_hashlike

            return false

        end

    end

    class IntType < Type

        def size_tier

            return @size_tier

        end

        def unsigned?

            return @unsigned

        end

        def signed?

            return !unsigned?

        end

        def native_name

            return @native_name

        end

        def directly_embeddable?

            return true

        end

        private

        def initialize( native_name )

            @native_name = native_name
            @unsigned       = true if @native_name.include? 'unsigned'

            if @native_name.include?( 'char' )
                @size_tier = 1
            elsif @native_name.include?( 'short' )
                @size_tier = 2
            elsif @native_name.include?( 'int' )
                @size_tier = 3
            elsif @native_name.include?( 'long long' )
                @size_tier = 4
            else
                throw "internal error: unrecognized integer size"
            end

        end

    end

    class FloatType < Type

        def self.instance

            @instance ||= FloatType.new
            return @instance

        end

        def native_name

            return "float"

        end

        def directly_embeddable?

            return true

        end

        private

        def initialize
        end

    end

    class BoolType < Type

        def self.instance

            @instance ||= BoolType.new
            return @instance

        end

        def native_name

            return "bool"

        end

        def directly_embeddable?

            return true

        end

        private

        def initialize
        end

    end

    class StringType < Type

        def self.instance

            @instance ||= StringType.new
            return @instance

        end

        def native_name

            return "const char *"

        end

        def embeddable_native_name

            return 'string'

        end

        private

        def initialize
        end

    end

    class GenericType < Type

        def self.instance

            @instance ||= GenericType.new
            return @instance

        end

        def native_name

            return 'cdata_generic_t'

        end

        private

        def initialize
        end

    end

    class NilType < Type

        def self.instance

            @instance ||= NilType.new
            return @instance

        end

        def native_name

            return "cdata_nil_t"

        end

        def directly_embeddable?

            return false

        end

        private

        def initialize
        end

    end

    class ArrayType < Type

        attr_accessor :value_child

        def initialize

            @value_child = TypeChild.new

        end

        def native_name

            return "#{@value_child.type.embeddable_native_name}_array_t"

        end

        def has_nil_type_at_the_bottom?

            if value_child.type.instance_of?( NilType )
                return true
            elsif value_child.type.instance_of?( ArrayType )
                return value_child.type.has_nil_type_at_the_bottom?
            else
                return false
            end

        end

        def is_arraylike

            return true

        end

    end

    class HashType < Type

        attr_reader :key_child, :value_child

        def initialize

            @key_child   = TypeChild.new
            @value_child = TypeChild.new

        end

        def native_name

            return "#{@key_child.type.embeddable_native_name}_to_#{@value_child.type.embeddable_native_name}_hash_t"

        end

        def is_hashlike

            return true

        end

    end

    class ClassType < Type

        attr_accessor :native_name, :superclass, :cached_methods, :subclasses, :is_stringlike, :is_arraylike, :is_hashlike, :additional_code, :cdata_type_variable_name
        attr_accessor :custom_methods

        # For arraylike and hashlike classes.
        attr_accessor :key_child, :value_child

        def initialize

            @children = {}
            @cached_methods = []
            @subclasses = Set.new

            @is_stringlike = false
            @is_arraylike = false
            @is_hashlike = false

            @cdata_type_variable_name = 'type'
            @custom_methods = []

        end

        def superclass_tree_from_bottom

            tree = [ self ]
            superclass = self.superclass

            while superclass != nil
                tree << superclass
                superclass = superclass.superclass
            end

            return tree

        end

        def superclass_tree_from_top

            return superclass_tree_from_bottom.reverse

        end

        def children

            return @children

        end

        def tree_children

            children = {}
            self.superclass_tree_from_top.each do |klass|
                children = children.merge( klass.children )
            end

            return children

        end

        def includes_type?

            return @subclasses.size > 0 || @superclass != nil

        end

    end

    class TypeChild

        attr_accessor :type, :types

        def initialize

            @type  = NilType::instance
            @types = Set.new

        end

    end

end
