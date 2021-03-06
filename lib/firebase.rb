require 'firebase/response'
require 'firebase/server_value'
require 'googleauth'
require 'httpclient'
require 'json'
require 'uri'

module Firebase
  class Client
    attr_reader :request

    def initialize(base_uri, auth)
      if base_uri !~ URI::regexp(%w(https))
        raise ArgumentError.new('base_uri must be a valid https uri')
      end
      base_uri += '/' unless base_uri.end_with?('/')
      @request = HTTPClient.new({
        :base_url => base_uri,
        :default_header => {
          'Content-Type' => 'application/json'
        }
      })
      @credentials = auth
      @credentials.apply!(@request.default_header)
      @expires_at = @credentials.issued_at + 0.95 * @credentials.expires_in
    end

    # Writes and returns the data
    #   Firebase.set('users/info', { 'name' => 'Oscar' }) => { 'name' => 'Oscar' }
    def set(path, data, query={})
      process :put, path, data, query
    end

    # Returns the data at path
    def get(path, query={})
      process :get, path, nil, query
    end

    # Writes the data, returns the key name of the data added
    #   Firebase.push('users', { 'age' => 18}) => {"name":"-INOQPH-aV_psbk3ZXEX"}
    def push(path, data, query={})
      process :post, path, data, query
    end

    # Deletes the data at path and returs true
    def delete(path, query={})
      process :delete, path, nil, query
    end

    # Write the data at path but does not delete ommited children. Returns the data
    #   Firebase.update('users/info', { 'name' => 'Oscar' }) => { 'name' => 'Oscar' }
    def update(path, data, query={})
      process :patch, path, data, query
    end

    private

    def process(verb, path, data=nil, query={})
      if path[0] == '/'
        raise(ArgumentError.new("Invalid path: #{path}. Path must be relative"))
      end

      if @expires_at && Time.now > @expires_at
        @credentials.refresh!
        @credentials.apply! @request.default_header
        @expires_at = @credentials.issued_at + 0.95 * @credentials.expires_in
      end

      Firebase::Response.new @request.request(verb, path, {
        :body             => (data && data.to_json)
      })
    end

    def valid_json?(json)
      begin
        JSON.parse(json)
        return true
      rescue JSON::ParserError
        return false
      end
    end
  end
end
