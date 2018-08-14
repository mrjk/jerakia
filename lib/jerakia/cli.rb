require 'thor'
require 'jerakia'
require 'json'
require 'yaml'
require 'jerakia/cli/server'
require 'jerakia/cli/token'
require 'jerakia/cli/lookup'
require 'jerakia/cli/secret'
require 'jerakia/cli/config'

class Jerakia
  class CLI < Thor

    # Add shared options class
    # Source: https://stackoverflow.com/questions/14346285/how-to-make-two-thor-tasks-share-options
    class << self
      def add_shared_option(name, options = {})
        @shared_options = {} if @shared_options.nil?
        @shared_options[name] =  options
      end

      def shared_options(*option_names)
        option_names.each do |option_name|
          opt =  @shared_options[option_name]
          raise "Tried to access shared option '#{option_name}' but it was not previously defined" if opt.nil?
          option option_name, opt
        end
      end
    end

    # Declare shared options
    add_shared_option :config,
                 aliases: :c,
                 type: :string,
                 desc: 'Configuration file'
    add_shared_option :verbose,
                 aliases: :v,
                 type: :boolean,
                 desc: 'Print verbose information'
    add_shared_option :debug,
                 aliases: :D,
                 type: :boolean,
                 desc: 'Debug information to console, implies --log-level debug'
    add_shared_option :trace,
                 type: :boolean,
                 desc: 'Output stacktrace to stdout'
    add_shared_option :log_level,
                 aliases: :l,
                 type: :string,
                 desc: 'Log level'

    # Include other arguments of CLI
    include Jerakia::CLI::Server
    include Jerakia::CLI::Lookup
    include Jerakia::CLI::Token
    include Jerakia::CLI::Secret
    include Jerakia::CLI::Config

    # Simple CLI arguments
    desc 'version', 'Version information'
    shared_options :config, :log_level, :verbose, :debug, :trace
    def version
      puts Jerakia::VERSION
    end

  end
end
