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
      class_name = self.name.gsub(/^.*::/, '').gsub(/([a-z\d])([A-Z])/, '\1_\2')
      m[:type] = (m[:type] ? m[:type] : class_name.upcase).to_sym
      m[:properties] = Neomirror::PropertyCollector.new(&block).properties if block_given?
      m[:if] = m[:if].to_proc if m[:if]
      m[:index_name] = "#{m[:start_node] == :self ? class_name.downcase : m[:start_node]}_#{m[:type]}_#{m[:end_node] == :self ? class_name.downcase : m[:end_node]}"
      ::Neomirror.neo.create_relationship_index(m[:index_name])
      rel_mirrors << m
    end

    def neo_primary_key
      @neo_primary_key ||= self.respond_to?(:primary_key) ? self.__send__(:primary_key) : :id
    end
    attr_writer :neo_primary_key
  end

  def neo_relationship(partial_mirror = nil)
    find_neo_relationship(partial_mirror) || create_neo_relationship(partial_mirror)
  end
  alias_method :neo_rel, :neo_relationship

  def neo_relationship_properties(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    return nil unless rel_mirror[:properties]
    rel_mirror[:properties].reduce({}) { |hash, (property, rule)| hash[property] = rule.call(self); hash }
  end

  def neo_relationship_must_exist?(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    !rel_mirror[:if] || !!rel_mirror[:if].call(self)
  end

  def find_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    return nil unless rel = ::Neomirror.neo.get_relationship_index(rel_mirror[:index_name], :id, self.__send__(self.class.neo_primary_key))
    @neo_rel = ::Neography::Relationship.load(rel, ::Neomirror.neo)
  end

  def create_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    return nil unless (m1 = related_object(rel_mirror[:start_node])) && (m2 = related_object(rel_mirror[:end_node])) &&
      neo_relationship_must_exist?(rel_mirror)
    @neo_rel = ::Neography::Relationship.create(rel_mirror[:type], m1.neo_node, m2.neo_node, neo_relationship_properties(rel_mirror))
    ::Neomirror.neo.add_relationship_to_index(rel_mirror[:index_name], :id, self.__send__(self.class.neo_primary_key), @neo_rel)
    @neo_rel
  end

  def related_object(method_name)
    method_name == :self ? self : self.__send__(method_name)
  end

  def update_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    if find_neo_relationship(rel_mirror)
      if related_object(rel_mirror[:start_node]) && related_object(rel_mirror[:end_node]) && neo_relationship_must_exist?(rel_mirror)
        ::Neomirror.neo.reset_relationship_properties(@neo_rel, neo_relationship_properties(rel_mirror))
      else
        ::Neomirror.neo.remove_relationship_from_index(rel_mirror[:index_name], :id, self.__send__(self.class.neo_primary_key), @neo_rel)
        ::Neomirror.neo.delete_relationship(@neo_rel)
      end
    else
      create_neo_relationship(rel_mirror) if neo_relationship_must_exist?(rel_mirror)
    end
  end

  def destroy_neo_relationship(partial_mirror = nil)
    raise "Couldn't find neo_relationship declaration" unless rel_mirror = self.class.rel_mirror(partial_mirror)
    if find_neo_relationship(rel_mirror)
      ::Neomirror.neo.remove_relationship_from_index(rel_mirror[:index_name], :id, self.__send__(self.class.neo_primary_key), @neo_rel)
      ::Neomirror.neo.delete_relationship(@neo_rel)
    end
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
