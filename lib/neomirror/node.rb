module Neomirror::Node
  def self.included(base)
    base.extend(ClassMethods)
    base.after_create :create_neo_node if base.respond_to?(:after_create)
    base.after_update :update_neo_node if base.respond_to?(:after_update)
    base.after_destroy :destroy_neo_node if base.respond_to?(:after_destroy)
  end

  module ClassMethods
    def neo_mirror
      @neo_mirror ||= begin
        return nil unless a = self.ancestors.drop(1).find { |c| c.respond_to?(:neo_mirror) && c.neo_mirror }
        a.neo_mirror
      end
    end

    def mirror_neo_node(options = {}, &block)
      raise "Node mirror is already defined. Reflection model into more than one node is not supported. Create an issue if you need such functionality." if @neo_mirror
      @neo_mirror = options
      @neo_mirror[:label] ||= self.name.gsub(/^.*::/, '').to_sym # demodulize
      @neo_mirror[:properties] = ::Neomirror::PropertyCollector.new(&block).properties if block_given?
      ::Neomirror.neo.execute_query("CREATE CONSTRAINT ON (n:#{@neo_mirror[:label]}) ASSERT n.id IS UNIQUE")
      @neo_mirror
    end

    def node_primary_key
      @node_primary_key ||= self.respond_to?(:primary_key) ? self.__send__(:primary_key) : :id
    end
    attr_writer :node_primary_key
  end

  def neo_node
    raise "Couldn't find neo_node declaration" unless self.class.neo_mirror
    find_neo_node || create_neo_node
  end
  alias_method :node, :neo_node

  def neo_node_properties
    neo_node_properties = ::Hash.new
    neo_node_properties[:id] = self.__send__(self.class.node_primary_key)
    if self.class.neo_mirror && self.class.neo_mirror[:properties]
      self.class.neo_mirror[:properties].each do |property, rule|
        neo_node_properties[property] = rule.call(self)
      end
    end
    neo_node_properties
  end

  def find_neo_node
    raise "Couldn't find neo_node declaration" unless self.class.neo_mirror
    label = self.class.neo_mirror[:label]
    id = self.__send__(self.class.node_primary_key)
    return nil unless node = ::Neomirror.neo.find_nodes_labeled(label, { :id => id }).first
    @neo_node = ::Neography::Node.load(node, ::Neomirror.neo)
  end

  def create_neo_node
    return true unless self.class.neo_mirror
    @neo_node = ::Neography::Node.create(neo_node_properties, ::Neomirror.neo) 
    ::Neomirror.neo.set_label(@neo_node, self.class.neo_mirror[:label])
    @neo_node
  end

  def update_neo_node
    return true unless self.class.neo_mirror
    if find_neo_node
      ::Neomirror.neo.reset_node_properties(@neo_node, neo_node_properties) if self.class.neo_mirror[:properties]
      true
    else
      create_neo_node
    end
  end

  def destroy_neo_node
    return true unless self.class.neo_mirror && find_neo_node
    ::Neomirror.neo.delete_node!(@neo_node)
    true
  end

  def neo_node_to_cypher
    ":#{self.class.neo_mirror[:label]} {id:#{self.__send__(self.class.node_primary_key)}}"
  end
end
