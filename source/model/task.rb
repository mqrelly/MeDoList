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

      def self.process_filter_args( action, args )
        raise "Missing filter argument." if args.size < 1
        filter = args.shift
        case filter
        when "all"
          {:action => action, :filter => :all}

        when "name"
          raise "Missing <name-pattern> argument." if args.size < 1
          {
            :action => action, 
            :filter => :name, 
            :pattern => args.shift
          }

        when "running"
          {:action => action, :filter => :running}

        when /active|suspended|done|canceled/
          {
            :action => action, 
            :filter => :status, 
            :status => Model.status_code(filter)
          }

        when "tag"
          raise "Missing <tag-list> argument." if args.size < 1
          {
            :action => action,
            :filter => :tag,
            :tags => Model::Tag.list_to_names(args.shift)
          }

        when "deadline"
          dl = process_time_intervall_args args
          dl[:action] = action
          dl[:filter] = :deadline
          dl

        else
          raise "Filter argument '#{filter}' not recognized."
        end
      end

      def self.list( db, filters )
        q = "1==1"
        filters.each do |f|
          case f[:action]
          when :include then q << "\nOR ("
          when :exclude then q = "(#{q})\nAND NOT ("
          when :filter then q = "(#{q})\nAND ("
          else raise "Don't know how to do #{f[:action].inspect}!"
          end

          case f[:filter]
          when :all
            q << "1==1"

          when :name
            q << "name like #{f[:pattern]}"

          when :running
            q << "running_slice_id not null"

          when :status
            q << "status = #{f[:status]}"

          when :tag
            tag_ids = Model::Tag.names_to_ids db, f[:tags]
            q << tag_ids.map do |tag_id|
              "(id in (select task_id from tasks_and_tags "<<
              "where tag_id=#{tag_id}))"
            end.join(" AND ")

          when :deadline
            case f[:type]
            when :before
              q << "deadline <= #{f[:time_ref].to_i}"

            when :after
              q << "deadline >= #{f[:time_ref].to_i}"

            when :in
              q << "(deadline >= #{f[:from].to_i} "<<
                "and deadline <= #{f[:to].to_i})"

            else
              raise "Don't know how to do '#{f[:type].inspect}'!"
            end

          else
            raise "Don't know how to do #{f[:filter].inspect}!"
          end

          q << ")"
        end

        db.execute "select id,name,status,running_slice_id from tasks where #{q}"
      end
    end

  end
end
