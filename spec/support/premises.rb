class Premises < ActiveRecord::Base
  include Neomirror::Node
  has_many :memberships
  has_many :staff

  mirror_neo_node
end
