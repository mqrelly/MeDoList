# encoding: utf-8

module MeDoList
  module Model

    class Tag
      def self.list_to_names( name_list )
        name_list.split(",").map{|t| t.strip}.
          select{|t| t && t!=""}
      end

      def self.get_or_create( db, name )
        tag_id = db.get_first_value "select id from tags "<<
          "where name='#{name}'"
        unless tag_id
          db.execute "insert into tags (name) values('#{name}')"
          tag_id = db.last_insert_row_id
        end
        tag_id
      end

      def self.tag_task( db, task_id, tag_id )
        db.execute "insert into tasks_and_tags (task_id,tag_id) "<<
          "values(#{task_id},#{tag_id})"
      rescue SQLite3::ConstraintException
        # Tag already assigned to task.
      end
    end

  end
end
