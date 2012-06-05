# encoding: utf-8

class Template
  TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

  def format( out, activity )
    out.write "    "
    out.write activity.start.strftime TIME_FORMAT
    out.write " - "
    if activity.running?
      out.write "still running      "
    else
      out.write activity.stop.strftime TIME_FORMAT
    end
    out.write activity.elapsed.to_s(true).rjust 34
    if activity.comment
      out.puts
      out.write "     "
      out.write activity.comment.length > 74 ?
        activity.comment[0..74] : activity.comment
    end
    out.puts
  end
end
