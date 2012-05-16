# encoding: utf-8

module MeDoList
  module Model

    class LastReferencedTasks
      def self.get( db, ref_num=1 )
        db.get_first_value "select task_id from last_ref_tasks"<<
          " where ref_num=#{ref_num}"
      end

      def self.get_max_ref_num( db )
        db.get_first_value "select max(ref_num) from last_ref_tasks"
      end

      def self.limit( db, limit )
        db.execute "delete from last_ref_tasks" <<
          " where ref_num>#{limit}"
      end

      def self.put( db, task_id )
        # Increment ref_nums
        max_ref_num = get_max_ref_num db
        if max_ref_num
          max_ref_num.downto(1) do |ref_num|
            db.execute "update last_ref_tasks set ref_num=(ref_num+1)"<<
              " where ref_num=#{ref_num}"
          end
        end

        # Insert task_ref to the first place
        db.execute "insert into last_ref_tasks (ref_num,task_id)"<<
          " values(1,#{task_id})"
      end

      def self.list( db, limit=nil )
        q = "select * from last_ref_tasks"
        q << " limit #{limit}" if limit
        res = db.execute q

        if block_given?
          res.each do |row|
            yield row[0], row[1]
          end
        else
          a = []
          res.each do |row|
            a << [row[0], row[1]]
          end
          a
        end
      end
    end

  end
end
