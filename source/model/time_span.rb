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
        @secs % 60
      end

      def total_min
        @secs / 60
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

      def to_s
        if total_sec < 60
          "#{total_sec}s"
        else
          "#{total_hour}:#{min.to_s.rjust 2, "0"}"
        end
      end
    end

  end
end
