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

      def self.process_filter_args( args )
        raise "Missing filter argument." if args.size < 1

        case args.first
        when "all"
          [:all]

        when "name"
          args.shift
          raise "Missing <name-pattern> argument." if args.size < 1
          [:name, args.first]

        when "running"
          [:running]

        when /active|suspended|done|canceled/
          [:status, Model.status_code(args.first)]

        when "tag"
          args.shift
          raise "Missing <tag-list> argument." if args.size < 1
          [:tag, Model::Tag.list_to_names(args.first)]

        else
          raise "Filter argument '#{args.first}' not recognized."
        end
      end

      def self.list( db, filters )
        q = "1==1"
        filters.each do |filter|
          case filter[0]
          when :include then q << "\nOR ("
          when :exclude then q = "(#{q})\nAND NOT ("
          when :filter then q = "(#{q})\nAND ("
          else raise "Don't know how to do #{filter[0].inspect}!"
          end

          case filter[1]
          when :all
            q << "1==1"

          when :name
            q << "name like #{filter[2]}"

          when :running
            q << "running_slice_id not null"

          when :status
            q << "status = #{filter[2]}"

          when :tag
            tag_ids = Model::Tag.names_to_ids db, filter[2]
            q << tag_ids.map do |tag_id|
              "(id in (select task_id from tasks_and_tags "<<
              "where tag_id=#{tag_id}))"
            end.join(" AND ")

          else
            raise "Don't know how to do #{filter[1].inspect}!"
          end

          q << ")"
        end

        db.execute "select id,name,status,running_slice_id from tasks where #{q}"
      end
    end

  end
end
