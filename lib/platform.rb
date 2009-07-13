class SearchResponse
  attr_accessor :solr_response
  def initialize(response , solr_response=nil)
    @namespaces = {'rss'=>'http://purl.org/rss/1.0/','os'=>'http://a9.com/-/spec/opensearch/1.1/'}
    parse_response(response.body.content)
    @solr_response = solr_response if solr_response
  end
  
  def parse_response(doc)    
    @solr_response = SelectResponse.new unless @solr_response
    rss = Nokogiri::XML.parse(doc)
    total = rss.xpath('//rss:channel/os:totalResults', @namespaces)
    @solr_response.total_results = total.inner_text.to_i if total.length > 0
    offset = rss.xpath('//rss:channel/os:startIndex', @namespaces)
    @solr_response.start_index = offset.inner_text.to_i if offset.length > 0  
    items_per_page = rss.xpath('//rss:channel/os:itemsPerPage', @namespaces)
    @solr_response.results_per_page = items_per_page.inner_text.to_i if items_per_page.length > 0
    rss.xpath('//rss:item', @namespaces).each do | item |
      i = RDFResource.new(item['about'])
      d = Nokogiri::XML::Document.new
      rdf = Nokogiri::XML::Node.new('rdf:RDF',d)
      rdf.add_namespace('rdf','http://www.w3.org/1999/02/22-rdf-syntax-ns#')
      c = item.clone
      c.name='rdf:Description'
      rdf.add_child(c)
      i.set_rdfxml(rdf.to_xml)
      item.children.each do | child |
        next unless child.inner_text
        predicate = "#{child.namespace.href}#{child.name}"
        i.assert(predicate, child.inner_text)
      end
      @solr_response.results << i
    end
  end
end

class FacetResponse
  attr_accessor :solr_response
  def initialize(response, solr_response=nil)
    @namespaces = {'facet'=>'http://schemas.talis.com/2007/facet-results#'}
    @solr_response = solr_response if solr_response
    parse_response(response.body.content)
  end 
  
  def parse_response(doc)
    @solr_response = SelectResponse.new unless @solr_response

    @solr_response.facets = {'facet_fields' => {}}

    facets = Nokogiri::XML.parse(doc)
    facets.xpath('//facet:fields/facet:field', @namespaces).each do | facet |
      field = facet['name']
      @solr_response.facets['facet_fields'][field] = []
      facet.children.each do | child |
        next unless child.name == 'term'
        @solr_response.facets['facet_fields'][field] << child['value']
        @solr_response.facets['facet_fields'][field] << child['number']
      end
    end
  end 
end