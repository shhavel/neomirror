class User < ActiveRecord::Base
  include Neomirror::Node
  has_many :staff
  has_many :premises, through: :staff
  has_many :groups,   through: :staff

  mirror_neo_node do
    property :name
  end
end
