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

    class Multiset

        def initialize( contents = [] )

            @hash = { }

            contents.each do |element|
                add( element )
            end

        end

        def add( element, how_many = 1 )

            if @hash.has_key?( element )
                @hash[ element ] += how_many
            else
                @hash[ element ] = how_many
            end

        end

        def <<( element )
            add( element )
        end

        def remove( element )

            return if @hash.has_key?( element ) == false
            @hash[ element ] -= 1
            @hash.delete( element ) if @hash[ element ] <= 0

        end

        def remove_all( element )
            @hash.delete( element )
        end

        def clear
            @hash.clear
        end

        def count( element = nil )

            return @hash.keys.size if element == nil
            return @hash[ element ].to_i

        end

        # TODO: Slow.
        def total_count

            total = 0
            self.each do |key, count|
                total += count
            end

            return total

        end

        def size

            return @hash.keys.size

        end

        alias_method :length, :size

        def includes?( element )

            return @hash.has_key?( element )

        end

        alias_method :include?, :includes?

        def elements

            return @hash.keys

        end

        def sorted_elements

            return @hash.sort { |b, a| a[ 1 ] <=> b[ 1 ] }

        end

        alias_method :to_a, :elements
        alias_method :keys, :elements
        alias_method :to_sorted_a, :sorted_elements
        alias_method :sorted_keys, :sorted_elements
        alias_method :sorted, :sorted_elements
        alias_method :include?, :includes?
        alias_method :has?, :includes?
        alias_method :has_key?, :includes?

        def each( &block )

            if block.arity == 1

                @hash.each do |key, value|

                    block.call( key )

                end

            elsif block.arity == 2

                @hash.each do |key, value|

                    block.call( key, value )

                end

            else

                throw ArgumentError.new( "invalid block arity" )

            end

        end

        def sorted_each( &block )

            if block.arity == 1

                sorted_elements.each do |key, value|

                    block.call( key )

                end

            elsif block.arity == 2

                sorted_elements.each do |key, value|

                    block.call( key, value )

                end

            else

                throw ArgumentError.new( "invalid block arity" )

            end

        end

        alias_method :push, :add

        def delete_if( &block )

            if block.arity == 1

                @hash.delete_if do |key, value|

                    block.call( key )

                end

            elsif block.arity == 2

                @hash.delete_if do |key, value|

                    block.call( key, value )

                end

            else

                throw ArgumentError.new( "invalid block arity" )

            end

        end

        def empty?

            @hash.empty?

        end

        def sub( source, destination )
            if has?( source )
                add( destination, count( source ) )
                remove_all( source )
            end
        end

    end

    class Set < Multiset

        def add( element, how_many = 1 )

            @hash[ element ] = 1

        end

    end

end