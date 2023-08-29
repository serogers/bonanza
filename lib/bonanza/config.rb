# frozen_string_literal: true

module Bonanza
  class Config

    attr_reader :config

    def initialize(repo_path)
      @config_path = File.join(repo_path.to_s, ".bonanza.yml")

      load_config
      validate_config
    end

  private

    def load_config
      unless File.exist?(@config_path)
        raise Error, "Must specify a valid path as first argument, provided: #{@config_path}"
      end

      @config = YAML.load_file(@config_path)
    end

    def validate_config
      if @config["gh_handle"].empty?
        raise Error, "Config: Must supply gh_handle"
      end
    end
  end
end
