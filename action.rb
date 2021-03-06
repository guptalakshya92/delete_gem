require 'awesome_print'
require 'octokit'
require 'json'
require 'net/http'
require 'uri'

puts "environments  from yml #{ENV['INPUT_PACKAGE-NAME']}"
puts "workspace path #{ENV['GITHUB_WORKSPACE']}"
puts "workspace all directories #{Dir['*']}"
puts "current working directory #{Dir.pwd}"

require_relative "#{ENV['GITHUB_WORKSPACE']}/#{ENV['INPUT_PACKAGE-NAME']}/lib/#{ENV['INPUT_PACKAGE-NAME']}/version"

client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])

org_query = <<-GRAPHQL
query {
  organization(login: "#{ENV['INPUT_ORGANISATION-NAME']}") {
      packages(names: ["#{ENV['INPUT_PACKAGE-NAME']}"], first: 100){
        nodes{
          versions(last:100){
            nodes{
              id
              version
            }
          }
        }
      }
  }
}
GRAPHQL

repo_query = <<-GRAPHQL
query {
  repository(owner: "#{ENV['OWNER']}",name: "#{ENV['INPUT_REPO-NAME']}") {
    packages(names: ["#{ENV['INPUT_PACKAGE-NAME']}"], first: 100){
      nodes{
        versions(last:100){
          nodes{
            id
            version
          }
        }
      }
    }
  }
}
GRAPHQL

is_org = (!"#{ENV['INPUT_ORGANISATION-NAME']}".nil? && !"#{ENV['INPUT_ORGANISATION-NAME']}".empty?)
response = client.post '/graphql', {query: "#{(is_org ? org_query : repo_query)}"}.to_json
ap response
version_to_be_deleted = Kernel.const_get("#{ENV['INPUT_PACKAGE-NAME']}".capitalize)::VERSION
puts "version to be deleted  #{version_to_be_deleted}"
version_obj = response[:data][(is_org ? :organization : :repository)][:packages][:nodes][0][:versions][:nodes].find {|x| x[:version].to_s == version_to_be_deleted.to_s}
puts "version object #{version_obj}"
if !version_obj.nil?
#   mutation = <<-GRAPHQL
# mutation {
#   deletePackageVersion (input:{packageVersionId: "#{version_obj[:id]}"}){
#      success
#    }
#  }
# GRAPHQL
#   puts " inside if version present check with query #{mutation}"
#   mutation_response = client.post '/graphql', {query: mutation}.to_json
  
#   ap mutation_response

  uri = URI.parse("https://api.github.com/graphql")
  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/vnd.github.package-deletes-preview+json"
  request["Authorization"] = "bearer #{ENV['GITHUB_TOKEN']}"
  request.body = JSON.dump({
                               "query" => "mutation { deletePackageVersion(input:{packageVersionId:\"#{version_obj[:id]}\"}) { success }}"
                           })

  req_options = {
      use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

response.code
ap JSON.parse response.body
  
end




