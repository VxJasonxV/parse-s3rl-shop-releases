require 'httparty'
require 'oga'

# https://djs3rl.com/shop/EMFA?limit=100
page = HTTParty.get('https://djs3rl.com/shop/EMFA?limit=5')
page_parsed = Oga.parse_html(page)

release_pages = []
page_parsed.css('#content .product-layout').each do |r|
  release_pages << r.css('.name-product > a').attribute('href')[0].text
end

unless page_parsed.css('.pagination')
  next_page = page_parsed.css('.pagination > li.active + li > a').attribute('href')[0].text
end

# https://djs3rl.com/shop/EMFA/Punch-the-Gas
release_pages.each do |rp|
  release = {}
  release_page = HTTParty.get(rp)
  rp_parsed = Oga.parse_html(release_page)

  release['url'] = rp.gsub(/\?limit.*/, '')
  release['title'], release['album_artist'] = rp_parsed.css('.product-title').text.split(' - ')

  rp_parsed.css('.product-section > li').each do |e|
    cleanup_on_aisle = e.text
    cleanup_on_aisle.tr!("\n", '')
    cleanup_on_aisle.squeeze!(' ')
    cleanup_on_aisle.strip!

    cleanup_on_aisle.match(/^Label: (.*)$/) { release['label'] = $1 }
    cleanup_on_aisle.match(/^Product Code: (.*)$/) { release['catno'] = $1 }
  end

  tracks = rp_parsed.css('select > option')
  tracklist = []
  tracks.each_with_index do |t, i|
    next if i.zero? # Skips "--- Please Select ---" default option

    track = t.text
    track.squeeze!(' ')
    track.strip!
    track.gsub!(/\ \(.*\)/, '')
    track.gsub!(/MP3 - /, '')
    track.gsub!(/WAV - /, '')
    tracklist << track
  end

  tracklist.uniq!
  tracklist.sort_by! { |f| f.match('Radio Edit') ? 0 : 1 }

  seed = <<-HTML
<html>
  <head></head>
  <body>
    <form name="form" id="form" action="https://musicbrainz.org/release/add" method="POST">
      <input name="name" type="text" value="#{release['title']}" /><br />
      <input name="artist_credit.names.0.name" type="text" value="#{release['album_artist']}" /><br />

      <input name="language" type="text" value="eng" /><br />
      <input name="script" type="text" value="Latn" /><br />
      <input name="type" type="text" value="single" />
      <input name="status" type="text" value="official" /><br />
      <input name="packaging" type="text" value="none" /><br />

      <input name="events.0.country" type="text" value="XW" /><br />
      <input name="labels.0.mbid" type="text" value="319ce8d8-e217-4be1-b5c8-4c8ee38293d9" />
      <input name="labels.0.catalog_number" type="text" value="#{release['catno']}" /><br />

      <input name="mediums.0.format" type="text" value="Digital Media" /><br />
HTML
  tracklist.each_with_index do |t, i|
    title = "#{release['title']} (#{t})"
seed << <<-HTML
      <input name="mediums.0.track.#{i}.name" type="text" value="#{title}" /><br />
HTML
  end
seed << <<-HTML
      <input name="urls.0.url" type="text" value="#{release['url']}" /><br />
      <input name="urls.0.link_type" type="text" value="74" /><br />

      <textarea name="edit_note" type="text">Data comes from a S3RL Web Store scraper I built and ran against S3RL's shop ( https://github.com/VxJasonxV/parse-s3rl-shop-releases ).

      The Shop does not contain track numbers, I have opted to put Radio Edits first which is what I've conventionally seen on digital releases, such as https://music.apple.com/us/album/reflections-feat-lokka-vox-single/1477673119 for example. S3RL's own releases at least on iTunes tend to only have the Radio Edit, but a number of other (UK/AU/Happy) Hardcore digital releases I've added have followed this convention.

      Also, when viewing the majority of releases on the shop ( ex. https://djs3rl.com/shop/Dopamine -> https://i.imgur.com/g12qHZl.png ) the sort order is Radio Edit before DJ Edit, (both) MP3 before WAV.

      Any other tracks will be alphabetically sorted starting from A following Radio Edit.
      </textarea><br />
      <input type="submit" value="seed" />
    </form>
  </body>
</html>
HTML

  puts seed
  File.write("#{ENV['HOME']}/tmp/seed.html", seed)
  system('open', "#{ENV['HOME']}/tmp/seed.html")
  gets
end
