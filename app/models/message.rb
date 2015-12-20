class Message < ActiveRecord::Base
  belongs_to :user
  include Searchable
end
