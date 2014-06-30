module Neomirror::Relationship
  def self.included(base)
    base.extend(ClassMethods)
    base.after_create :create_neo_relationships if base.respond_to?(:after_create)
    base.after_update :update_neo_relationships if base.respond_to?(:after_update)
    base.after_destroy :destroy_neo_relationships if base.respond_to?(:after_destroy)
  end

  module ClassMethods
    def rel_mirrors
      @rel_mirrors ||= begin
        if a = self.ancestors.drop(1).find { |c| c.respond_to?(:rel_mirrors) && c.rel_mirrors.any? }
          a.rel_mirrors
        else
          []
        end
      end
    end

    # Find declaration by partial options.
    def rel_mirror(p)
      return rel_mirrors.first unless p
      rel_mirrors.find { |m| (!p[:start_node] || p[:start_node] == m[:start_node]) &&
        (!p[:end_node] || p[:end_node] == m[:end_node]) && (!p[:type] || p[:type] == m[:type]) }
    end

    def mirror_neo_relationship(options, &block)
      m = Hash[options.map{ |k, v| [k.to_sym, v] }]
      raise ArgumentError, "Mirror with such options already defined" if rel_mirror(m)
      raise ArgumentError, "Options :start_node and :end_node are mandatory" unless m[:start_node] && m[:end_node]
      m[:start_node] = m[:start_node].to_sym
      m[:end_node] = m[:end_node].to_sym
      m[:type] = (m[:type] ? m[:type] : self.name.gsub(/^.*::/, '').gsub(/([a-z\d])([A-Z])/, '\1_\2').upcase).to_sym
      m[:properties] = Neomirror::PropertyCollector.new(&block).properties if block_given?
      m[:if] = m[:if].to_proc if m[:if]
      rel_mirrors << m
    end
  end

  def neo_relationship(partial_mirror = nil)
    find_neo_relationship(partial_mirror) || create_neo_relationship(partial_mirror)
  end
  alias_method :neo_rel, :neo_relationship

  def neo_relationship_properties(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    return nil unless rel_mirror[:properties]
    rel_mirror[:properties].reduce({}) { |h, (property, rule)| h[property] = rule.call(self); h }
  end

  def neo_relationship_must_exist?(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    !rel_mirror[:if] || !!rel_mirror[:if].call(self)
  end

  def find_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    return nil unless (m1 = self.__send__(rel_mirror[:start_node])) && (m2 = self.__send__(rel_mirror[:end_node])) &&
      (rel = ::Neomirror.neo.execute_query("MATCH (#{m1.neo_node_to_cypher})-[r:#{rel_mirror[:type]}]->(#{m2.neo_node_to_cypher}) RETURN r")["data"].first)
    @neo_rel = ::Neography::Relationship.load(rel, ::Neomirror.neo)
  end

  def create_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    return nil unless self.__send__(rel_mirror[:start_node]) && self.__send__(rel_mirror[:end_node]) && 
      neo_relationship_must_exist?(rel_mirror)
    ::Neography::Relationship.create(rel_mirror[:type], self.__send__(rel_mirror[:start_node]).neo_node, 
      self.__send__(rel_mirror[:end_node]).neo_node, neo_relationship_properties(rel_mirror))
  end

  def update_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    if find_neo_relationship(rel_mirror)
      if neo_relationship_must_exist?(rel_mirror)
        ::Neomirror.neo.reset_relationship_properties(@neo_rel, neo_relationship_properties(rel_mirror))
      else
        ::Neomirror.neo.delete_relationship(@neo_rel)
      end
    else
      create_neo_relationship(rel_mirror) if neo_relationship_must_exist?(rel_mirror)
    end
  end

  def destroy_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    ::Neomirror.neo.delete_relationship(@neo_rel) if find_neo_relationship(rel_mirror)
  end

  def create_neo_relationships
    self.class.rel_mirrors.each { |rel_mirror| create_neo_relationship(rel_mirror) }
    true
  end

  def update_neo_relationships
    self.class.rel_mirrors.each { |rel_mirror| update_neo_relationship(rel_mirror) }
    true
  end

  def destroy_neo_relationships
    self.class.rel_mirrors.each { |rel_mirror| destroy_neo_relationship(rel_mirror) }
    true
  end
end
