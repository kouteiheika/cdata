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

        def generate

            types = Set.new
            child_type_to_array_type = {}
            child_type_to_hash_type  = {}
            exported   = []
            referenced = Set.new
            generics   = Set.new

            custom_type_trees = []
            max_tree_depth = 0

            @wrappers_for_qualified_path.each do |path, list|

                nil_wrappers = []
                nil_array_wrappers = []

                non_nil_wrapper = nil
                non_nil_array_wrapper = nil

                # TODO: Hashes

                list.each do |value_wrapper|

                    if value_wrapper.type == NilType::instance
                        nil_wrappers << value_wrapper
                    else

                        if non_nil_wrapper == nil
                            non_nil_wrapper = value_wrapper
                        end

                        if value_wrapper.type.instance_of?( ArrayType )

                            if value_wrapper.type.value_child.type == NilType::instance
                                nil_array_wrappers << value_wrapper
                            elsif non_nil_array_wrapper == nil
                                non_nil_array_wrapper = value_wrapper
                            end

                        end

                    end

                end

                if nil_wrappers.empty? == false && non_nil_wrapper != nil

                    nil_wrappers.each do |value_wrapper|
                        value_wrapper.type = non_nil_wrapper.type
                    end

                end

                if nil_array_wrappers.empty? == false && non_nil_array_wrapper != nil

                    nil_array_wrappers.each do |value_wrapper|
                        value_wrapper.type.value_child.type = non_nil_array_wrapper.type.value_child.type
                    end

                end

            end

            @value_wrappers.each do |value_wrapper|

                if value_wrapper.type == @generic_type

                    throw "internal error: exported generic type: #{value_wrapper.value.inspect}"

                end

                if value_wrapper.is_exported

                    exported   << value_wrapper

                elsif value_wrapper.is_referenced && value_wrapper.type.directly_embeddable? == false

                    referenced << value_wrapper

                end

                if value_wrapper.name == nil

                    if value_wrapper.type.instance_of?( IntType )
                        value_wrapper.name = "integer__#{value_wrapper.value.to_i.to_s.sub( '-', 'neg' )}"
                    elsif value_wrapper.type == @float_type
                        value_wrapper.name = "float__#{value_wrapper.value.to_f.to_s.gsub( '.', 'dot' ).sub( '-', 'neg' )}"
                    elsif value_wrapper.value == true
                        value_wrapper.name = "bool__true"
                    elsif value_wrapper.value == false
                        value_wrapper.name = "bool__false"
                    else
                        value_wrapper.name = "s#{generate_new_id}"
                    end

                end

                if value_wrapper.type.is_arraylike == true

                    if value_wrapper.type.instance_of?( ArrayType )

                        child_type   = value_wrapper.type.value_child.type
                        unified_type = child_type_to_array_type[ child_type ]

                        if unified_type != nil

                            value_wrapper.type = unified_type

                        else

                            child_type_to_array_type[ child_type ] = value_wrapper.type
                            types.add value_wrapper.type

                        end

                    end

                    if value_wrapper.type.value_child.type == @generic_type

                        value_wrapper.array_children.each do |child|

                            generics.add child
                            referenced.add child

                        end

                    end

                elsif value_wrapper.type.is_hashlike == true

                    if value_wrapper.type.instance_of?( HashType )

                        child_key_type   = value_wrapper.type.key_child.type
                        child_value_type = value_wrapper.type.value_child.type
                        child_type       = [ child_key_type, child_value_type ]
                        unified_type     = child_type_to_hash_type[ child_type ]

                        if unified_type != nil

                            value_wrapper.type = unified_type

                        else

                            child_type_to_hash_type[ child_type ] = value_wrapper.type
                            types.add value_wrapper.type

                        end

                    end

                    is_generic_key   = value_wrapper.type.key_child.type   == @generic_type
                    is_generic_value = value_wrapper.type.value_child.type == @generic_type

                    if is_generic_key || is_generic_value

                        value_wrapper.hash_children.each do |key_child, value_child|

                            if is_generic_key == true

                                generics.add key_child
                                referenced.add key_child

                            end

                            if is_generic_value == true

                                generics.add value_child
                                referenced.add value_child

                            end

                        end

                    end

                end

                if value_wrapper.type.instance_of?( ClassType )

                    unless types.has_key? value_wrapper.type

                        klass = value_wrapper.type
                        while klass != nil

                            types.add klass
                            klass = klass.superclass

                        end

                        tree = value_wrapper.type.superclass_tree_from_top
                        custom_type_trees << tree
                        max_tree_depth = [ max_tree_depth, tree.size ].max

                    end

                    if value_wrapper.class_children.empty?

                        value_wrapper.type.superclass_tree_from_top.each do |klass|

                            klass.children.each do |id, type_child|
                                value_wrapper.children << register( nil, nil, false, false, "#{klass}.#{id}" )
                            end

                        end

                    end

                    type_children  = value_wrapper.type.tree_children
                    value_children = value_wrapper.class_children

                    if type_children.size != value_children.size
                        throw "internal error: type_children.size (#{type_children.size}) != value_children.size (#{value_children.size}) for #{value_wrapper.type.native_name} #{value_wrapper.name}"
                    end

                    value_children.each_with_index do |child, index|

                        type_child = type_children[ type_children.keys[ index ] ]
                        if type_child.type == @generic_type

                            generics.add child
                            referenced.add child

                        end

                    end

                end

            end

            sorted_custom_types = []
            0.upto( max_tree_depth ) do |i|

                list = []

                custom_type_trees.each do |tree|

                    next if i >= tree.size
                    list << tree[ i ]

                end

                sorted_custom_types << list

            end

            fp = CData::StringIO.new
            generate_header_start( fp )

            unless types.empty?

                fp.puts "/* Forward declaration of types. */"
                types.each do |type|
                    fp.puts "struct #{type.native_name};"
                end
                fp.puts

                fp.puts "/* Types. */"
                types.each do |type|
                    fp.puts "extern const cdata_type_t * const #{type.type_identifier};"
                end
                fp.puts

                fp.puts "/* Definitions of types. */"
                types.each do |type|

                    if type.instance_of?( ArrayType )

                        generate_array_code( fp, type )

                    elsif type.instance_of?( HashType )

                        generate_hash_code( fp, type )

                    end

                end

                sorted_custom_types.each do |list|

                    done = Set.new
                    list.each do |type|

                        next if done.include? type
                        done.add type

                        type_t = type.native_name

                        if type.is_hashlike == true

                            generate_hash_outside_code( fp, type )

                        end

                        fp.print "struct #{type_t}"
                        fp.print " /* : public #{type.superclass.native_name} */" if type.superclass != nil
                        fp.puts
                        fp.puts "{"

                        if type.is_arraylike == true

                            fp.extra_indentation += 4
                            generate_array_inline_code( fp, type )
                            fp.extra_indentation -= 4

                        elsif type.is_hashlike == true

                            fp.extra_indentation += 4
                            generate_hash_inline_code( fp, type )
                            fp.extra_indentation -= 4

                        elsif type.is_stringlike == true

                            fp.puts "    const char * const value;"
                            fp.puts

                            fp.puts "    operator const char * const () const"
                            fp.puts "    {"
                            fp.puts "        return value;"
                            fp.puts "    }"

                        end

                        fp.puts "    const #{type_t} * operator ->() const"
                        fp.puts "    {"
                        fp.puts "        return this;"
                        fp.puts "    }"
                        fp.puts

                        tree = type.superclass_tree_from_bottom
                        tree[ 1..-1 ].each do |superclass|

                            fp.puts "    operator const #{superclass.native_name} *() const"
                            fp.puts "    {"
                            fp.puts "        return (const #{superclass.native_name} *)this;"
                            fp.puts "    }"
                            fp.puts

                        end

                        if type.includes_type?

                            fp.puts "    const cdata_type_t * const #{type.cdata_type_variable_name};"

                        end

                        tree.reverse.each do |type|

                            if tree.size > 1
                                fp.puts "  /* #{type.native_name} */"
                            end

                            type.children.each do |method, metadata|

                                if metadata == nil
                                    throw "internal error: metadata == nil for #{type_t}.#{method}"
                                end

                                if metadata.type == nil
                                    throw "internal error: metadata.type == nil for #{type_t}.#{method}"
                                end

                                append = ''

                                # if method_type.instance_of?( ArrayType ) && method_type.value_type == @generic_type
                                #     append << " /* -> #{method_type.value_types_list.collect { |type| type.to_s }.join( ", " )} */"
                                # end
