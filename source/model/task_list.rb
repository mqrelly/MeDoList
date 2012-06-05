# encoding: utf-8

module MeDoList
  module Model

    class TaskList
      def initialize( db, res )
        @db = db
        @res = res
      end

      def count
        @res.count
      end

      def each
        @res.each do |row|
          yield Task.new @db, row
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
          flt = TimeUtils.process_time_intervall_args args
          flt[:action] = action
          flt[:filter] = :deadline
          flt

        when "last-changed"
          flt = TimeUtils.process_time_intervall_args args
          flt[:action] = action
          flt[:filter] = :changed
          flt

        when "activity"
          flt = TimeUtils.process_time_intervall_args args
          flt[:action] = action
          flt[:filter] = :activity
          flt

        when "last-referenced"
          raise "Missing <max-ref-number> argument." if args.size < 1
          max_ref_num = Integer(args.shift.strip)
          {
            :action => action,
            :filter => :last_referenced,
            :max_ref_num => max_ref_num,
          }

        else
          raise "Filter argument '#{filter}' not recognized."
        end
      end

      def self.list( db, filters )
        q = "1==1"
        now = Time.now.utc
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

          when :activity
            subq = "select distinct task_id from timeslices where "
            case f[:type]
            when :before
              subq << "start <= #{f[:time_ref].to_i}"

            when :after
              subq << "(stop >= #{f[:time_ref].to_i}) "<<
                "or (stop is null and #{now.to_i} >= #{f[:time_ref].to_i})"

            when :in
              subq << "((stop is null and #{now.to_i} >= #{f[:from].to_i} or "<<
                "stop >= #{f[:from].to_i}) "<<
                "and start <= #{f[:to].to_i})"

            else
              raise "Don't know how to do '#{f[:type].inspect}'!"
            end
            task_ids = []
            res = db.execute subq
            res.each do |row|
              task_ids << row[0]
            end
            q << "id in (#{task_ids.join ","})"


          when :changed
            case f[:type]
            when :before
              q << "last_changed <= #{f[:time_ref].to_i}"

            when :after
              q << "last_changed >= #{f[:time_ref].to_i}"

            when :in
              q << "(last_changed >= #{f[:from].to_i} "<<
                "and last_changed <= #{f[:to].to_i})"

            else
              raise "Don't know how to do '#{f[:type].inspect}'!"
            end

          when :last_referenced
            task_ids = []
            res = db.execute "select distinct task_id from last_ref_tasks"<<
              " where ref_num <= #{f[:max_ref_num]}"
            res.each do |row|
              task_ids << row[0]
            end
            q << "id in (#{task_ids.join ","})"

          else
            raise "Don't know how to do #{f[:filter].inspect}!"
          end

          q << ")"
        end

        db.execute "select id,name,status,running_slice_id,deadline from tasks where #{q}"
      end
    end

  end
end
