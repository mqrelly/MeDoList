# encoding: utf-8

module MeDoList
  module Model

    class TimeUtils
      def self.process_time_intervall_args( args )
        raise "Missing <time-intervall> argument." if args.size < 1
        type = args.shift.strip
        case type
        when /before|after/
          raise "Missing <time-ref> argument." if args.size < 1
          time_ref_arg = args.shift
          time_ref = Chronic.parse time_ref_arg
          raise "Unrecognized <time-ref> '#{time_ref_arg}'." if time_ref.nil?
          {
            :type => type.to_sym,
            :time_ref => time_ref,
          }

        when "in"
          raise "Missing from <time-ref> argument." if args.size < 1
          raise "Missing to <time-ref> argument." if args.size < 2
          from_arg = args.shift
          from_time_ref = Chronic.parse from_arg
          raise "Unknown <time-ref> '#{from_arg}'." if from_time_ref.nil?
          to_arg = args.shift
          to_time_ref = Chronic.parse to_arg
          raise "Unknown <time-ref> '#{to_arg}'." if to_time_ref.nil?
          {
            :type => :in,
            :from => from_time_ref,
            :to => to_time_ref,
          }

        else
          raise "Unknown time-intervall type '#{type}'."
        end
      end
    end

  end
end
