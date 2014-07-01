class Group < ActiveRecord::Base
  include Neomirror::Node
  include Neomirror::Relationship
  has_many :memberships
  has_many :staff
  belongs_to :parent, class_name: 'Group', foreign_key: :parent_id

  mirror_neo_node
  mirror_neo_relationship start_node: :self, end_node: :parent, type: :CHILD_OF
end
