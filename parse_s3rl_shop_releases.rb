# frozen_string_literal: true

require 'httparty'
require 'oga'

# https://djs3rl.com/shop/EMFA?limit=100
page = HTTParty.get('https://djs3rl.com/shop/EMFA?limit=2')
page_parsed = Oga.parse_html(page)

release_pages = []
page_parsed.css('#content .product-layout').each do |r|
  release_pages << r.css('.name-product > a').attribute('href')[0].text
end

if page_parsed.css('.pagination')
  next_page = page_parsed.css('.pagination > li.active + li > a').attribute('href')[0].text
end

# https://djs3rl.com/shop/EMFA/Punch-the-Gas
release_pages.each do |rp|
  release_page = HTTParty.get(rp)
  rp_parsed = Oga.parse_html(release_page)

  release = rp_parsed.css('.product-title').text
  rp_parsed.css('.product-section > li').each do |e|
    cleanup_on_aisle = e.text
    cleanup_on_aisle.tr!("\n", '')
    cleanup_on_aisle.squeeze!(' ')
    cleanup_on_aisle.strip!

    cleanup_on_aisle.match(/^Label: (.*)$/) { puts $1 }
    cleanup_on_aisle.match(/^Product Code: (.*)$/) { puts $1 }
  end

  tracks = rp_parsed.css('select > option')
  tracklist = []
  tracks.each_with_index do |t, i|
    next if i.zero? # Skips "--- Please Select ---" default option

    track = t.text
    track.squeeze!(' ')
    track.strip!
    tracklist << track
  end

  p release
  p tracklist
  puts ''
end
