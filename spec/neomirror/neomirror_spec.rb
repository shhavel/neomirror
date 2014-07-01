require "spec_helper"

describe Neomirror do
  describe "Reflection of model as node and relation" do
    let(:group) { create(:group) }
    let(:child_group) { create(:group, parent: group) }

    it "creates neo4j nodes" do
      group.find_neo_node.should be_a Neography::Node
      child_group.find_neo_node.should be_a Neography::Node
    end

    it "creates neo4j relation with object itself" do
      group.find_neo_relationship.should be_nil
      child_group.find_neo_relationship.should be_a Neography::Relationship
      Neomirror.neo.execute_query("MATCH (:Group {id: #{child_group.id}})-[r:CHILD_OF]->(:Group {id: #{group.id}}) RETURN r")["data"].first.should be_present
    end

    it "destroys relationship on update if actual relationship disappears (both nodes must be present)" do
      child_group.update(parent_id: nil)
      child_group.find_neo_relationship.should be_nil
      Neomirror.neo.execute_query("MATCH (:Group {id: #{child_group.id}})-[r:CHILD_OF]->(:Group {id: #{group.id}}) RETURN r")["data"].first.should be_nil
    end
  end
end
