module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks

    # Customize the index name
    #
    index_name [Rails.application.engine_name, Rails.env].join('_')

    # Set up index configuration and mapping
    #
    settings index: { number_of_shards: 1,
                      number_of_replicas: 0,
                      analysis: {
                        tokenizer: {
                          kuromoji_search_tokenizer:{ #for match search query
                            type: 'kuromoji_tokenizer',
                            mode: 'search'
                          },
                          kuromoji_completion_suggest_tokenizer: { #for completion suggester
                            type: 'kuromoji_tokenizer',
                            mode: 'extended'
                          },
                          kuromoji_term_suggest_tokenizer:{ #for term suggester
                            type: 'kuromoji_tokenizer',
                            mode: 'normal'
                          }
                        },
                        filter:{
                          kuromoji_pos_filter: {type: 'kuromoji_part_of_speech', stoptags: ['助詞-格助詞-一般', '助詞-終助詞']},
                          greek_lowercase_filter: {type: 'lowercase', language: 'greek'},
                          kuromoji_readingform_filter: {type: 'kuromoji_readingform', use_romaji: false},
                          kuromoji_stemmer_filter: {type: 'kuromoji_stemmer'},
                          kuromoji_stop_filter: {type: 'stop'}
                        },
                        analyzer:{
                          kuromoji_search_analyzer:{
                            type: 'custom',
                            tokenizer: 'kuromoji_search_tokenizer',
                            filter: ['kuromoji_baseform','cjk_width','kuromoji_pos_filter','greek_lowercase_filter','kuromoji_readingform_filter','kuromoji_stemmer_filter']
                          },
                          kuromoji_completion_suggest_analyzer:{
                            type: 'custom',
                            tokenizer: 'kuromoji_completion_suggest_tokenizer',
                            filter: ['cjk_width','greek_lowercase_filter','kuromoji_readingform_filter']
                          },
                          kuromoji_term_suggest_analyzer:{
                            type: 'custom',
                            tokenizer: 'kuromoji_term_suggest_tokenizer',
                            filter: ['kuromoji_readingform_filter','kuromoji_stop_filter']
                          }
                        }
                      }
    } do
      mapping dynamic: 'false' do
        indexes :subject, type: 'string' do
          indexes :text, type: 'string', analyzer: 'kuromoji_search_analyzer'
          indexes :completion_suggest, type: 'string', analyzer: 'kuromoji_completion_suggest_analyzer'
          indexes :term_suggest, type: 'string', analyzer: 'kuromoji_term_suggest_analyzer'
        end
        indexes :user, type: 'nested' do
          # indexes :name, type: 'string', analyzer: 'kuromoji_search_analyzer'
          indexes :email, type: 'string'
        end
        indexes :from_address, type: 'string'
        indexes :mail_body, type: 'string' do
          indexes :text, type: 'string', analyzer: 'kuromoji_search_analyzer'
          indexes :completion_suggest, type: 'string', analyzer: 'kuromoji_completion_suggest_analyzer'
          indexes :term_suggest, type: 'string', analyzer: 'kuromoji_term_suggest_analyzer'
        end
        indexes :header, type: 'string'
        indexes :created_at, type: 'date'
      end
    end

    # Set up callbacks for updating the index on model changes
#    after_commit lambda { Indexer.perform_async(:index,  self.class.to_s, self.id) }, on: :create
#    after_commit lambda { Indexer.perform_async(:update, self.class.to_s, self.id) }, on: :update
#    after_commit lambda { Indexer.perform_async(:delete, self.class.to_s, self.id) }, on: :destroy
#    after_touch  lambda { Indexer.perform_async(:update, self.class.to_s, self.id) }

    # Customize the JSON serialization for Elasticsearch
    #
    def as_indexed_json(options={})
      hash = self.as_json(
        include: {
          user: {only: [:email]}
        }
      )

      hash
    end

    # Search in title and content fields for `query`, include highlights in response
    #
    # @param query [String] The user query
    # @return [Elasticsearch::Model::Response::Response]
    #
    def self.search(query, options={})

      # Prefill and set the filters (top-level `filter` and `facet_filter` elements)
      #
      __set_filters = lambda do |f|

        @search_definition[:filter][:and] ||= []
        @search_definition[:filter][:and]  |= [f]

      end

      @search_definition = {
        query: {},
        filter: {}
      }

      unless query.blank?
        @search_definition[:query] = {
          multi_match: {
            query: query,
            fields: ['name','description'],
            type: 'best_fields',
            operator: 'and'
          }
        }
      else
        @search_definition[:query] = { match_all: {} }
      end

      if options[:artist_id]
        f = { term: { 'artist_id' => options[:artist_id] } }
        __set_filters.(f)
      end

      if options[:album_id]
        f = { term: { 'album_id' => options[:album_id] } }
        __set_filters.(f)
      end

      if options[:sort]
        @search_definition[:sort]  = { options[:sort] => 'desc' }
        @search_definition[:track_scores] = true
      end

      __elasticsearch__.search(@search_definition)
    end
  end
end
