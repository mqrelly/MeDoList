# encoding: utf-8

require "sqlite3"

$MDL_SCHEMA_VERSION = "1"


module MeDoList
  module Model
    def self.open( db_file )
      db = SQLite3::Database.new db_file

      # Check mdl schema version
      begin
        version = db.get_first_value "select value from mdl_settings where name='version'"
      rescue
        version = nil
      end

      if version.nil?
        # Create tables
        db.execute <<-SQL
          create table mdl_settings (
            name text not null primary key,
            value text)
SQL
        db.execute <<-SQL
          create table tags (
            id integer not null primary key autoincrement,
            name text not null unique)
SQL
        db.execute <<-SQL
          create table tasks (
            id integer not null primary key autoincrement,
            name text not null,
            status int not null default 0,
            last_changed datetime not null,
            deadline datetime)
SQL
        db.execute <<-SQL
          create table tasks_and_tags (
            task_id int not null,
            tag_id int not null,
            primary key (task_id,tag_id))
SQL
        db.execute <<-SQL
          create table timeslices (
            id integer not null primary key autoincrement,
            task_id int not null,
            start integer not null,
            stop integer default null,
            comment text)
SQL
        # Create indices to speed up frequent queries
        # TODO

        db.execute <<-SQL
          insert into mdl_settings values(
            'version', '#{$MDL_SCHEMA_VERSION}')
SQL
      elsif version != $MDL_SCHEMA_VERSION
        raise "Incompatible MDL Schema version."
        #TODO: use custom Exception!
      end

      db
    end

    def self.status_name( status )
      case status
      when 0 then "active"
      when 1 then "suspended"
      when 2 then "done"
      when 3 then "canceled"
      else raise ArgumentError, "Invalid status code '#{status}'."
      end
    end

    def self.status_code( status )
      case status
      when "active" then 0
      when "suspended" then 1
      when "done" then 2
      when "canceled" then 3
      else raise ArgumentError, "Invalid status name '#{status}'."
      end
    end

    def self.tag_name_list( arg )
      arg.split(",").map{|t| t.strip.downcase}.select{|t| t && t!=""}
    end

    def self.get_or_create_tag( db, name )
      tag_id = db.get_first_value "select id from tags where name='#{name}'"
      unless tag_id
        db.execute "insert into tags (name) values('#{name}')"
        tag_id = db.last_insert_row_id
      end
      tag_id
    end

    def self.tag_task( db, task_id, tag_id )
      db.execute "insert into tasks_and_tags (task_id,tag_id) " <<
        "values(#{task_id},#{tag_id})"
    rescue => er
      puts er.to_s
    end

    def self.lookup_task_ref( db, task_ref )
      case task_ref
      when /#\d+/
        task_id = task_ref[1..task_ref.length-1].to_i
        task_count_with_id = db.get_first_value "select count(id) from tasks where id=#{task_id}"
        raise "Task ##{task_id} not found." if task_count_with_id == 0

      when /~\d*/
        # TODO

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
  end
end
