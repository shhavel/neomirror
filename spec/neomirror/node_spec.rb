require "spec_helper"

describe Neomirror::Node do
  let(:user) { create(:user) }
  let(:neo_node) { user.find_neo_node }

  describe "#find_neo_node" do
    it "searches neo4j node, returns Neography::Node instance" do
      user.find_neo_node.should be_a Neography::Node
      user.find_neo_node.name.should == user.name
    end

    it "returns nil if there is no node in neo4j" do
      user.destroy_neo_node
      user.find_neo_node.should be_nil
    end
  end

  describe "#neo_node" do
    it "finds neo4j node if exists, returns Neography::Node instance" do
      user.neo_node.should be_a Neography::Node
      user.neo_node.name.should == user.name
    end

    it "creates neo4j node if not exists, returns Neography::Node instance" do
      user.destroy_neo_node
      user.neo_node.should be_a Neography::Node
      user.neo_node.name.should == user.name
    end
  end

  describe "#create_neo_node" do
    before { user.destroy_neo_node }

    it "creates neo4j node after record was created" do
      user.create_neo_node
      neo_node.should be_a Neography::Node
    end
  end

  describe "#update_neo_node" do
    it "updates neo4j node after record was updated" do
      user.neo_node.name.should == 'Ted'
      user.update_attributes(name: 'Dougal')
      user.neo_node.name.should == 'Dougal'
    end

    it "creates neo4j node if it is not exists after record was updated" do
      user.destroy_neo_node
      user.find_neo_node.should be_nil
      user.update_attributes(name: 'Dougal')
      user.find_neo_node.should be_a Neography::Node
      user.find_neo_node.name.should == 'Dougal'
    end
  end

  describe "#destroy_neo_node" do
    it "destroys neo4j node after record was destroyed" do
      user.destroy
      user.find_neo_node.should be_nil
    end
  end

  describe ".neo_primary_key" do
    let(:postcode) { Postcode.new.tap { |p| p.code = 'ABC' } }

    it "sets custom primary key" do
      postcode.neo_node.should be_a Neography::Node
      postcode.neo_node.id.should == 'ABC'
    end
  end
end
