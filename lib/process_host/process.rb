module ProcessHost
  class Process
    include Logging

    attr_reader :client
    attr_reader :child_fiber
    attr_reader :host_fiber
    attr_reader :name

    def initialize client, name = nil
      @client = client
      @name = name || client.class.name
      @host_fiber = Fiber.current
    end

    def start
      @child_fiber = Fiber.new do
        start_client
      end
    end

    def start_client
      invoke_client do
        client.start io_wrapper
      end
    end

    def resume
      unless Fiber.current == host_fiber
        fail "not in host fiber"
      end

      return_value = io_wrapper.complete_pending_action
      logger.debug "Process #{name.inspect} finished action; returned #{return_value.inspect}"
      child_fiber.resume return_value
    end

    def io_wrapper
      @io_wrapper ||= IOWrapper.new host_fiber
    end

    def connect!
      invoke_client do
        begin
          client.connect io_wrapper
        rescue Errno::ECONNREFUSED
        end
      end
    end

    def pending_read?
      io_wrapper.pending_read?
    end

    def pending_write?
      io_wrapper.pending_write?
    end

    def socket
      connect! if io_wrapper.socket.closed?
      io_wrapper.socket
    end

    def invoke_client
      yield
    rescue => error
      crash = Crash.new client, error
      raise crash
    end

    class Crash < StandardError
      attr_reader :cause
      attr_reader :client

      def initialize client, original_error
        @client = client
        @cause = original_error
      end

      def to_s
        cause.to_s
      end

      def backtrace
        cause.backtrace
      end
    end
  end
end