=begin TODO: FIXME
                                qualified_type_name = "#{type.original_type}::#{method}"
                                if @qualified_generic_types_map.has_key? qualified_type_name
                                    append << " /* -> #{@qualified_generic_types_map[ qualified_type_map ].collect { |type| type.to_s }.join( ", " )} */"
                                end
=end
                                fp.puts "    #{metadata.type.reference_name} #{method};#{append}"

                            end

                            if type.additional_code != nil
                                fp.puts
                                fp.extra_indentation += 4
                                fp.m_puts type.additional_code
                                fp.extra_indentation -= 4
                            end

                        end
                        fp.puts "};"
                        fp.puts

                        if type.is_arraylike == true

                            generate_array_outside_code( fp, type )

                        end

                    end

                end

            end

            unless exported.empty?

                fp.puts "/* Exported variables. */"
                exported.each do |value_wrapper|

                    fp.puts "extern #{value_wrapper.type.declaration_name} #{value_wrapper.name};"

                end
                fp.puts

            end

            generate_header_end( fp )
            @header = fp.string

            fp = CData::StringIO.new
            generate_source_start( fp )

            unless types.empty?

                fp.puts "/* Types. */"
                types.each do |type|
                    fp.puts "static const cdata_type_t #{type.type_identifier}__instance = {};"
                    fp.puts "const cdata_type_t * const #{type.type_identifier} = &#{type.type_identifier}__instance;"
                end
                fp.puts

            end

            unless referenced.empty?

                fp.puts "/* Forward declarations. */"
                referenced.each do |value_wrapper|

                    fp.puts "extern #{value_wrapper.type.declaration_name} #{value_wrapper.name};"

                end
                fp.puts

            end

            fp.puts "/* Generic wrappers. */"
            generics.each do |value_wrapper|

                name            = value_wrapper.name
                type_identifier = value_wrapper.type.type_identifier

                reference = nil

                if value_wrapper.type.native_name.end_with?( '*' )
                    reference = name
                else
                    reference = "&#{name}"
                end

                fp.puts "cdata_generic_t #{value_wrapper.generic_name} = { #{type_identifier}, ( const void * const )#{reference} };"

            end
            fp.puts

            if exported.empty? == false || referenced.empty? == false

                fp.puts "/* Definitions. */"
                exported.each   { |value_wrapper| generate_definition( fp, value_wrapper ) }
                referenced.each { |value_wrapper| generate_definition( fp, value_wrapper ) }
                fp.puts

            end

            generate_source_end( fp )
            @source = fp.string

        end

        private

        def prepare_array_definition( fp, value_wrapper )

            type            = value_wrapper.type
            name            = value_wrapper.name
            value_type_name = type.value_child.type.reference_name

            fp.puts "static #{value_type_name} #{name}__data[] ="
            fp.puts "{"
            fp.puts "    #{value_wrapper.array_children.collect { |child| child.reference( type.value_child.type ) }.join( ', ' )}"
            fp.puts "};"
            fp.puts

            return [ value_wrapper.array_children.size.to_s, "#{name}__data" ]

        end

        def prepare_hash_definition( fp, value_wrapper )

            value_wrapper.value = {} if value_wrapper.value == nil

            type      = value_wrapper.type
            type_name = value_wrapper.type.declaration_name
            name      = value_wrapper.name
            value     = value_wrapper.value

            hashtable_size = (value.size * 1.5).to_i
            minimum_hash = nil

            hash = { }
            value_wrapper.hash_children.each do |key, value|

                hashed_key = key.value.cdata_hash % hashtable_size

                minimum_hash = hashed_key if minimum_hash == nil || hashed_key < minimum_hash
                hash[ hashed_key ] ||= [ ]
                hash[ hashed_key ] << [ key, value ]

            end

            buckets = { }
            hash.each do |hashed_key, contents|

                fp.print "static #{type_name}__pair_t #{name}__bucket_#{hashed_key}_pairs[] = { "

                output = [ ]
                contents.each_with_index do |entry, index|

                    key, value = entry
                    output << "{ #{key.reference( type.key_child.type )}, #{value.reference( type.value_child.type )} }"

                end

                fp.print output.join( ", " )
                fp.puts " };"

                buckets[ hashed_key ] = [ contents.size.to_s, "&#{name}__bucket_#{hashed_key}_pairs[ 0 ]" ]

            end

            next_bucket_map = { }
            previous_key = nil
            hash.keys.sort.each do |key|

                if previous_key == nil

                    previous_key = key
                    next

                end

                next_bucket_map[ previous_key ] = key
                previous_key = key

            end

            fp.puts "static #{type_name}__bucket_t #{name}__buckets[ ] ="
            fp.puts "{"
            0.upto( hashtable_size - 1 ) do |current|

                fp.print "    "
                if buckets.has_key?( current )

                    next_bucket_index = "(unsigned)~0"
                    next_bucket_index = next_bucket_map[ current ] if next_bucket_map.has_key?( current )
                    fp.print "{ #{buckets[ current ][ 0 ]}, #{next_bucket_index}, #{buckets[ current ][ 1 ]} }"

                else

                    fp.print "{ 0, 0, 0 }"

                end
                if current != hashtable_size - 1

                    fp.puts ", "

                else

                    fp.puts

                end
            end

            fp.puts "};"

            if minimum_hash == nil
                minimum_hash = "(unsigned)~0"
            end

            return [ minimum_hash, value_wrapper.hash_children.size, hashtable_size, "&#{name}__buckets[ 0 ]" ]

        end

        def prepare_class_definition( fp, value_wrapper )

            type      = value_wrapper.type
            type_name = value_wrapper.type.declaration_name
            name      = value_wrapper.name
            value     = value_wrapper.value

            type_children  = type.tree_children
            value_children = value_wrapper.class_children

            if type_children.size != value_children.size
                throw "internal error: type_children.size (#{type_children.size}) != value_children.size (#{value_children.size}) for #{type.native_name} #{value_wrapper.name}"
            end

            references = []
            value_children.each_with_index do |child, index|

                type_child = type_children[ type_children.keys[ index ] ]
                if type_child == nil
                    throw "internal error: type_child == nil for #{value_wrapper.type.native_name}.#{type_children.keys[ index ]}"
                end

                references << child.reference( type_child.type )

            end

            if type.includes_type?
                references = [ value_wrapper.type.type_identifier ] + references
            end

            return references

        end

        def generate_structure_definition( fp, value_wrapper, references )

            fp.puts "#{value_wrapper.type.declaration_name} #{value_wrapper.name} ="
            fp.puts "{"
            fp.puts "    #{references.join( ', ' )}"
            fp.puts "};"

        end

        def generate_definition( fp, value_wrapper )

            type      = value_wrapper.type
            type_name = value_wrapper.type.declaration_name
            name      = value_wrapper.name
            value     = value_wrapper.value

            if type == @nil_type

                fp.puts "#{type_name} #{name} = 0;"

            elsif type == @string_type

                value = escape_cstring( value_wrapper.value.to_s )
                fp.puts "#{type_name} #{name} = \"#{value}\";"

            elsif type.instance_of?( IntType )

                fp.puts "#{type_name} #{name} = #{value};"

            elsif type == @float_type

                fp.puts "#{type_name} #{name} = #{value}f;"

            elsif type == @bool_type

                fp.puts "#{type_name} #{name} = #{value.to_s};"
