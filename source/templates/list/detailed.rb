# encoding: utf-8

class Template
  def format( out, tasks, filters )
    tasks.each do |task|
      TemplateFormatter.format "task/detailed", out, task
    end

    case tasks.count
    when 0 then out.puts "No tasks."
    when 1 then out.puts "1 task."
    else out.puts "#{tasks.count} tasks."
    end
  end
end
