module Textris
  module Delay
    module ActiveJob
      class Job < ::ActiveJob::Base
        queue_as :textris

        # Resolve GlobalID-style payloads back to AR objects, recursively
        def locate_global(arg)
          case arg
          when Hash
            if arg.key?('_aj_globalid')
              GlobalID::Locator.locate(arg['_aj_globalid'])
            else
              arg.transform_values { |v| locate_global(v) }
            end
          when Array
            arg.map { |a| locate_global(a) }
          else
            arg
          end
        end

        def perform(texter, action, args)
          texter_class = texter.safe_constantize
          return unless texter_class

          # The adapter passes args as an Array (or a single payload). Normalize.
          normalized_args =
            if args.is_a?(Array)
              locate_global(args)
            else
              locate_global([args])
            end

          # Call the texter class method as callers do (UserTexter.dashboard_message(...))
          result = texter_class.send(action, *(normalized_args || []))

          # If the texter returned a delivery/message, trigger immediate delivery.
          if result.respond_to?(:deliver_now)
            result.deliver_now
          elsif result.respond_to?(:deliver)
            result.deliver
          else
            # nothing to deliver (texter may have already created DB record and not returned a delivery)
            Rails.logger.info("[Textris::Delay::ActiveJob::Job] texter returned no delivery for #{texter}##{action}")
          end
        rescue StandardError => e
          Rails.logger.error("[Textris::Delay::ActiveJob::Job] failed: #{e.class} #{e.message}")
          raise
        end
      end
    end
  end
end
