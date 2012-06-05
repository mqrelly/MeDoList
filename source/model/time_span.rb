# encoding: utf-8

module MeDoList
  module Model

    class TimeSpan
      def initialize( seconds )
        @secs = seconds
      end

      def self.from_seconds( seconds )
        TimeSpan.new seconds
      end

      def total_sec
        @secs
      end

      def sec
        @secs.to_i % 60
      end

      def total_min
        @secs.to_i / 60
      end

      def min
        total_min % 60
      end

      def total_hour
        total_min / 60
      end

      def hour
        total_hour % 24
      end

      def total_day
        total_hour / 24
      end

      def to_s( long=false )
        if total_sec == 0
          "-"
        elsif total_sec < 60
          "#{total_sec.to_i}s"
        else
          if long
            "#{total_hour}:#{min.to_s.rjust 2, "0"}:#{sec.to_s.rjust 2, "0"}"
          else
            "#{total_hour}:#{min.to_s.rjust 2, "0"}"
          end
        end
      end
    end

  end
end
