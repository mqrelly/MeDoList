# encoding: utf-8

module MeDoList

  class TemplateFormatter
    @@templates = Hash.new
    @@search_path = [
      File.join($MDL_USER_DIR, "templates"),
      File.join($MDL_BIN_DIR, "templates"),
    ]

    def self.format( template_name, out, *params )
      template = @@templates[template_name]
      if template.nil?
        template = TemplateFormatter.new template_name
        @@templates[template_name] = template
      end
      template.run out, *params
    end

    attr_accessor :name

    def initialize( template_name )
      @name = template_name

      # Locate template file
      file = nil
      @@search_path.each do |sp|
        file = File.join sp, @name + ".rb"
        if File.exists? file
          break
        else
          file = nil
        end
      end
      raise "Template not found '#{@name}'." if file.nil?

      # Load template code with proper namespacing to prevent name collision.
      ns = @name.split("/").map{ |m| m.capitalize }
      code = ns.map{|m| "module #{m}" }.join "\n"
      code << File.read(file)
      code << "end\n" * ns.count

      @binding = binding
      eval code, @binding
      @template = eval "#{ns.join "::"}::Template.new", @binding
    end

    def run( out, *params )
      @template.format out, *params
    end
  end

end
