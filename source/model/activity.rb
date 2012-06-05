# encoding: utf-8

module MeDoList
  module Model

    class Activity
      def initialize( task, data_row )
        @task=task
        @id,@task_id,@start,@stop,@comment = *data_row
        raise "Bad task" if @task.id != @task_id

        @start = Time.at @start
        @stop = Time.at @stop if @stop
      end

      attr_accessor :id, :task, :start, :comment

      def stop
        @stop || Time.now.utc
      end

      def running?
        @stop.nil?
      end

      def elapsed
        TimeSpan.new stop-start
      end
    end

  end
end
