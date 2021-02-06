+++
title = "Mongoid Use Objectid as Created At"
date = "2013-08-23"
slug = "2013/08/23/mongoid-use-objectid-as-created-at"
Categories = ["mongodb", "rails", "mongoid"]
+++

date = "Nov"
slug = "Nov/mongoid-use-objectid-as-created-at"

One great feature of Mongodb is, that the first bytes of each ObjectID contains the time, they were generated.
This can be exploited to mimic the well known `created_at` field in rails.
First put this file in your lib directory.


```ruby
#lib/mongoid/created.rb
module Mongoid
  module CreatedAt
    # Returns the creation time calculated from ObjectID
    #
    # @return [ Date ] the creation time
    def created_at
      id.generation_time
    end

    # Set generation time of ObjectId.
    # Note: This will modify the ObjectId and
    # is therefor only useful for not persisted documents
    #
    # @return [ BSON::ObjectId ] the generated object id
    def created_at=(date)
      self.id = BSON::ObjectId.from_time(date)
    end
  end
end
```

If you are still using mongoid 3 replace `BSON::ObjectId` with `Moped::BSON::ObjectId`.

Now you can include this module in every Model, where you need created at.

```ruby
#app/models/user.rb
class User
  include Mongoid::Document
  include Mongoid::CreatedAt
# ...
end
u = User.new(created_at: 1.hour.ago)
u.created_at
```

That's all easy enough, isn't it?
