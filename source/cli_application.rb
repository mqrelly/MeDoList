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

    def list( argv )
      db = Model.open $MDL_FILE
      res = db.execute "select id,name,status from tasks"
      res.each do |row|
        task_id = row[0]
        puts "\##{task_id.to_s.ljust 6} #{row[1]} #{Model.status_name row[2]}"
        tag_ids = db.execute "select tag_id from tasks_and_tags where task_id=#{task_id}"
        tag_ids.each do |tag_row|
          tag_name = db.get_first_value "select name from tags where id=#{tag_row[0]}"
          puts "  #{tag_name}"
        end

        running_slice_id = Model::Task.get_running_slice_id db, task_id
        if running_slice_id
          start_time = db.get_first_value "select start from timeslices"<<
            " where id=#{running_slice_id}"
          puts "  Running since #{Time.at start_time}"
        end
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
          raise "Missing tag-list for --tag option!" unless args.size > 0
          args.first.split(",").map(&strip)
        end

        option :mark, /^-m|--mark$/ do |args|
          args.shift
          raise "Missing status for --mark option!" unless args.size > 0
          status = args.first.strip
          raise "Unknown status '#{status}'!" unless status =~ /^active|suspended|done|canceled$/
          status
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
      # TODO

      # Mark new task
      # TODO

      # Start new task
      # TODO

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

    def refs( argv )
      # Process args
      opts = ArgsParser.new do
        option :limit, /^--limit|-l$/ do |args|
          raise "Missing limit number argument." if args.size == 1
          args.shift
          args.first.to_i
        end
      end.parse argv

      # List references
      db = Model.open $MDL_FILE
      Model::LastReferencedTasks.list(db,opts[:limit]) do |ref_num,task_id|
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
      puts "  Copyright by Márk Szabadkai (mqrelly@gmail.com)"
      # TODO: add license info, add github link
    end
  end

end
