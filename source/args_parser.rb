# encoding: utf-8

class ArgsParser
  def initialize( &setup )
    @options = {}
    @stop_on = []

    self.instance_eval &setup if setup

    self
  end

  def option( id, pattern, &filter )
    @options[id] = {
      :id => id,
      :pattern => pattern,
      :filter => filter,
    }
  end
def stop_on( *words )
    @stop_on = words
  end

  def handle_unrecognized( &handler )
    @handle_unrecognized = handler
  end

  def parse( args )
    options = {}
    while !args.empty? do
      arg = args[0]

      # Stop if one of the @stop_on args encountered
      break if @stop_on.include? arg

      recognized = false
      @options.values.each do |opt|
        if opt[:pattern].is_a?(String)
          next unless opt[:pattern] == arg
        else
          next unless opt[:pattern] =~ arg
        end

        if opt[:filter]
          options[opt[:id]] = opt[:filter].call(args)
        else
          options[opt[:id]] = true
          args.shift
        end
        recognized = true
        break
      end

      unless recognized
        if @handle_unrecognized
          @handle_unrecognized.call(args)
        else
          raise ArgumentError, "Argument '#{arg}' not recognized.", caller[1..-1]
        end
      end
    end
    options
  end
end
