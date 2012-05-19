# encoding: utf-8

require File.join $MDL_ROOT, "args_parser.rb"


module MeDoList

  class CliApplication
    def self.run( argv )
      app = self.new(argv)
      cmd = argv.shift || :missing_command
      app.send cmd, argv
    end

    def initialize( argv )
      @globals = ArgsParser.new do
        option :verbose, /^-v|--verbose$/
        option :silent, /^-s|--silent$/
        option :dry_run, /^-n|--dry-run$/
        stop_on *%w(help version add start stop mark tag list refs)
      end.parse(argv)
    end

    def missing_command( argv )
      puts "Missing command."
      puts "  To list available commands use: mdl help"
      exit 1
    end

    def process_filter_args( filters, action, args )
      args.shift
      raise "Missing filter argument." if args.size < 1

      case args.first
      when "all"
        filters << [action, :all]

      when "name"
        args.shift
        raise "Missing <name-pattern> argument." if args.size < 1
        filters << [action, :name, args.first]

      when "running"
        filters << [action, :running]

      when /active|suspended|done|canceled/
        filters << [action, :status, Model.status_code(args.first)]

      when "tag"
        args.shift
        raise "Missing <tag-list> argument." if args.size < 1
        filters << [action, :tag, Model::Tag.list_to_names(args.first)]

      else
        raise "Filter argument '#{args.first}' not recognized."
      end
    end

    def list( argv )
      # Process arguments
      filters = []
      if argv.size > 0
        cli = self
        options = ArgsParser.new do
          option :format, /^--format$/ do |args|
            args.shift
            raise "Missing <list-format> option." if args.size < 1

            format = args.first.strip
            unless %w(oneline detailed).include? format
              raise "List format '#{format}' not recognized."
            end
            format
          end

          option :include, /^--include|-I$/ do |args|
            cli.process_filter_args filters, :include, args
          end

          option :exclude, /^--exclude|-X$/ do |args|
            cli.process_filter_args filters, :exclude, args
          end

          option :filter, /^--filter|-F$/ do |args|
            cli.process_filter_args filters, :filter, args
          end
        end.parse argv
      else
        options = {}
      end

      # Set default format to 'oneline'
      format = options[:format] || "oneline"

      # Query task infos
      db = Model.open $MDL_FILE
      q = "1==1"
      filters.each do |filter|
        case filter[0]
        when :include then q << "\nOR ("
        when :exclude then q = "(#{q})\nAND NOT ("
        when :filter then q << "\nAND ("
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

      res = db.execute "select id,name,status,running_slice_id from tasks where #{q}"

      if format == "oneline"
        res.each do |row|
          task_id = row[0]
          name = row[1]
          status_code = row[2]
          running_slice_id = row[3]

          status_sym = if running_slice_id
            "%"
          else
            case status_code
            when 0 then " "
            when 1 then "S"
            when 2 then "+"
            when 3 then "-"
            end
          end

          total_time = Model::Task.get_total_time db, task_id
          total_time_str = Model::TimeSpan.new(total_time).to_s

          if running_slice_id
            running_time = Model::Task.get_running_time db, task_id
            running_time_str = Model::TimeSpan.new(running_time).to_s
            running_time_str << "/"
          else
            running_time_str = ""
          end

          name_width = 78-10-running_time_str.length-total_time_str.length
          if name.length > name_width
            name = name[0,name_width-3] << "..."
          else
            name = name.ljust name_width
          end

          puts "#{status_sym} \##{task_id.to_s.ljust 6} #{name} #{running_time_str}#{total_time_str}"
        end
      else # detailed
        puts "TODO"
      end
    end

    def add( argv )
      # Get task-name
      raise "Missing task-name!" unless argv.size > 0
      task_name = argv.shift

      # Parse optional arguments
      options = ArgsParser.new do
        option :start, /^-S|--start$/

        option :tag, /^-t|--tag$/ do |args|
          args.shift
          raise "Missing <tag-list> for --tag option!" if args.size < 1
          args.first.split(",").map{|t| t.strip}
        end

        option :mark, /^-m|--mark$/ do |args|
          args.shift
          raise "Missing status for --mark option!" if args.size < 1
          Model::status_code args.first.strip
        end

        option :force, /^-f|--force$/
      end.parse(argv)

      # Open database
      db = Model.open $MDL_FILE
      db.transaction

      # Check for same named tasks
      unless options[:force]
        task_count_width_same_name = db.get_first_value "select count(id) from tasks where name=? and status in (0,1)", task_name
        if task_count_width_same_name > 0
          puts "There is already a task not fiished, and called '#{task_name}'."
          if @globals[:silent]
            puts "  To force create use: mdl add \"#{task_name}\" --force"
          end
          exit
        end
      end

      # Add new task
      change_time = Time.now
      db.execute "insert into tasks (name,last_changed)"<<
      " values('#{task_name}', #{change_time.to_i})"
      task_id = db.last_insert_row_id

      # Tag new task
      if options[:tag]
        # Process tag-list argument
        tag_names = options[:tag]
        tag_ids = tag_names.map {|tn| Model::Tag.get_or_create db, tn}

        # Add tags to the task
        tag_ids.each do |tag_id|
          Model::Tag.tag_task db, task_id, tag_id
        end
      end

      # Mark new task
      if options[:mark]
        status_code = options[:mark]
        Model::Task.set_status db, task_id, status_code
      end

      # Start new task
      if options[:start]
        Model::Task.start db, task_id
      end

      # Save LRT
      Model::LastReferencedTasks.put db, task_id
    rescue
      db.rollback if db && !db.closed?
      raise
    else
      db.commit
    end

    def tag( argv )
      db = Model.open $MDL_FILE
      db.transaction

      # Process task-reference
      raise "Missing <task-ref> argument!" unless argv.size > 0
      task_ref = argv.shift.strip
      task_id = Model::Task.lookup_task_ref db, task_ref

      # Process tag-list argument
      raise "Missing <tag-list> argument!" unless argv.size > 0
      tag_names = Model::Tag.list_to_names argv.shift
      tag_ids = tag_names.map {|tn| Model::Tag.get_or_create db, tn}

      # Check for unprocessed args
      raise "Unknown argument: #{argv.first}" if argv.size > 0

      # Add tags to the task
      tag_ids.each do |tag_id|
        Model::Tag.tag_task db, task_id, tag_id
      end

      # Save LRT
      Model::LastReferencedTasks.put db, task_id
    rescue
      db.rollback if db && !db.closed?
      raise
    else
      db.commit
    end

    def start( argv )
      db = Model.open $MDL_FILE
      db.transaction

      # Parse <task-ref>
      raise "Missing <task-ref> argument!" if argv.size == 0
      task_ref = argv.shift
      task_id = Model::Task.lookup_task_ref db, task_ref

      # Start task
      Model::Task.start db, task_id

      # Save LRT
      Model::LastReferencedTasks.put db, task_id
    rescue
      db.rollback if db && !db.closed?
      raise
    else
      db.commit
    end

    def stop( argv )
      raise "Missing argument for stop command." if argv.size < 1
      task_ref = argv.shift

      if task_ref == "--all"
        # Stop all runnung tasks
        db = Model.open $MDL_FILE
        db.transaction do |db|
          # Get all the running tasks
          task_ids = []
          res = db.execute "select id from tasks where running_slice_id > 0"
          res.each do |row|
            task_ids << row[0]
          end

          # Stop them one by one
          task_ids.each do |task_id|
            Model::Task.stop db, task_id
          end
        end
      else
        # Stop only the given one
        db = Model.open $MDL_FILE

        # Parse task_ref
        task_id = Model::Task.lookup_task_ref db, task_ref

        if argv.size > 0
          options = ArgsParser.new do
            option :mark, /^-m|--mark$/ do |args|
              args.shift
              raise "Missing status for --mark option." if args.size < 1
              Model.status_code args.first
            end
          end.parse argv
        else
          options = {}
        end

        db.transaction do |db|
          # Stop the task
          Model::Task.stop db, task_id

          # Change status
          if options[:mark]
            new_status = options[:mark]
            Model::Task.set_status db, task_id, new_status
          end

          # Save LRT
          Model::LastReferencedTasks.put db, task_id
        end
      end
    end

    def mark( argv )
      # Process args
      raise "Missing <task-ref> argument." if argv.size < 1
      raise "Missing <status> argument." if argv.size < 2
      raise "Unknown argument." if argv.size > 2

      db = Model.open $MDL_FILE

      # Lookup referenced task id
      task_ref = argv.shift.strip
      task_id = Model::Task.lookup_task_ref db, task_ref

      # Parse new status
      status_name = argv.shift.strip
      status_code = Model.status_code status_name

      # Check if status will finish the task and if it's running
      if status_code >= 2 && Model::Task.get_running_slice_id(db, task_id)
        raise "Task #{task_ref} is still running."
      end

      db.transaction do |db|
        # Change status
        Model::Task.set_status db, task_id, status_code

        # Save LRT
        Model::LastReferencedTasks.put db, task_id
      end
    end

    def refs( argv )
      # Process args
      options = ArgsParser.new do
        option :limit, /^--limit|-l$/ do |args|
          raise "Missing limit number argument." if args.size == 1
          args.shift
          args.first.to_i
        end
      end.parse argv

      # List references
      db = Model.open $MDL_FILE
      Model::LastReferencedTasks.list(db,options[:limit]) do |ref_num,task_id|
        puts "~#{ref_num.to_s.ljust 6} ##{task_id}"
      end
    end

    def help( argv )
      puts <<EOF
Usage: mdl [-s|--silent|-v|--verbose] [-n|--dry-run] <command> <command-args>

TODO:
- global options
- list commands
EOF
    end

    def version( argv )
      puts "mdl - MeDoList CLI Client in Ruby  #{$MDL_VERSION}"
      puts "Copyright by Márk Szabadkai (mqrelly@gmail.com)"
      puts "Homepage: http://github.com/mqrelly/MeDoList"
      # TODO: add license info
    end
  end

end
