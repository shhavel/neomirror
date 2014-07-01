class User < ActiveRecord::Base
  include Neomirror::Node
  has_many :staff

  mirror_neo_node do
    property :name
  end
end
