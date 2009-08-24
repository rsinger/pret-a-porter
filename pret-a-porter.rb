require 'rubygems'
require 'sinatra'
require 'pho'
require 'nokogiri'
require 'lib/platform'
require 'lib/rdf_resource'

configure do
  STORES = {}
end

get '/:store/select' do
  unless STORES[params["store"]]
    init_store(params["store"])
  end
  query_string = (params['q'] || "*:*")
  if params['fq']
    query_string << " +#{params['fq']}"
  end
  opts = {}
  if params['rows']
    opts['max'] = params['rows']
  end
  if params['start']
    opts['offset'] = params['start']
  end
  if params['sort']
    opts['sort'] = params['sort']
  end
  
  response = case params['qt'] 
    when 'document' then DescribeResponse.new(STORES[params["store"]][:connection].describe(params[:id]))
    else SearchResponse.new(STORES[params["store"]][:connection].search(query_string, opts))
  end
  
  
  if params["facet"] == "true"
    response.solr_response.facets ||= {}
    response.solr_response.facets['facet_fields'] ||={}
    for var in request.query_string.split("&")
      f,v = var.split('=')
      if f == 'facet.field'
        response.solr_response.facets['facet_fields'][v] = []
      end
    end
    facet_response = STORES[params["store"]][:connection].facet(query_string, response.solr_response.facets['facet_fields'].keys, {'output'=>'xml'})
    FacetResponse.new(facet_response, response.solr_response)
  end
  response.solr_response.send("to_#{params["wt"]}")
end


def init_store(store)
  STORES[store] = {:connection => Pho::Store.new("http://api.talis.com/stores/#{store}")}
end


class SelectResponse
  attr_accessor :total_results, :start_index, :results, :facets, :results_per_page
  def initialize
    @total_results = 0
    @start_index = 0    
    @results = []
  end
  
  def to_ruby
    response = to_hash
    response['responseHeader']['params']['wt'] = 'ruby'    
    response.inspect
  end  
  
  def to_json
    response = to_hash
    response['responseHeader']['params']['wt'] = 'json'
    response.to_json
  end
  
  def to_python
    response = to_hash
    response['responseHeader']['params']['wt'] = 'python'    
    response.to_json
  end
  
  def to_hash
    response = {'responseHeader'=>{'status'=>0,'QTime'=>0, 'params'=>{'rows'=>(@results_per_page||0)}}}
    response['responseHeader']['params']['spellcheck.q'] = ''
    response['response']={'numFound'=>@total_results, 'start'=>@start_index, 'maxScore'=> 1.0, 'docs'=>[]}
    @results.each do | result |
      response['response']['docs'] << result.to_hash
    end
    
    if @facets
      response['responseHeader']['facet'] = 'true'
      response['responseHeader']['facet.field'] = (@facets['facet_fields'].keys||[])

      response['facet_counts'] = {'facet_queries'=>{},'facet_fields'=>{}}
      @facets['facet_fields'].each do | field, values |
        response['facet_counts']['facet_fields'][field] = values
      end
    end
    response
  end    
end

