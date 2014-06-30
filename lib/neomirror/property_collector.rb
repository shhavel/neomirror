class Neomirror::PropertyCollector
  def properties
    @properties ||= {}
  end

  def property(property_name, record_method_name = nil, &block)
    if record_method_name && block_given?
      raise ArgumentError, "For property provide record's method name or block (or proc)"
    elsif block_given?
      properties[property_name.to_sym] = block
    else
      record_method_name ||= property_name
      record_method_name = record_method_name.to_sym if record_method_name.is_a?(String)
      properties[property_name.to_sym] = record_method_name.to_proc
    end
  end

private

  def initialize(&block)
    return unless block_given? 
    if block.arity == 0
      self.instance_eval(&block)
    else
      block.call(self)
    end
  end
end
