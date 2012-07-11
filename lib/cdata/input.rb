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

    class Serializer

        def serialize( value, variable_name = nil )

            register( value, variable_name, true, false, '' )

        end

        private

        def add_cached_value_wrapper_for( value, value_wrapper )

            type = value_wrapper.type

            if type.instance_of?( IntType )
                @int_value_to_value_wrapper[ value ] = value_wrapper
            elsif type == @float_type
                @float_value_to_value_wrapper[ value ] = value_wrapper
            elsif type == @bool_type
                @bool_value_to_value_wrapper[ value ] = value_wrapper
            elsif type == @string_type
                @string_value_to_value_wrapper[ value ] = value_wrapper
            elsif type.instance_of?( ArrayType )
                @array_value_to_value_wrapper[ value.__id__ ] = value_wrapper
            elsif type.instance_of?( HashType )
                @hash_value_to_value_wrapper[ value.__id__ ] = value_wrapper
            elsif type.instance_of?( ClassType )
                if type.is_stringlike == true
                    # Two different classes derived from String set to the same string will have the same hash.
                    # We need a separate hash for every string-derived type to support them properly.
                    @stringlike_class_value_to_value_wrapper_map[ type ] ||= {}
                    @stringlike_class_value_to_value_wrapper_map[ type ][ value ] = value_wrapper
                else
                    @class_value_to_value_wrapper[ value ] = value_wrapper
                end
            elsif type.instance_of?( NilType )
                @nil_value_wrapper = value_wrapper
            else
                throw "internal error"
            end

        end

        def has_cached_value_wrapper_for?( value, type )

            return get_cached_value_wrapper_for( value, type ) != nil

        end

        def get_cached_value_wrapper_for( value, type )

            if type.instance_of?( IntType )
                return @int_value_to_value_wrapper[ value ]
            elsif type == @float_type
                return @float_value_to_value_wrapper[ value ]
            elsif type == @bool_type
                return @bool_value_to_value_wrapper[ value ]
            elsif type == @string_type
                return @string_value_to_value_wrapper[ value ]
            elsif type.instance_of?( ArrayType )
                return @array_value_to_value_wrapper[ value.__id__ ]
            elsif type.instance_of?( HashType )
                return @hash_value_to_value_wrapper[ value.__id__ ]
            elsif type.instance_of?( ClassType )
                if type.is_stringlike == true
                    @stringlike_class_value_to_value_wrapper_map[ type ] ||= {}
                    return @stringlike_class_value_to_value_wrapper_map[ type ][ value ]
                else
                    return @class_value_to_value_wrapper[ value ]
                end
            elsif type.instance_of?( NilType )
                return @nil_value_wrapper
            else
                throw "internal error: unexpected type passed: #{type.inspect}"
            end

        end

        def register( value, variable_name, is_exported, is_referenced, qualified_path )

            if value.instance_of?( value.class ) == false
                throw "error: a variable of type '#{value.class}' passed yet instance_of?( #{value.class} ) returns false!"
            end

            if value == nil

                return wrap( value, variable_name, @nil_type, is_exported, is_referenced, qualified_path )

            elsif value == true

                return wrap( value, variable_name, @bool_type, is_exported, is_referenced, qualified_path )

            elsif value == false

                return wrap( value, variable_name, @bool_type, is_exported, is_referenced, qualified_path )

            elsif value.kind_of? Fixnum

                type = nil
                if value >= 0

                    if value < 2 ** 8
                        type = @unsigned_char_type
                    elsif value < 2 ** 16
                        type = @unsigned_short_type
                    elsif value < 2 ** 32
                        type = @unsigned_int_type
                    else
                        type = @unsigned_long_long_type
                    end

                else

                    if value >= -(2 ** 8 / 2) && value < (2 ** 8 / 2)
                        type = @signed_char_type
                    elsif value >= -(2 ** 16 / 2) && value < (2 ** 16 / 2)
                        type = @signed_short_type
                    elsif value >= -(2 ** 32 / 2) && value < (2 ** 32 / 2)
                        type = @signed_int_type
                    else
                        type = @signed_long_long_type
                    end

                end

                return wrap( value, variable_name, type, is_exported, is_referenced, qualified_path )

            elsif value.kind_of? Float

                return wrap( value, variable_name, @float_type, is_exported, is_referenced, qualified_path )

            elsif value.instance_of? String

                return wrap( value, variable_name, @string_type, is_exported, is_referenced, qualified_path )

            elsif value.instance_of? Array

                qualified_path = "array_#{value.__id__}" if qualified_path.empty?

                type = ArrayType.new
                result = wrap( value, variable_name, type, is_exported, is_referenced, qualified_path )
                register_array_value( result, qualified_path )

                return result

            elsif value.instance_of? Hash

                if CData.hashes_supported? == false
                    throw "As 'inline' library was not found hashes are unsupported!"
                end

                qualified_path = "hash_#{value.__id__}" if qualified_path.empty?

                type = HashType.new
                result = wrap( value, variable_name, type, is_exported, is_referenced, qualified_path )
                register_hash_value( result, qualified_path )

                return result

            else

                type = register_custom_type( value, value.class )
                was_wrapped = has_cached_value_wrapper_for?( value, type )

                result = wrap( value, variable_name, type, is_exported, is_referenced, qualified_path )

                return result if was_wrapped == true

                if type.is_stringlike == true

                    cloned = "#{value.to_s}"

                    string_child = wrap( cloned, nil, @string_type, false, true, '' )
                    result.children << string_child

                    if string_child.value.class != String
                        throw "internal error: string_child.value.class != String"
                    end

                elsif type.is_arraylike == true

                    register_array_value( result, qualified_path )

                elsif type.is_hashlike == true

                    register_hash_value( result, qualified_path )

                end

                type.cached_methods.each do |type, klass, method, name|

                    method_qualified_path = "#{klass}.#{name}"

                    child = value.send( method )
                    registered_child = register( child, nil, false, true, method_qualified_path )

                    @types_for_qualified_path[ method_qualified_path ] ||= Set.new
                    @wrappers_for_qualified_path[ method_qualified_path ] ||= []

                    member = type.children[ name ]
                    member.type = member.type.resolve_type( registered_child.type )
                    member.types.add registered_child.type

                    result.children << registered_child

                end

                return result

            end

        end

        def register_array_value( result, qualified_path )

            value = result.value
            type  = result.type

            value_child_qualified_path = ''
            unless qualified_path.empty?

                value_child_qualified_path = "#{qualified_path}.values"

                @types_for_qualified_path[ value_child_qualified_path ] ||= Set.new
                @wrappers_for_qualified_path[ value_child_qualified_path ] ||= []

            end

            value.each do |element|

                child = register( element, nil, false, true, value_child_qualified_path )
                result.children << child

                type.value_child.type = child.type.resolve_type( type.value_child.type )
                type.value_child.types.add child.type

            end

        end

        def register_hash_value( result, qualified_path )

            value = result.value
            type  = result.type

            key_child_qualified_path   = ''
            value_child_qualified_path = ''

            unless qualified_path.empty?

                key_child_qualified_path   = "#{qualified_path}.keys"
                value_child_qualified_path = "#{qualified_path}.values"

                @types_for_qualified_path[ key_child_qualified_path ] ||= Set.new
                @types_for_qualified_path[ value_child_qualified_path ] ||= Set.new

                @wrappers_for_qualified_path[ key_child_qualified_path ] ||= []
                @wrappers_for_qualified_path[ value_child_qualified_path ] ||= []

            end

            value.each do |key, element|

                key_child   = register( key, nil, false, true, key_child_qualified_path )
                value_child = register( element, nil, false, true, value_child_qualified_path )

                result.children << [ key_child, value_child ]

                type.key_child.type     = key_child.type.resolve_type( type.key_child.type )
                type.value_child.type   = value_child.type.resolve_type( type.value_child.type )

                type.key_child.types.add   key_child.type
                type.value_child.types.add value_child.type

            end

        end

        def register_custom_type( value, klass )

            return @klass_to_klass_type[ klass ] if @klass_to_klass_type.has_key? klass

            methods = klass.methods( false )

            type = ClassType.new

            name = klass.to_s
            name = name.gsub( /([a-z])([A-Z])/ ) { "#{$1}_#{$2}" }
            name.gsub!( '::', '_' )
            name.downcase!
            name << "_t"

            name = klass.cdata_name if methods.include?( :cdata_name )

            type.native_name = name
            type.additional_code = klass.cdata_code if methods.include?( :cdata_code )
            type.cdata_type_variable_name = klass.cdata_type_variable_name if klass.methods.include?( :cdata_type_variable_name )

            if klass.superclass != Object

                if klass.superclass == String

                    type.is_stringlike = true

                elsif klass.superclass == Array

                    type.is_arraylike = true
                    type.value_child = TypeChild.new

                elsif klass.superclass == Hash

                    type.is_hashlike = true
                    type.key_child   = TypeChild.new
                    type.value_child = TypeChild.new

                else

                    type.superclass = register_custom_type( value, klass.superclass )
                    type.superclass.subclasses.add type
                    type.cached_methods += type.superclass.cached_methods
                    type.is_stringlike = type.superclass.is_stringlike
                    type.is_arraylike = type.superclass.is_arraylike
                    type.is_hashlike = type.superclass.is_hashlike
                    type.key_child = type.superclass.key_child
                    type.value_child = type.superclass.value_child

                end

            end

            if methods.include?( :cdata_methods )

                renamed_methods = {}
                if methods.include?( :cdata_rename )

                    renamed_methods = klass.cdata_rename

                end

                klass.cdata_methods.each do |method|

                    name = method.to_s
                    if renamed_methods.has_key? method
                        name = renamed_methods[ method ]
                    elsif renamed_methods.has_key? name
                        name = renamed_methods[ name ]
                    end

                    name = "is_#{name.to_s[ 0..-2 ]}" if name.to_s.end_with? '?'

                    type.cached_methods << [ type, klass, method, name ]
                    type.children[ name ] = TypeChild.new

                end

            end

            @klass_to_klass_type[ klass ] = type

            return type

        end

        def wrap( value, name, type, is_exported, is_referenced, qualified_path )

            if value == nil

                if type.instance_of?( IntType )
                    value = 0
                elsif type.instance_of?( FloatType )
                    value = 0.0
                elsif type.instance_of?( StringType )
                    value = ""
                elsif type.instance_of?( BoolType )
                    value = false
                end

            end

            unless qualified_path.empty?

                @types_for_qualified_path[ qualified_path ] ||= Set.new
                @types_for_qualified_path[ qualified_path ].add type

                @wrappers_for_qualified_path[ qualified_path ] ||= []

            end

            value_wrapper = get_cached_value_wrapper_for( value, type )
            result = nil

            if value_wrapper != nil

                value_wrapper.is_exported = true if is_exported == true
                result = value_wrapper

            else

                value_wrapper = ValueWrapper.new( value, name, type, is_exported, is_referenced )
                @value_wrappers << value_wrapper

                add_cached_value_wrapper_for( value, value_wrapper )

                result = value_wrapper

            end

            unless qualified_path.empty?

                @wrappers_for_qualified_path[ qualified_path ] << result

            end

            return result

        end

    end

end
