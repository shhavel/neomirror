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
      create_neo_node_constraint unless @neo_mirror[:indexed]
      @neo_mirror
    end

    def mirror_neo_node(options = {}, &block)
      raise "Node mirror is already defined. Reflection model into more than one node is not supported. Create an issue if you need such functionality." if @neo_mirror
      @neo_mirror = options
      @neo_mirror[:label] ||= self.name.gsub(/^.*::/, '').to_sym # demodulize
      @neo_mirror[:properties] = ::Neomirror::PropertyCollector.new(&block).properties if block_given?
      create_neo_node_constraint
      @neo_mirror
    end

    def neo_primary_key
      @neo_primary_key ||= self.respond_to?(:primary_key) ? self.__send__(:primary_key) : :id
    end
    attr_writer :neo_primary_key

  private
    def create_neo_node_constraint
      ::Neomirror.neo.execute_query("CREATE CONSTRAINT ON (n:#{@neo_mirror[:label]}) ASSERT n.id IS UNIQUE")
      @neo_mirror[:indexed] = true
    rescue
    end
  end

  def neo_node
    raise "Couldn't find neo_node declaration" unless self.class.neo_mirror
    find_neo_node || create_neo_node
  end
  alias_method :node, :neo_node

  def neo_node_properties
    hash = { :id => self.__send__(self.class.neo_primary_key) }
    if self.class.neo_mirror && self.class.neo_mirror[:properties]
      self.class.neo_mirror[:properties].each { |property, rule| hash[property] = rule.call(self) }
    end
    hash
  end

  def find_neo_node
    raise "Couldn't find neo_node declaration" unless self.class.neo_mirror
    n = 0
    begin
      label = self.class.neo_mirror[:label]
      id = self.__send__(self.class.neo_primary_key)
      return nil unless node = ::Neomirror.neo.find_nodes_labeled(label, { :id => id }).first
      @neo_node = ::Neography::Node.load(node, ::Neomirror.neo)
    rescue Exception => ex
      retry if (n += 1) <= 4
      raise ex
    end
  end

  attr_accessor :skip_neo_callbacks

  def create_neo_node
    return true unless self.class.neo_mirror && !skip_neo_callbacks
    n = 0
    begin
      @neo_node = ::Neography::Node.create(neo_node_properties, ::Neomirror.neo)
      ::Neomirror.neo.set_label(@neo_node, self.class.neo_mirror[:label])
      @neo_node
    rescue Exception => ex
      retry if (n += 1) <= 4
      raise ex
    end
  end

  def update_neo_node
    return true unless self.class.neo_mirror && !skip_neo_callbacks
    if find_neo_node
      n = 0
      begin
        ::Neomirror.neo.reset_node_properties(@neo_node, neo_node_properties) if self.class.neo_mirror[:properties]
      rescue Exception => ex
        retry if (n += 1) <= 4
        raise ex
      end
      true
    else
      create_neo_node
    end
  end

  def destroy_neo_node
    return true unless self.class.neo_mirror && !skip_neo_callbacks && find_neo_node
    n = 0
    begin
      ::Neomirror.neo.delete_node!(@neo_node)
    rescue Exception => ex
      retry if (n += 1) <= 4
      raise ex
    end
    true
  end
end
