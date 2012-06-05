# encoding: utf-8

class Template
  def format( out, task )
    # Id and name
    out.puts "\##{task.id} - #{task.name}"

    # Status
    status =  Model.status_name(task.status).capitalize
    out.puts "  #{status}"

    # Deadline
    if task.deadline
      out.write "  Deadline at #{task.deadline.strftime "%Y-%m-%d %H:%M:%S"}"
      if task.deadline < Time.now.utc
        out.puts "  OVERDUE"
      else
        out.puts
      end
    end

    # Tags
    if task.tags.count > 0
      tags = task.tags.to_a.map { |t| t.name }
      out.puts "  [#{tags.join ","}]"
    end

    # Activities
    total_time = 0
    if task.activities.count > 0
      out.puts "  Activities:"
      task.activities.each do |act|
        total_time += act.stop - act.start
        TemplateFormatter.format "activity/detailed", out, act
      end
    else
      out.puts "  No activities"
    end

    if task.running_activity
      str = task.running_activity.elapsed.to_s(true)
      str << " / "
      str << Model::TimeSpan.from_seconds(total_time).to_s(true)
      out.puts "  Running #{str.rjust 69}"
    else
      str = Model::TimeSpan.from_seconds(total_time).to_s(true)
      out.puts "  Not running #{str.rjust 65}"
    end

    out.puts
  end
end
