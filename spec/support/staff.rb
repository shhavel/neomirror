ActiveSupport::Inflector.inflections do |inflect|
  inflect.uncountable 'staff', 'staff'
end

class Staff < ActiveRecord::Base
  include Neomirror::Relationship
  belongs_to :user
  belongs_to :premises
  belongs_to :group
  serialize :roles, Array

  mirror_neo_relationship start_node: :user, end_node: :premises, type: :STAFF_OF do
    property :roles, ->(record) { record.roles.to_a }
  end
  mirror_neo_relationship start_node: :user, end_node: :group, type: :STAFF_OF do
    property :roles
  end

  mirror_neo_relationship start_node: :user, end_node: :premises, type: :MANAGER_OF, if: ->(r) { r.roles.include?('manager') }
  mirror_neo_relationship start_node: :user, end_node: :premises, type: :VISITOR_OF, if: ->(r) { r.roles.include?('visitor') }
end