=begin
            elsif type == @string_with_length_type

                fp.puts "#{type_name} #{name} ="
                fp.puts "{"
                fp.puts "    #{value.bytesize}, \"#{escape_cstring( value )}\""
                fp.puts "};"
=end
            elsif type.instance_of?( ArrayType )

                references = prepare_array_definition( fp, value_wrapper )
                generate_structure_definition( fp, value_wrapper, references )

            elsif type.instance_of?( HashType )

                references = prepare_hash_definition( fp, value_wrapper )
                generate_structure_definition( fp, value_wrapper, references )

            elsif type.instance_of?( ClassType )

                if type.is_arraylike == true
                    references = prepare_array_definition( fp, value_wrapper ) + prepare_class_definition( fp, value_wrapper )
                elsif type.is_hashlike == true
                    references = prepare_hash_definition( fp, value_wrapper ) + prepare_class_definition( fp, value_wrapper )
                elsif type.is_stringlike == true
                    references = [ value_wrapper.string_child.reference( @string_type ) ] + prepare_class_definition( fp, value_wrapper )
                else
                    references = prepare_class_definition( fp, value_wrapper )
                end
                generate_structure_definition( fp, value_wrapper, references )

            else

                throw "internal error: unknown type: #{type}"

            end

        end

    end

end
