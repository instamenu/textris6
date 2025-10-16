module Textris
  class MessageDelivery
    def initialize(texter, action, *args)
      @texter = texter
      @action = action
      @args   = args
    end

    # Lazily build the message
    def message
      @message ||= @texter.new(@action, *@args).call_action
    end

    # Common delivery API
    def deliver
      message.deliver
    end

    def deliver_now(*opts)
      if message.respond_to?(:deliver_now)
        message.deliver_now(*opts)
      else
        message.deliver
      end
    end

    def deliver_later(*opts)
      options = opts.first.is_a?(Hash) ? opts.first : {}

      # Prefer ActiveJob-backed job if available
      if defined?(Textris::Delay::ActiveJob::Job)
        job = Textris::Delay::ActiveJob::Job
        job.new(@texter.to_s, @action.to_s, @args || []).enqueue(options)
        return
      end

      # Fallback to Sidekiq worker if available
      if defined?(Textris::Delay::Sidekiq::Worker)
        serialized_args = if defined?(Textris::Delay::Sidekiq::Serializer)
                            Textris::Delay::Sidekiq::Serializer.serialize(@args || [])
                          else
                            @args || []
                          end
        Textris::Delay::Sidekiq::Worker.perform_async(@texter.to_s, @action.to_s, serialized_args)
        return
      end

      # No async backend — raise to match previous ActionMailer-style behavior
      raise(LoadError, "ActiveJob/Delay backend not available to deliver later")
    end

    # Forward any other calls to the underlying message (e.g. :to, :content)
    def method_missing(name, *args, &block)
      message.public_send(name, *args, &block)
    end

    def respond_to_missing?(name, include_private = false)
      message.respond_to?(name, include_private) || super
    end
  end
end