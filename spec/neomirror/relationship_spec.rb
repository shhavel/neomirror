require "spec_helper"

describe Neomirror::Relationship do
  let(:premises) { create(:premises) }
  let(:group) { create(:group) }
  let(:membership) { create(:membership, premises: premises, group: group) }
  let(:user) { create(:user) }
  let(:staff_of_premises) { create(:staff, user: user, premises: premises) }
  let(:staff_of_group) { create(:staff, user: user, group: group) }
  let(:staff) { create(:staff, user: user, premises: premises, group: group) }
  let(:other_premises) { create(:premises) }

  describe "#find_neo_relationship" do
    it "searches neo4j relationship, returns Neography::Relationship instance" do
      membership.find_neo_relationship.should be_a Neography::Relationship
    end

    it "returns nil if there is no relationship in neo4j" do
      membership.destroy_neo_relationship
      membership.find_neo_relationship.should be_nil
    end
  end

  describe "#neo_relationship" do
    it "finds neo4j relationship if exists, returns Neography::Relationship instance" do
      membership.neo_relationship.should be_a Neography::Relationship
    end

    it "creates neo4j relationship if not exists, returns Neography::Relationship instance" do
      membership.destroy_neo_relationship
      membership.neo_relationship.should be_a Neography::Relationship
    end
  end

  describe "#create_neo_relationship" do
    before { membership.destroy_neo_relationship }

    it "creates neo4j relationship after record was created" do
      membership.create_neo_relationship
      membership.find_neo_relationship.should be_a Neography::Relationship
    end

    it "does not create neo4j relationship unless both nodes are present" do
      membership = create(:membership, premises: premises)
      membership.create_neo_relationship
      membership.find_neo_relationship.should be_nil
    end

    it "does not create neo4j relationship if condition returns false" do
      staff.create_neo_relationship(type: :VISITOR_OF)
      staff.find_neo_relationship(type: :VISITOR_OF).should be_a Neography::Relationship
      staff.create_neo_relationship(type: :MANAGER_OF)
      staff.find_neo_relationship(type: :MANAGER_OF).should be_nil
    end
  end

  describe "#create_neo_relationships" do
    it "creates multiple neo4j relationships after record was created" do
      staff.find_neo_relationship(end_node: :premises, type: :STAFF_OF).should be_a Neography::Relationship
      staff.find_neo_relationship(end_node: :group, type: :STAFF_OF).should be_a Neography::Relationship
    end

    it "creates multiple neo4j relationships for which both nodes exist" do
      staff_of_premises.find_neo_relationship(end_node: :premises, type: :STAFF_OF).should be_a Neography::Relationship
      staff_of_premises.find_neo_relationship(end_node: :group, type: :STAFF_OF).should be_nil
    end

    it "creates multiple optional neo4j relationships for which condition returns true after record was created" do
      staff.find_neo_relationship(type: :VISITOR_OF).should be_a Neography::Relationship
      staff.find_neo_relationship(type: :MANAGER_OF).should be_nil
    end

    it "stores model id attribute as property" do
      staff.neo_rel.id.should eq staff.id
    end
  end

  describe "#update_neo_relationship" do
    it "updates neo4j relationship after record was updated" do
      staff.find_neo_relationship.roles.should == %w(visitor)
      staff.update_attributes(roles: %w(visitor admin))
      staff.find_neo_relationship.roles.should == %w(visitor admin)
    end

    it "creates neo4j relationship if it is not exists after record was updated" do
      staff.destroy_neo_relationships
      staff.find_neo_relationship.should be_nil
      staff.update_attributes(roles: %w(admin))
      staff.find_neo_relationship.should be_a Neography::Relationship
      staff.find_neo_relationship.roles.should == %w(admin)
    end

    it "deletes optional relationship for which condition returns false" do
      staff.find_neo_relationship(type: :VISITOR_OF).should be_a Neography::Relationship
      staff.find_neo_relationship(type: :MANAGER_OF).should be_nil
      staff.update_attributes(roles: %w(manager))
      staff.find_neo_relationship(type: :VISITOR_OF).should be_nil
      staff.find_neo_relationship(type: :MANAGER_OF).should be_a Neography::Relationship
    end

    it "destroys relationship on update if actual relationship disappears (both nodes must be present)" do
      staff_of_premises
      Neomirror.neo.execute_query("MATCH (:User {id: #{user.id}})-[r:STAFF_OF]->(:Premises {id: #{premises.id}}) RETURN r")["data"].first.should be_present
      staff_of_premises.update(premises_id: nil)
      Neomirror.neo.execute_query("MATCH (:User {id: #{user.id}})-[r:STAFF_OF]->(:Premises {id: #{premises.id}}) RETURN r")["data"].first.should be_nil
    end

    it "removes itself and recreate if at least one of related object has changed" do
      staff_of_premises
      Neomirror.neo.execute_query("MATCH (:User {id: #{user.id}})-[r:STAFF_OF]->(:Premises {id: #{premises.id}}) RETURN r")["data"].first.should be_present
      staff_of_premises.update(premises_id: other_premises.id)
      Neomirror.neo.execute_query("MATCH (:User {id: #{user.id}})-[r:STAFF_OF]->(:Premises {id: #{premises.id}}) RETURN r")["data"].first.should be_nil
      Neomirror.neo.execute_query("MATCH (:User {id: #{user.id}})-[r:STAFF_OF]->(:Premises {id: #{other_premises.id}}) RETURN r")["data"].first.should be_present
    end
  end

  describe "#destroy_neo_relationship" do
    it "destroys neo4j relationship after record was destroyed" do
      membership.destroy
      membership.find_neo_relationship.should be_nil
      staff.destroy
      staff.find_neo_relationship(end_node: :premises, type: :STAFF_OF).should be_nil
      staff.find_neo_relationship(end_node: :group, type: :STAFF_OF).should be_nil
      staff.find_neo_relationship(type: :VISITOR_OF).should be_nil
    end
  end

  describe "#skip_neo_callbacks" do
    it "skips neo relationships create callback if skip_neo_callbacks set to true" do
      staff = build(:staff)
      staff.skip_neo_callbacks = true
      staff.save
      staff.find_neo_relationship(end_node: :premises, type: :STAFF_OF).should be_nil
    end

    it "skips neo relationships update callback if skip_neo_callbacks set to true" do
      staff.skip_neo_callbacks = true
      staff.neo_relationship(end_node: :premises, type: :STAFF_OF).roles.should == %w(visitor)
      staff.update_attributes(roles: %w(visitor manager))
      staff.neo_relationship(end_node: :premises, type: :STAFF_OF).roles.should == %w(visitor)
    end

    it "skips neo relationships destroy callback if skip_neo_callbacks set to true" do
      staff.skip_neo_callbacks = true
      staff.destroy
      staff.find_neo_relationship(end_node: :premises, type: :STAFF_OF).should be_a Neography::Relationship
    end
  end
end
