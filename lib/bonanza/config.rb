# frozen_string_literal: true

module Bonanza
  class Config

    attr_reader :config, :default_config, :user_config, :options

    def initialize(repo_path, options = {})
      Bonanza.log_verbose "Initializing config"

      @config_path = File.join(repo_path.to_s, ".bonanza.yml")
      @options = options

      load_default_config
      load_user_config
      apply_defaults_and_overrides

      Bonanza.log_verbose("Config set: #{config}")

      validate_config
    end

  private

    def load_default_config
      @default_config = YAML.load_file("config/defaults.yml")
    end

    def load_user_config
      unless File.exist?(@config_path)
        raise Error, "Must specify a valid path as first argument, provided: #{@config_path}"
      end

      @user_config = YAML.load_file(@config_path)
    end

    def apply_defaults_and_overrides
      @config = @default_config.merge(user_config).merge(@options)
    end

    def validate_config
      if @config["gh_handle"].empty?
        raise Error, "Config: Must supply gh_handle"
      end
    end

    # Friendly lookup of config keys
    def method_missing(method_name, *args, &block)
      if config && config.key?(method_name.to_s)
        config[method_name.to_s]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      (config && config.key?(method_name.to_s)) || super
    end
  end
end
