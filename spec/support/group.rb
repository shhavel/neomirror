class Group < ActiveRecord::Base
  include Neomirror::Node
  has_many :memberships
  has_many :premises, through: :memberships
  has_many :staff
  has_many :users, through: :staff

  mirror_neo_node
end
