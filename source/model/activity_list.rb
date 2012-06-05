# encoding: utf-8

module MeDoList
  module Model

    class ActivityList
      def initialize( db, task )
        @db = db
        @task = task
        @items = []
        @ids = @db.execute "select id from timeslices where task_id=#{@task.id}"
        @ids.map! { |row| row[0] }
      end

      def count
        @ids.count
      end

      def each
        @ids.count.times do |index|
          if @items[index].nil?
            data = @db.get_first_row "select id,task_id,start,stop,comment from timeslices where id=#{@ids[index]}"
            @items[index] = Activity.new @task, data
          end

          yield @items[index]
        end
      end

      def to_a
        a = []
        each { |act| a << act }
        a
      end
    end

  end
end
