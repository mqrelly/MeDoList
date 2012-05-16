# encoding: utf-8

$MDL_SCHEMA_VERSION = "1"

require "sqlite3"
require File.join $MDL_ROOT, "model", "tag.rb"
require File.join $MDL_ROOT, "model", "task.rb"
require File.join $MDL_ROOT, "model", "last_ref_tasks.rb"


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
            name text collate nocase not null unique)
SQL
        db.execute <<-SQL
          create table tasks (
            id integer not null primary key autoincrement,
            name text not null,
            status int not null default 0,
            last_changed integer not null,
            running_slice_id integer,
            deadline integer)
SQL
        db.execute <<-SQL
          create table last_ref_tasks (
            ref_num integer not null primary key,
            task_id integer not null)
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
  end
end
