class Membership < ActiveRecord::Base
  include Neomirror::Relationship
  belongs_to :premises
  belongs_to :group

  mirror_neo_relationship start_node: :premises, end_node: :group, type: :MEMBER_OF
end
