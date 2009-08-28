require 'uri'
require 'builder'
require 'date'
require 'base64'
class RDFResource
  attr_reader :uri, :namespaces, :modifiers, :rdfxml
  def initialize(uri)
    @uri = uri
    @namespaces = ['http://www.w3.org/1999/02/22-rdf-syntax-ns#']
    @modifiers = {}
  end
  
  def assert(predicate, object, type=nil, lang=nil)
    uri = URI.parse(predicate)
    ns = nil
    elem = nil
    if uri.fragment
      ns, elem = predicate.split('#')
      ns << '#'
    else
      elem = uri.path.split('/').last
      ns = predicate.sub(/#{elem}$/, '')
    end
    attr_name = ''
    if i = @namespaces.index(ns)
      attr_name = "n#{i}_#{elem}"
    else
      @namespaces << ns
      attr_name = "n#{@namespaces.index(ns)}_#{elem}"
    end
    unless type
      val = object
    else
      @modifiers[object.object_id] ||={}
      @modifiers[object.object_id][:type] = type      
      val = case type
      when 'http://www.w3.org/2001/XMLSchema#dateTime' then DateTime.parse(object)
      when 'http://www.w3.org/2001/XMLSchema#date' then Date.parse(object)
      when 'http://www.w3.org/2001/XMLSchema#int' then object.to_i
      when 'http://www.w3.org/2001/XMLSchema#string' then object.to_s
      when 'http://www.w3.org/2001/XMLSchema#boolean'
        if object.downcase == 'true' || object == '1'
          true
        else
          false
        end
      else
        object
      end
    end
    if lang
      @modifiers[object.object_id] ||={}
      @modifiers[val.object_id][:language] = lang  
    end
    if self.instance_variable_defined?("@#{attr_name}")
      unless self.instance_variable_get("@#{attr_name}").is_a?(Array)
        att = self.instance_variable_get("@#{attr_name}")
        self.instance_variable_set("@#{attr_name}", [att])
      end
      self.instance_variable_get("@#{attr_name}") << val
    else
      self.instance_variable_set("@#{attr_name}", val)
    end
  end
  
  def to_rdfxml
    doc = Builder::XmlMarkup.new
    xmlns = {}
    i = 1
    @namespaces.each do | ns |
      next if ns == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
      xmlns["xmlns:n#{i}"] = ns
      i += 1
    end
    doc.rdf :Description,xmlns.merge({:about=>uri}) do | rdf |
      self.instance_variables.each do | ivar |
        next unless ivar =~ /^@n[0-9]*_/
        prefix, tag = ivar.split('_',2)
        attrs = {}
        curr_attr = self.instance_variable_get("#{ivar}")
        prefix.sub!(/^@/,'')
        prefix = 'rdf' if prefix == 'n0'
        unless curr_attr.is_a?(Array)
          curr_attr = [curr_attr]
        end
        curr_attr.each do | val |
          if val.is_a?(RDFResource)
            attrs['rdf:resource'] = val.uri
          end
          if @modifiers[val.object_id]
            if @modifiers[val.object_id][:language]
              attrs['xml:lang'] = @modifiers[val.object_id][:language]
            end
            if @modifiers[val.object_id][:type]
              attrs['rdf:datatype'] = @modifiers[val.object_id][:type]
            end          
          end
          unless attrs['rdf:resource']
            rdf.tag!("#{prefix}:#{tag}", attrs, val)
          else
            rdf.tag!("#{prefix}:#{tag}", attrs)
          end
        end
      end
    end
    doc.target!
  end
  
  def to_ruby
    str = "{'id'=>'#{@uri}',"
    instance_variables.each do | ivar |
      next unless ivar =~ /^@n[0-9]*_/
      prefix, tag = ivar.split('_',2)
      idx = prefix.match(/[0-9]*$/)[0]      
      str << "'#{@namespaces[idx.to_i]}#{tag}'=>"
      ivar_val = instance_variable_get(ivar)
      if ivar_val.is_a?(Array)
        str << "["
        ivar_val.each do | iv |
          str << "'#{iv.gsub(/\'/,"\\\\'")}', "
        end
        str << "]"
      else
        str << "'#{ivar_val.gsub(/\'/, "\\\\'")}'"
      end
      str << ', '
    end
    str << "'rdf' => '#{@rdfxml.gsub(/\'/,"\\\\'")}'"
    str << "}"
    str
  end
  
  def to_hash
    response = {'id'=>@uri,'rdf'=>@rdfxml}
    instance_variables.each do | ivar |
      next unless ivar =~ /^@n[0-9]*_/
      prefix, tag = ivar.split('_',2)
      idx = prefix.match(/[0-9]*$/)[0] 
      ivar_val = instance_variable_get(ivar)
      if ivar_val.is_a?(Array)
        response["#{@namespaces[idx.to_i]}#{tag}"] = []
        ivar_val.each do | iv |
          if iv.is_a?(RDFResource)
            response["#{@namespaces[idx.to_i]}#{tag}"] << iv.uri
          else
            response["#{@namespaces[idx.to_i]}#{tag}"] << iv
          end
        end    
      else
        if ivar_val.is_a?(RDFResource)
          response["#{@namespaces[idx.to_i]}#{tag}"] = ivar_val.uri
        else
          response["#{@namespaces[idx.to_i]}#{tag}"] = ivar_val
        end
      end    
    end
    response
  end
  
  def set_rdfxml(doc)
    @rdfxml = doc
  end
  
end