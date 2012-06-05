# encoding: utf-8
require "yaml"
require "fileutils"

module MeDoList

  class UserConfig
    CONFIG_VERSION = 1

    def initialize( user_dir )
      @user_dir = user_dir
      FileUtils.mkdir_p File.join @user_dir, "templates", "list"
      FileUtils.mkdir_p File.join @user_dir, "templates", "task"
      FileUtils.mkdir_p File.join @user_dir, "templates", "activity"
      config_file = File.join @user_dir, "confing.yaml"
      if File.exists? config_file
        @conf = YAML.load(File.read config_file)

        # Check config version
        # TODO: Maybe convert old config formats?
        raise "Incompatible config file." if @conf["version"] > CONFIG_VERSION
      else
        @conf = { "version" => CONFIG_VERSION }
        # No defualts yet

        File.open(config_file,"w+") do |f|
          f.write @conf.to_yaml
        end
      end
    end

    def get
      @conf
    end
  end

end
