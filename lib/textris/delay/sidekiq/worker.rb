module Textris
  module Delay
    module Sidekiq
      class Worker
        include ::Sidekiq::Worker

        def perform(texter, action, args)
          texter = texter.safe_constantize

          if texter.present?
            args = ::Textris::Delay::Sidekiq::Serializer.deserialize(args)

            # Build the delegator with the texter constant and action
            ::Textris::MessageDelivery.new(texter, action, *args).deliver_now
          end
        end
      end
    end
  end
end
