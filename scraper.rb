#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'open-uri'


class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

local = false
# local = true
sleep_between_requests = 60 # (seconds) be kind to El Salvador's server!

if local
	require 'pry'
	la_url = 'http://localhost:8000/pleno_legislativo.html'
else
	la_url = open('http://asamblea.gob.sv/pleno/pleno-legislativo', read_timeout: 60)
end

noko = noko_for(la_url)
ids = ScraperWiki::select('id from data')

noko.css('dl dt a').each do |a|
	person_url = a.xpath('./@href').text

	if local
		person_url.sub!('asamblea.gob.sv/pleno', 'localhost')
	end
	puts "url: #{person_url}"

	id = person_url.sub(/.*\//, '')
	puts "id: #{id}"

	# The server keeps going down, so better to only scrape data we don't already have
	if not ids.include?(id)
		p = noko_for(person_url)
		name = p.css('h1').text
		puts "name: #{name}"

		party_class = 'Grupo Parlamentario'
		group = p.xpath("//span[@class='informacion-diputado'][contains(.,'#{party_class}')]")
			.first.text.sub(/.*#{party_class}/, '').tidy
		puts "faction: #{group}"

		email = p.xpath("//span[.//img[contains(@src,'/emailicon.png')]]/a/@href").text.sub('mailto:', '')
		puts "email: #{email}"

		personal_email = p.xpath("//a[.//img[contains(@src,'personal-emailicon.png')]]/span").text
		puts "personal email: #{personal_email}"

		image = p.xpath("//h1/following-sibling::img[1]/@src").text.sub(/.*\//, "#{person_url}/")
		puts "image: #{image}\n"
		
		data = {
			id: id,
			name: name,
			faction: group,
			email: email,
			email__personal: personal_email,
			image: image,
		}
		ScraperWiki.save_sqlite([:id], data)

	else
		puts "already in database"
	end
	sleep(sleep_between_requests)
end
