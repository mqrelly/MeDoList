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

      def self.update_last_changed( db, task_id, changed_time=Time.now )
        db.execute "update tasks set last_changed=#{changed_time.to_i}"<<
          " where id=#{task_id}"
        raise "Failed to update task.last_changed." if db.changes == 0
      end
    end

  end
end
