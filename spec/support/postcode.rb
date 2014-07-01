class Postcode
  attr_accessor :code
  include Neomirror::Node

  self.neo_primary_key = :code

  mirror_neo_node
end
