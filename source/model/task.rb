# encoding: utf-8

module MeDoList
  module Model

    class Task
      def self.lookup_task_ref( db, task_ref )
        case task_ref
        when /(#|\^)\d+/
          task_id = task_ref[1..task_ref.length-1].to_i
          task_count_with_id = db.get_first_value "select count(id) from tasks where id=#{task_id}"
          raise "Task ##{task_id} not found." if task_count_with_id == 0

        when /(#|\^)~\d*/
          if task_ref.length == 2
            ref_num = 1
        else
          ref_num = task_ref[2..task_ref.length-1].to_i
        end
        task_id = LastReferencedTasks.get db, ref_num
        raise "Last task reference ~#{ref_num} not found." unless task_id

        else
          # TODO: sanitize task_ref before!
          task_cnt_with_name = db.get_first_value "select count(id) from tasks where name='#{task_ref}'"
          if task_cnt_with_name == 0
            raise "Task '#{task_ref}' not found."
          elsif task_cnt_with_name > 1
            raise "More then one task are called '#{task_ref}'."
          end
          task_id = db.get_first_value "select id from tasks where name='#{task_ref}'"
        end
        task_id
      end

      def self.get_running_slice_id( db, task_id )
        db.get_first_value "select running_slice_id from tasks "<<
        "where id=#{task_id}"
      end

      def self.start( db, task_id )
        # Check if running
        raise "Task alredy running." if get_running_slice_id(db,task_id)

        # Create Timeslice if not running
        start_time = Time.now
        db.execute "insert into timeslices (task_id,start) "<<
        "values(#{task_id},#{start_time.to_i})"
        slice_id = db.last_insert_row_id

        # Update task.running_slice_id
        db.execute "update tasks set running_slice_id=#{slice_id} "<<
        "where id=#{task_id}"

        # Update task.last_changed
        update_last_changed db, task_id, start_time

        slice_id
      end

      def self.stop( db, task_id )
        # Get running timeslice
        running_slice_id = get_running_slice_id db, task_id
        raise "Running timeslice not found." unless running_slice_id

        stop_time = Time.now

        # Update timeslice
        db.execute "update timeslices set stop=#{stop_time.to_i}"<<
        " where id=#{running_slice_id}"

        # Clear ref to runnning timeslice
        db.execute "update tasks set running_slice_id=NULL"<<
        " where id=#{task_id}"

        # Update task.last_changed
        update_last_changed db, task_id, stop_time

        true
      end

      def self.set_status( db, task_id, status_code )
        db.execute "update tasks set status=#{status_code}"<<
        " where id=#{task_id}"

        raise "Failed to set task.status." if db.changes != 1

        update_last_changed db, task_id
      end

      def self.update_last_changed( db, task_id, changed_time=Time.now )
        db.execute "update tasks set last_changed=#{changed_time.to_i}"<<
        " where id=#{task_id}"

        raise "Failed to update task.last_changed." if db.changes != 1
        true
      end

      def self.get_running_time( db, task_id )
        running_slice_id = get_running_slice_id db, task_id
        return nil if running_slice_id.nil?

        start_time = db.get_first_value "select start from timeslices"<<
        " where id=#{running_slice_id}"
        now = Time.now.to_i

        now - start_time
      end

      def self.get_total_time( db, task_id )
        res = db.execute "select (stop-start),start from timeslices"<<
        " where task_id=#{task_id}"
        total_time = 0
        now = Time.now.to_i
        res.each do |row|
          time = row[0] ? row[0] : now - row[1]
          total_time += time
        end
        total_time
      end

      def self.set_deadline( db, task_id, deadline )
        if deadline.nil?
          deadline="NULL"
        else
          deadline = deadline.to_i
        end

        db.execute "update tasks set deadline=#{deadline} where id=#{task_id}"
        raise "Failed to update deadline!" if db.changes == 0

        update_last_changed db, task_id
      end

      def initialize( db, row )
        @db = db
        @id,@name,@status,@running_activity_id,@deadline = *row
        @deadline = Time.at @deadline if @deadline
      end

      attr_accessor :id, :name, :status, :deadline

      def running_activity
        if @running_activity.nil? && @running_activity_id
          data = @db.get_first_row "select id,task_id,start,stop,comment from timeslices where id=#{@running_activity_id}"
          @running_activity = Activity.new self, data
        end
        @running_activity
      end

      def activities
        @activities ||= ActivityList.new @db, self
      end

      def tags
        @tags ||= TagList.new @db, self
      end
    end

  end
end
