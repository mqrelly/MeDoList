# encoding: utf-8

module MeDoList
  module Model

    class TagList
      def initialize( db, task )
        @db = db
        @task = task
        @items = []
        @ids = @db.execute("select tag_id from tasks_and_tags where task_id=#{@task.id}")
        @ids.map! { |row| row[0] }
      end

      def count
        @ids.count
      end

      def each
        @ids.count.times do |index|
          if @items[index].nil?
            data = @db.get_first_row "select id,name from tags where id=#{@ids[index]}"
            @items[index] = Tag.new data
          end

          yield @items[index]
        end
      end

      def to_a
        a = []
        each { |t| a << t }
        a
      end
    end

  end
end
