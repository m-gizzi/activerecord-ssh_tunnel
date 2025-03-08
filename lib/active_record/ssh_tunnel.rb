require "active_record/ssh_tunnel/version"
require "net/ssh/gateway"
require "rails/railtie"

module ActiveRecord
  module SshTunnel
    class Railtie < ::Rails::Railtie
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.singleton_class.prepend ::ActiveRecord::SshTunnel
      end
    end

    def establish_connection(spec = nil)
      spec ||= ConnectionHandling::DEFAULT_ENV.call.to_sym
      if ActiveRecord::VERSION::MAJOR >= 6 && ActiveRecord::VERSION::MINOR >= 1
        spec = ActiveRecord::Base.configurations.resolve(spec)
      else
        resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new configurations
        spec = resolver.spec(spec)
      end

      config = if ActiveRecord::VERSION::MAJOR >= 6 && ActiveRecord::VERSION::MINOR >= 1
        spec.configuration_hash.deep_dup
      else
        spec.config
      end

      if config[:ssh_tunnel_hostname]
        ssh_options = Hash[config.keys.select { |key|
          key.to_s.start_with? "ssh_tunnel_"
        }.map{ |key|
          [key.to_s.gsub("ssh_tunnel_", "").to_sym, config[key]]
        }]

        port = Net::SSH::Gateway.new(
          ssh_options.delete(:hostname),
          ssh_options.delete(:user),
          ssh_options,
        ).open(config[:host], config[:port])

        config[:host] = "127.0.0.1"
        config[:port] = port
      end

      remove_connection
      if ActiveRecord::VERSION::MAJOR >= 5
        connection_handler.establish_connection config
      else
        connection_handler.establish_connection self, spec
      end
    end
  end
end
