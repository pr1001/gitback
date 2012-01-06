#!/usr/bin/env ruby

require "rubygems"
require 'optparse'
require 'octokit'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'net/http'

options = {}
 
optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: gitback.rb [options] username/rep /destination/directory"
  
  options[:username] = nil
  opts.on('-u', '--username username', 'GitHub username') do |username|
    options[:username] = username
  end
  
  options[:password] = nil
  opts.on('-p', '--password password', 'GitHub password') do |password|
    options[:password] = password
  end
  
  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

# Parse the command-line. Remember there are two forms
# of the parse method. The 'parse' method simply parses
# ARGV, while the 'parse!' method parses ARGV and removes
# any options found there, as well as any parameters for
# the options. What's left is the list of files to resize.
optparse.parse!

reponame = ARGV[0]
path = ARGV[1]
if not reponame
  puts "A repo name in the format username/repo is required."
  exit
end
if not path
  puts "A path in the format /destination/directory is required."
  exit
end

client = (options[:username] and options[:password]) ? Octokit::Client.new(:login => options[:username], :password => options[:password]) : Octokit::Client.new()

# username, name = reponame.split('/')

repo = client.repo(reponame)

puts "Found repo " + repo["name"]

# make dir
FileUtils.mkdir_p(path)

clone_url = repo["private"] ? repo["ssh_url"] : repo["clone_url"]
git_path = path + "/" + repo["name"]
git_dir = git_path + "/.git"

system("git clone #{clone_url} #{git_path}")
# don't userstand why it's not picking up the work-tree param, so just cd to the dir first
system("cd #{git_path}; git --git-dir=#{git_dir} --work-tree=#{git_path} pull --all")

if repo["has_issues"]
  puts "We've got issues! Downloading them now..."
  
  # get the issues
  issues = client.list_issues(reponame)
  # can create the directory without checking because we know there are issues?
  FileUtils.mkdir_p(path + "/issues") unless issues.empty?
  issues.each do |issue|
    # write json issue to path + "/issues/" + issue["number"]
    FileUtils.mkdir_p(path + "/issues/" + issue["number"].to_s)
    File.open(path + "/issues/" + issue["number"].to_s + "/" + issue["number"].to_s + ".json", 'w') do |f|
      f.write(JSON.generate(issue))
    end
    if (issue["comments"] > 0)
      puts "Downloading " + issue["comments"].to_s + " comments"
      FileUtils.mkdir_p(path + "/issues/" + issue["number"].to_s + "/comments")
      comments = client.issue_comments(reponame, issue["number"])
      comments.each do |comment|
        # write json comment to path + "/issues/" + issue["number"] + "/comments/" + comment["id"]
        File.open(path + "/issues/" + issue["number"].to_s + "/comments/" + comment["id"].to_s + ".json", 'w') do |f|
          f.write(JSON.generate(comment))
        end
      end
    end
  end
end

if repo["has_wiki"]
  # not worth doing anything here since the wiki is already in the main repo?
  puts "This repo has a wiki. Remember, it's just a branch of your normal repo."
end

# FIXME: This only works for public repos
if repo["has_downloads"] and not repo["private"]
  downloads_url = repo["html_url"] + "/downloads"
  
  # get html, extract "#manual_downloads a[href]"
  page = Nokogiri::HTML(open(downloads_url))
  links = page.css("#manual_downloads a")
  
  # repo["has_downloads"] seems to always be true, so actually check first
  if links.length > 0
    puts "We've got downloads!"
    FileUtils.mkdir_p(path + "/downloads/")
  end
  
  # can we do this in parallel?
  links.each do |link|
    download_url = "https://github.com" + link["href"]
    puts "Downloading #{download_url}"
    # code to write the stream directly into the file and not store in memory first
    # from http://ruby-doc.org/stdlib-1.9.3/libdoc/net/http/rdoc/Net/HTTP.html
    uri = URI(download_url)
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new uri.request_uri
      http.request request do |response|
        open(path + "/downloads/" + link.inner_text, 'w') do |io|
          response.read_body do |chunk|
            io.write chunk
          end
        end
      end
    end
  end
elsif repo["has_downloads"] and repo["private"]
  downloads_url = repo["html_url"] + "/downloads"
  downloads_path = path + "/downloads/"
  FileUtils.mkdir_p(downloads_path)
  puts "This repo is private so we can't download the files for you (yet!)."
  puts "We've created the folder #{downloads_path} so you can manually download the files listed at #{downloads_url} into it."
end
