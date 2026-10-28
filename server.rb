# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'
require 'date'
require 'rexml/document'
require 'time'
require 'openssl'
require 'sinatra/base'

module Astra
  module_function

  AU_PER_LIGHT_YEAR = 63_241.077084
  OBLIQUITY_RAD = 23.4392911 * Math::PI / 180.0

  SPATIAL_DATA = {
    'sun' => { distance_ly: 0.0, local_position_au: [0.0, 0.0, 0.0], map_frame: 'solar-system', source: 'Solar System barycentric origin' },
    'mercury' => { distance_au: 0.3871, phase_deg: 14, orbit_radius_au: 0.3871, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'venus' => { distance_au: 0.7233, phase_deg: 81, orbit_radius_au: 0.7233, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'earth' => { distance_au: 1.0000, phase_deg: 181, orbit_radius_au: 1.0000, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'moon' => { parent_id: 'earth', offset_au: [0.00257, 0.0, 0.0], distance_au: 1.00257, map_frame: 'solar-system', source: 'Approximate Earth–Moon separation; JPL Horizons ephemeris refreshes position' },
    'mars' => { distance_au: 1.5237, phase_deg: 231, orbit_radius_au: 1.5237, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'ceres' => { distance_au: 2.7675, phase_deg: 143, orbit_radius_au: 2.7675, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'jupiter' => { distance_au: 5.2028, phase_deg: 291, orbit_radius_au: 5.2028, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'europa' => { parent_id: 'jupiter', offset_au: [0.00314, 0.0, 0.0], distance_au: 5.2059, map_frame: 'solar-system', source: 'Approximate moon orbit; JPL Horizons ephemeris refreshes position' },
    'ganymede' => { parent_id: 'jupiter', offset_au: [0.00716, 0.0, 0.0], distance_au: 5.21, map_frame: 'solar-system', source: 'Approximate moon orbit; JPL Horizons ephemeris refreshes position' },
    'saturn' => { distance_au: 9.5388, phase_deg: 340, orbit_radius_au: 9.5388, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'titan' => { parent_id: 'saturn', offset_au: [0.00817, 0.0, 0.0], distance_au: 9.547, map_frame: 'solar-system', source: 'Approximate moon orbit; JPL Horizons ephemeris refreshes position' },
    'enceladus' => { parent_id: 'saturn', offset_au: [0.00159, 0.0, 0.0], distance_au: 9.5404, map_frame: 'solar-system', source: 'Approximate moon orbit; JPL Horizons ephemeris refreshes position' },
    'uranus' => { distance_au: 19.191, phase_deg: 12, orbit_radius_au: 19.191, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'neptune' => { distance_au: 30.07, phase_deg: 81, orbit_radius_au: 30.07, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'pluto' => { distance_au: 39.482, phase_deg: 201, orbit_radius_au: 39.482, map_frame: 'solar-system', source: 'Mean orbital elements; JPL Horizons ephemeris refreshes position' },
    'halleys-comet' => { distance_au: 17.8, phase_deg: 73, orbit_radius_au: 17.8, map_frame: 'solar-system', source: 'Orbit semi-major axis; use JPL Horizons for date-specific position' },

    'proxima-centauri' => { ra_deg: 217.4292, dec_deg: -62.6795, distance_ly: 4.2465, source: 'ICRS coordinates and measured distance; values are rounded' },
    'proxima-centauri-b' => { ra_deg: 217.4292, dec_deg: -62.6795, distance_ly: 4.2465, host_id: 'proxima-centauri', source: 'Host-star position at interstellar scale; orbital offset is unresolved here' },
    'sirius' => { ra_deg: 101.2872, dec_deg: -16.7161, distance_ly: 8.60, source: 'ICRS coordinates and measured distance; values are rounded' },
    'betelgeuse' => { ra_deg: 88.7929, dec_deg: 7.4071, distance_ly: 548.0, source: 'ICRS coordinates; distance is uncertain and varies by study' },
    'vega' => { ra_deg: 279.2347, dec_deg: 38.7837, distance_ly: 25.04, source: 'ICRS coordinates and measured distance; values are rounded' },
    'trappist-1e' => { ra_deg: 346.622, dec_deg: -5.0415, distance_ly: 40.0, host_id: 'trappist-1', source: 'Host-star position at interstellar scale; orbital offset is unresolved here' },
    'kepler-186f' => { ra_deg: 298.65, dec_deg: 43.95, distance_ly: 490.0, host_id: 'kepler-186', source: 'Approximate host-star coordinates and distance; orbital offset is unresolved here' },
    'kepler-452-b' => { ra_deg: 296.004, dec_deg: 44.277, distance_ly: 1_400.0, host_id: 'kepler-452', source: 'Approximate host-star coordinates and distance; orbital offset is unresolved here' },
    'milky-way' => { ra_deg: 266.4168, dec_deg: -29.0078, distance_ly: 26_000.0, source: 'Galactic-centre direction and approximate Sun-to-centre distance' },
    'sagittarius-a-star' => { ra_deg: 266.4168, dec_deg: -29.0078, distance_ly: 26_000.0, source: 'Galactic-centre coordinates and approximate distance; black hole is at the galactic centre' },
    'andromeda' => { ra_deg: 10.6847, dec_deg: 41.2690, distance_ly: 2_537_000.0, source: 'ICRS coordinates and approximate distance' },
    'triangulum-galaxy' => { ra_deg: 23.4621, dec_deg: 30.6600, distance_ly: 2_730_000.0, source: 'ICRS coordinates and approximate distance' },
    'sombrero-galaxy' => { ra_deg: 189.9975, dec_deg: -11.6231, distance_ly: 29_300_000.0, source: 'ICRS coordinates and approximate distance' },
    'orion-nebula' => { ra_deg: 83.8221, dec_deg: -5.3911, distance_ly: 1_344.0, source: 'ICRS coordinates and approximate distance' },
    'crab-nebula' => { ra_deg: 83.6331, dec_deg: 22.0145, distance_ly: 6_523.0, source: 'ICRS coordinates and approximate distance' },
    'pillars-of-creation' => { ra_deg: 274.7, dec_deg: -13.8, distance_ly: 6_500.0, source: 'Approximate region centre and distance' },
    'm87-star' => { ra_deg: 187.7059, dec_deg: 12.3911, distance_ly: 53_500_000.0, source: 'Host galaxy coordinates and approximate distance' }
  }.freeze

  EPHEMERIS_BODY_IDS = {
    'mercury' => '199', 'venus' => '299', 'earth' => '399', 'moon' => '301',
    'mars' => '499', 'jupiter' => '599', 'saturn' => '699', 'uranus' => '799',
    'neptune' => '899', 'pluto' => '999', 'ceres' => '1;', 'europa' => '502',
    'ganymede' => '503', 'titan' => '606', 'enceladus' => '602', 'halleys-comet' => 'DES=1P/Halley;'
  }.freeze
  EPHEMERIS_MUTEX = Mutex.new
  EPHEMERIS_CACHE = { fetched_at: Time.at(0), positions: {} }

  def orbital_position_au(distance_au, phase_deg)
    angle = phase_deg.to_f * Math::PI / 180.0
    x = distance_au.to_f * Math.cos(angle)
    ecliptic_y = distance_au.to_f * Math.sin(angle)
    # Rotate the ecliptic plane into the equatorial frame; y is vertical in Three.js.
    [x, ecliptic_y * Math.sin(OBLIQUITY_RAD), -ecliptic_y * Math.cos(OBLIQUITY_RAD)]
  end

  def radec_position(ra_deg, dec_deg, distance_ly)
    return nil if ra_deg.nil? || dec_deg.nil? || distance_ly.nil?
    return nil unless [ra_deg, dec_deg, distance_ly].all? { |value| value.to_f.finite? }
    distance = distance_ly.to_f
    return nil if distance.negative? || distance > 100_000_000_000.0

    ra = ra_deg.to_f * Math::PI / 180.0
    dec = dec_deg.to_f * Math::PI / 180.0
    [distance * Math.cos(dec) * Math.cos(ra),
     distance * Math.sin(dec),
     -distance * Math.cos(dec) * Math.sin(ra)]
  end

  def add_spatial_metadata(item)
    data = SPATIAL_DATA[item[:id]] || {}
    local_au = if data[:local_position_au]
                 data[:local_position_au]
               elsif data[:parent_id]
                 parent = SPATIAL_DATA[data[:parent_id]] || {}
                 parent_au = parent[:local_position_au] || orbital_position_au(parent[:distance_au] || 0, parent[:phase_deg] || 0)
                 offset = data[:offset_au] || [0, 0, 0]
                 3.times.map { |index| parent_au[index].to_f + offset[index].to_f }
               elsif data[:distance_au]
                 orbital_position_au(data[:distance_au], data[:phase_deg] || 0)
               end

    position_ly = if data.key?(:distance_ly)
                    if data[:distance_ly].to_f.zero?
                      [0.0, 0.0, 0.0]
                    else
                      radec_position(data[:ra_deg], data[:dec_deg], data[:distance_ly])
                    end
                  elsif local_au
                    local_au.map { |coordinate| coordinate.to_f / AU_PER_LIGHT_YEAR }
                  end

    item[:position] = position_ly
    item[:local_position_au] = local_au if local_au
    item[:ra_deg] = data[:ra_deg] if data.key?(:ra_deg)
    item[:dec_deg] = data[:dec_deg] if data.key?(:dec_deg)
    item[:distance_ly] = data[:distance_ly] if data.key?(:distance_ly)
    item[:distance_from_sun_au] = data[:distance_au] if data.key?(:distance_au)
    item[:orbit_radius_au] = data[:orbit_radius_au] if data.key?(:orbit_radius_au)
    item[:host_id] = data[:host_id] if data[:host_id]
    item[:map_frame] = data[:map_frame] || (local_au ? 'solar-system' : 'universe')
    item[:position_source] = data[:source] || 'Coordinates and distance are not available for a physical placement'
    item[:position_accuracy] = position_ly ? 'catalog-position' : 'unavailable'
    item[:map_status] = position_ly ? 'plotted' : 'unplotted'
    item[:local_ephemeris_available] = !!EPHEMERIS_BODY_IDS[item[:id]]
    item
  end

  def source(label, publisher, url)
    { label: label, publisher: publisher, url: url }
  end

  def object(id, name, type, category, color, size, _initial_position, system, subtitle, description, facts, sources, related, texture_colors = nil)
    item = {
      id: id, name: name, type: type, category: category, color: color, size: size,
      system: system, subtitle: subtitle, description: description,
      facts: facts, sources: sources, related: related
    }
    item[:textureColors] = texture_colors if texture_colors
    add_spatial_metadata(item)
  end

  NASA = 'https://science.nasa.gov/'.freeze
  EXO = 'https://exoplanetarchive.ipac.caltech.edu/'.freeze
  WIKI = 'https://en.wikipedia.org/wiki/'.freeze

  CATALOG = [
    object('sun', 'Sun', 'Star', 'star', '#ffbd73', 1.05, [-12, 0, 0], 'Solar System',
      'The star at the center of our Solar System',
      'The Sun is the star at the center of our planetary system. Gravity holds the system together, while energy produced by nuclear fusion supplies most of the light and heat that reach Earth.',
      { 'Diameter' => '1.39 million km', 'Surface temperature' => 'About 5,500°C', 'Age' => 'About 4.6 billion years', 'Composition' => 'Hydrogen and helium', 'Star type' => 'G-type main-sequence star', 'System' => 'Solar System' },
      [source('Sun overview', 'NASA', 'https://science.nasa.gov/sun/'), source('Solar System', 'NASA', 'https://science.nasa.gov/solar-system/')],
      %w[mercury earth sirius sagittarius-a-star], ['#ffcf8c', '#653d32']),
    object('mercury', 'Mercury', 'Planet', 'planet', '#b4a18f', 0.23, [-9.6, 0.15, 0.25], 'Solar System',
      'The smallest planet',
      'Mercury is the smallest planet in our Solar System and the closest to the Sun. Its heavily cratered surface records a long history of impacts, and its very thin exosphere cannot retain heat well.',
      { 'Diameter' => '4,879 km', 'Year length' => '88 Earth days', 'Day length' => '59 Earth days', 'Mean distance' => '57.9 million km', 'Moons' => '0', 'Surface' => 'Rocky and cratered' },
      [source('Mercury facts', 'NASA', 'https://science.nasa.gov/mercury/facts/'), source('Mercury overview', 'NASA', 'https://science.nasa.gov/mercury/')],
      %w[sun venus earth], ['#bdb6ab', '#383b4b']),
    object('venus', 'Venus', 'Planet', 'planet', '#e5bd89', 0.36, [-8.8, -0.1, -2.8], 'Solar System',
      'A world wrapped in dense clouds',
      'Venus is similar in size to Earth but has an extremely hot surface beneath a thick carbon-dioxide atmosphere. Clouds of sulfuric acid obscure its surface from visible-light observation.',
      { 'Diameter' => '12,104 km', 'Year length' => '225 Earth days', 'Surface temperature' => 'About 465°C', 'Mean distance' => '108.2 million km', 'Moons' => '0', 'Atmosphere' => 'Mostly carbon dioxide' },
      [source('Venus facts', 'NASA', 'https://science.nasa.gov/venus/venus-facts/'), source('Venus overview', 'NASA', 'https://science.nasa.gov/venus/')],
      %w[mercury earth mars], ['#e7ca9a', '#694a36']),
    object('earth', 'Earth', 'Planet', 'planet', '#5e9eff', 0.41, [-7.5, 0.1, 1.2], 'Solar System',
      'Our home world',
      'Earth is the only world currently known to support life. Liquid water covers most of its surface, while its atmosphere and magnetic field help shield the biosphere from parts of the space environment.',
      { 'Diameter' => '12,756 km', 'Year length' => '365.25 days', 'Mean distance' => '149.6 million km', 'Natural moons' => '1', 'Age' => 'About 4.54 billion years', 'Surface water' => 'About 71%' },
      [source('Earth facts', 'NASA', 'https://science.nasa.gov/earth/facts/'), source('Earth Observatory', 'NASA', 'https://earthobservatory.nasa.gov/')],
      %w[moon mars sun trappist-1e], ['#64abe8', '#18365e']),
    object('moon', 'Moon', 'Natural satellite', 'moon', '#bec8d8', 0.15, [-6.8, 0.65, 1.45], 'Earth system',
      'Earth’s natural satellite',
      'Earth’s Moon is a rocky natural satellite with a heavily cratered surface. Its gravity is the main driver of Earth’s ocean tides; its phases reflect the changing Sun–Earth–Moon geometry.',
      { 'Diameter' => '3,475 km', 'Mean distance' => '384,400 km from Earth', 'Orbital period' => 'About 27.3 days', 'Gravity' => 'About 1/6 of Earth’s', 'Surface' => 'Rocky and airless' },
      [source('Moon facts', 'NASA', 'https://science.nasa.gov/moon/facts/'), source('Moon overview', 'NASA', 'https://science.nasa.gov/moon/')],
      %w[earth mars sun], ['#d7d8d5', '#474c5e']),
    object('mars', 'Mars', 'Planet', 'planet', '#e97859', 0.31, [-5.8, 0.2, -0.2], 'Solar System',
      'The Red Planet',
      'Mars is a cold desert world with a thin atmosphere, ancient river-shaped terrain and the tallest known volcano in the Solar System. Robotic missions study whether its past could have supported microbial life.',
      { 'Diameter' => '6,792 km', 'Year length' => '687 Earth days', 'Mean distance' => '227.9 million km', 'Natural moons' => '2', 'Largest volcano' => 'Olympus Mons', 'Atmosphere' => 'Mostly carbon dioxide' },
      [source('Mars facts', 'NASA', 'https://science.nasa.gov/mars/facts/'), source('Mars exploration', 'NASA', 'https://science.nasa.gov/mars/')],
      %w[earth jupiter ceres moon], ['#df8868', '#572c35']),
    object('jupiter', 'Jupiter', 'Planet', 'planet', '#d9ac86', 0.88, [-3.1, 0.1, -1.5], 'Solar System',
      'The giant of the Solar System',
      'Jupiter is the largest planet in our Solar System. It is a gas giant with cloud bands, powerful storms and a large family of moons, including the ocean-world candidate Europa.',
      { 'Diameter' => 'About 143,000 km', 'Year length' => '11.86 Earth years', 'Mean distance' => '778.6 million km', 'Cloud tops' => 'Hydrogen and helium', 'Great Red Spot' => 'Long-lived giant storm', 'Planet type' => 'Gas giant' },
      [source('Jupiter facts', 'NASA', 'https://science.nasa.gov/jupiter/facts/'), source('Jupiter overview', 'NASA', 'https://science.nasa.gov/jupiter/')],
      %w[mars saturn europa sun], ['#edd0a9', '#7f564d']),
    object('saturn', 'Saturn', 'Planet', 'planet', '#e4c995', 0.74, [0.1, 0.2, -2.5], 'Solar System',
      'The ringed gas giant',
      'Saturn is a gas giant known for its wide, bright ring system made mainly of water-ice particles mixed with rocky debris. Its moon Titan has lakes of liquid hydrocarbons and a dense atmosphere.',
      { 'Diameter' => 'About 120,500 km', 'Year length' => '29.4 Earth years', 'Mean distance' => '1.43 billion km', 'Rings' => 'Extensive ice-and-rock system', 'Largest moon' => 'Titan', 'Planet type' => 'Gas giant' },
      [source('Saturn facts', 'NASA', 'https://science.nasa.gov/saturn/facts/'), source('Saturn overview', 'NASA', 'https://science.nasa.gov/saturn/')],
      %w[jupiter uranus titan], ['#ebd7ad', '#8b735c']),
    object('uranus', 'Uranus', 'Planet', 'planet', '#94dce6', 0.56, [3.6, 0.18, -1.7], 'Solar System',
      'The tilted ice giant',
      'Uranus is an ice giant with a blue-green appearance caused by methane in its atmosphere. Its rotation axis is tilted dramatically, creating unusually extreme seasonal illumination.',
      { 'Diameter' => 'About 51,100 km', 'Year length' => '84 Earth years', 'Mean distance' => '2.87 billion km', 'Atmosphere' => 'Hydrogen, helium, methane', 'Rotation tilt' => 'About 98°', 'Planet type' => 'Ice giant' },
      [source('Uranus facts', 'NASA', 'https://science.nasa.gov/uranus/facts/'), source('Uranus overview', 'NASA', 'https://science.nasa.gov/uranus/')],
      %w[saturn neptune jupiter], ['#b7ebed', '#477d9a']),
    object('neptune', 'Neptune', 'Planet', 'planet', '#5578e7', 0.54, [6.6, 0.12, -3], 'Solar System',
      'A distant, windy ice giant',
      'Neptune is the most distant planet from the Sun. It is a cold ice giant with a dynamic atmosphere and exceptionally fast winds; Voyager 2 flew past the planet in 1989.',
      { 'Diameter' => 'About 49,500 km', 'Year length' => '165 Earth years', 'Mean distance' => '4.5 billion km', 'Known moons' => '16 (catalog counts can change)', 'Atmosphere' => 'Hydrogen, helium, methane', 'First observed' => '1846' },
      [source('Neptune facts', 'NASA', 'https://science.nasa.gov/neptune/facts/'), source('Neptune overview', 'NASA', 'https://science.nasa.gov/neptune/')],
      %w[uranus saturn pluto], ['#6e9df8', '#18245f']),
    object('pluto', 'Pluto', 'Dwarf planet', 'dwarf-planet', '#c4a995', 0.2, [9.2, -0.2, -0.7], 'Kuiper Belt',
      'An icy world beyond Neptune',
      'Pluto is a dwarf planet in the Kuiper Belt. The New Horizons spacecraft revealed water-ice mountains, nitrogen-ice plains and a complex atmosphere during its 2015 flyby.',
      { 'Diameter' => 'About 2,377 km', 'Year length' => '248 Earth years', 'Mean distance' => 'About 5.9 billion km', 'Known moons' => '5', 'Region' => 'Kuiper Belt', 'Classification' => 'Dwarf planet' },
      [source('Pluto facts', 'NASA', 'https://science.nasa.gov/dwarf-planets/pluto/facts/'), source('New Horizons', 'NASA', 'https://science.nasa.gov/mission/new-horizons/')],
      %w[neptune ceres mars], ['#d3b9a9', '#6d4c54']),
    object('ceres', 'Ceres', 'Dwarf planet', 'dwarf-planet', '#b8b4b1', 0.16, [-4.4, -2.4, -4.6], 'Asteroid Belt',
      'The largest object in the asteroid belt',
      'Ceres is a dwarf planet located in the asteroid belt between Mars and Jupiter. NASA’s Dawn mission mapped its cratered surface and found evidence of salts and past or present briny activity.',
      { 'Diameter' => 'About 940 km', 'Region' => 'Main asteroid belt', 'Orbital period' => 'About 4.6 Earth years', 'Mission' => 'NASA Dawn', 'Surface' => 'Rock and ice' },
      [source('Ceres facts', 'NASA', 'https://science.nasa.gov/dwarf-planets/ceres/facts/'), source('Dawn mission', 'NASA', 'https://science.nasa.gov/mission/dawn/')],
      %w[mars jupiter pluto], ['#c2beb9', '#48495a']),
    object('europa', 'Europa', 'Moon', 'moon', '#d8bf9f', 0.22, [-2.0, -1.3, -3.6], 'Jupiter system',
      'An icy moon with a possible subsurface ocean',
      'Europa is one of Jupiter’s large moons. Evidence suggests a global salty ocean lies beneath its ice shell, making it a major target in the search for potentially habitable environments beyond Earth.',
      { 'Host planet' => 'Jupiter', 'Diameter' => 'About 3,122 km', 'Surface' => 'Water ice', 'Key question' => 'Ocean chemistry and habitability', 'Mission' => 'Europa Clipper launched in 2024' },
      [source('Europa overview', 'NASA', 'https://science.nasa.gov/jupiter/moons/europa/'), source('Europa Clipper', 'NASA', 'https://science.nasa.gov/mission/europa-clipper/')],
      %w[jupiter enceladus ganymede], ['#d9c4ad', '#554a4a']),
    object('ganymede', 'Ganymede', 'Moon', 'moon', '#b9b5ae', 0.24, [-1.7, 0.7, -4.1], 'Jupiter system',
      'The largest moon in the Solar System',
      'Ganymede is larger than the planet Mercury and is the only moon known to have its own intrinsic magnetic field. Evidence points to a large subsurface ocean.',
      { 'Host planet' => 'Jupiter', 'Diameter' => 'About 5,268 km', 'Distinction' => 'Largest Solar System moon', 'Magnetic field' => 'Present', 'Interior' => 'Possible subsurface ocean' },
      [source('Ganymede', 'NASA', 'https://science.nasa.gov/jupiter/moons/ganymede/'), source('JUICE mission', 'ESA', 'https://www.esa.int/Science_Exploration/Space_Science/Juice')],
      %w[jupiter europa titan], ['#bebbb5', '#424958']),
    object('titan', 'Titan', 'Moon', 'moon', '#dfb36e', 0.25, [1.4, 1.3, -3.2], 'Saturn system',
      'A world with hydrocarbon lakes and a thick atmosphere',
      'Saturn’s moon Titan has a dense nitrogen-rich atmosphere and surface lakes and seas of liquid methane and ethane. NASA’s Dragonfly mission is designed to explore this unusual organic-rich world.',
      { 'Host planet' => 'Saturn', 'Diameter' => 'About 5,150 km', 'Atmosphere' => 'Mostly nitrogen', 'Surface liquids' => 'Methane and ethane', 'Future mission' => 'Dragonfly' },
      [source('Titan overview', 'NASA', 'https://science.nasa.gov/saturn/moons/titan/'), source('Dragonfly', 'NASA', 'https://science.nasa.gov/mission/dragonfly/')],
      %w[saturn europa enceladus], ['#d8b477', '#72533a']),
    object('enceladus', 'Enceladus', 'Moon', 'moon', '#d9e6f7', 0.15, [1.9, -0.4, -3.6], 'Saturn system',
      'An icy moon that sprays water-rich plumes into space',
      'Enceladus is a small icy Saturnian moon with jets of water vapor and ice grains from its south polar region. The material provides evidence for a global subsurface ocean.',
      { 'Host planet' => 'Saturn', 'Diameter' => 'About 504 km', 'Surface' => 'Bright water ice', 'Key feature' => 'South-polar plumes', 'Scientific interest' => 'Ocean chemistry' },
      [source('Enceladus', 'NASA', 'https://science.nasa.gov/saturn/moons/enceladus/'), source('Cassini mission', 'NASA', 'https://science.nasa.gov/mission/cassini/')],
      %w[saturn europa titan], ['#e8f3ff', '#606a86']),
    object('proxima-centauri', 'Proxima Centauri', 'Star', 'star', '#ff9d73', 0.31, [-16, 3, -9], 'Alpha Centauri system',
      'The nearest known star to the Sun',
      'Proxima Centauri is a small red dwarf about 4.24 light-years from the Sun. It is part of the Alpha Centauri system and hosts at least one confirmed planet.',
      { 'Distance' => 'About 4.24 light-years', 'Star type' => 'Red dwarf', 'Known planets' => 'At least 1 confirmed', 'Constellation' => 'Centaurus', 'System' => 'Alpha Centauri' },
      [source('Proxima discovery research', 'ESO', 'https://www.eso.org/public/news/eso1629/'), source('NASA Exoplanet Archive', 'NASA / Caltech', EXO)],
      %w[proxima-centauri-b sun sirius], ['#ffb18b', '#4e2537']),
    object('proxima-centauri-b', 'Proxima Centauri b', 'Exoplanet', 'exoplanet', '#66dbe4', 0.2, [-14.9, 2.5, -8.8], 'Proxima Centauri',
      'A nearby planet orbiting a red dwarf',
      'Proxima Centauri b orbits the nearest known star to the Sun. It receives stellar energy in a range where surface liquid water could be possible under suitable conditions, but its atmosphere and surface environment are not established.',
      { 'Host star' => 'Proxima Centauri', 'Distance' => 'About 4.24 light-years', 'Year length' => 'About 11.2 Earth days', 'Discovery method' => 'Radial velocity', 'Habitability' => 'Surface conditions unknown' },
      [source('Discovery announcement', 'ESO', 'https://www.eso.org/public/news/eso1629/'), source('NASA Exoplanet Archive', 'NASA / Caltech', EXO)],
      %w[proxima-centauri trappist-1e kepler-186f], ['#8ee7e9', '#1d5266']),
    object('trappist-1e', 'TRAPPIST-1 e', 'Exoplanet', 'exoplanet', '#6ee4e2', 0.22, [-13.3, -4.3, -8], 'TRAPPIST-1',
      'An Earth-sized planet in a compact planetary system',
      'TRAPPIST-1 e is one of seven known planets orbiting an ultracool dwarf star. It is close to Earth in size and lies in the system’s temperate orbital region, but its atmosphere and liquid-water conditions remain under investigation.',
      { 'Host star' => 'TRAPPIST-1', 'Distance' => 'About 40 light-years', 'Size' => 'Close to Earth-sized', 'Year length' => 'About 6.1 Earth days', 'System planets' => '7 known', 'Atmosphere' => 'Under study' },
      [source('TRAPPIST-1 system', 'NASA', 'https://science.nasa.gov/exoplanets/trappist-1/'), source('NASA Exoplanet Archive', 'NASA / Caltech', EXO)],
      %w[proxima-centauri-b kepler-186f kepler-452-b], ['#80e7ed', '#234e77']),
    object('kepler-186f', 'Kepler-186 f', 'Exoplanet', 'exoplanet', '#9cb4ff', 0.23, [15, -4.5, -10], 'Kepler-186',
      'An Earth-sized planet found by transit',
      'Kepler-186 f was the first validated Earth-size planet found in the habitable zone of another star. Its atmospheric and surface conditions are not known.',
      { 'Host star' => 'Kepler-186', 'Distance' => 'Roughly 500 light-years', 'Discovery method' => 'Transit', 'Discovery year' => '2014', 'Size' => 'Earth-sized', 'Atmosphere' => 'Unknown' },
      [source('NASA Exoplanet Archive', 'NASA / Caltech', EXO), source('Exoplanet exploration', 'NASA', 'https://science.nasa.gov/exoplanets/')],
      %w[trappist-1e kepler-452-b proxima-centauri-b], ['#a4baff', '#303b7a']),
    object('kepler-452-b', 'Kepler-452 b', 'Exoplanet', 'exoplanet', '#dda5ff', 0.25, [17, 1.4, -12], 'Kepler-452',
      'A larger-than-Earth world orbiting a Sun-like star',
      'Kepler-452 b orbits a star similar to the Sun and was announced in 2015. It is larger than Earth, but its composition and surface conditions are not confirmed.',
      { 'Host star' => 'Kepler-452', 'Distance' => 'About 1,400 light-years', 'Discovery method' => 'Transit', 'Discovery year' => '2015', 'Size' => 'Larger than Earth', 'Composition' => 'Not confirmed' },
      [source('NASA Exoplanet Archive', 'NASA / Caltech', EXO), source('Exoplanet exploration', 'NASA', 'https://science.nasa.gov/exoplanets/')],
      %w[kepler-186f trappist-1e proxima-centauri-b], ['#dda5ff', '#403b87']),
    object('sirius', 'Sirius', 'Star system', 'star', '#b8d8ff', 0.4, [10, 3.8, -7], 'Canis Major',
      'The brightest star in Earth’s night sky',
      'Sirius is a binary star system about 8.6 light-years away. Its primary, Sirius A, is a luminous white main-sequence star; its companion, Sirius B, is a white dwarf.',
      { 'Distance' => 'About 8.6 light-years', 'System' => 'Binary star', 'Primary' => 'Sirius A', 'Companion' => 'Sirius B (white dwarf)', 'Constellation' => 'Canis Major', 'Apparent magnitude' => 'About −1.46' },
      [source('SIMBAD astronomical database', 'CDS Strasbourg', 'https://simbad.cds.unistra.fr/'), source('ESA/Hubble image archive', 'ESA / NASA', 'https://esahubble.org/images/')],
      %w[proxima-centauri vega betelgeuse], ['#d8e9ff', '#506b9b']),
    object('betelgeuse', 'Betelgeuse', 'Star', 'star', '#ff8969', 0.52, [-17, -1.5, -10], 'Orion',
      'A red supergiant in a late stage of stellar evolution',
      'Betelgeuse is a bright red supergiant in Orion. Its size and brightness vary, and astronomers study it to understand how massive stars change late in their lives.',
      { 'Star type' => 'Red supergiant', 'Distance' => 'Roughly 500–700 light-years', 'Constellation' => 'Orion', 'Brightness' => 'Variable', 'Color' => 'Red-orange' },
      [source('SIMBAD astronomical database', 'CDS Strasbourg', 'https://simbad.cds.unistra.fr/'), source('NASA science', 'NASA', NASA)],
      %w[orion-nebula vega sun], ['#ff9679', '#4c2036']),
    object('vega', 'Vega', 'Star', 'star', '#b4d1ff', 0.32, [5.5, 6.8, -10], 'Lyra',
      'A bright blue-white star in the northern sky',
      'Vega is a bright blue-white star in Lyra. It spins rapidly and is surrounded by a debris disk studied as a possible analogue to material involved in planet formation.',
      { 'Distance' => 'About 25 light-years', 'Star type' => 'A-type main-sequence star', 'Constellation' => 'Lyra', 'Color' => 'Blue-white', 'Rotation' => 'Rapid' },
      [source('SIMBAD astronomical database', 'CDS Strasbourg', 'https://simbad.cds.unistra.fr/'), source('NASA science', 'NASA', NASA)],
      %w[sirius betelgeuse sun], ['#dce9ff', '#536caa']),
    object('milky-way', 'Milky Way', 'Galaxy', 'galaxy', '#b4a4ff', 0.82, [-7, -5.5, -15], 'Local Group',
      'The galaxy that contains our Solar System',
      'The Milky Way is a barred spiral galaxy containing our Sun and billions of other stars. Its central region contains the supermassive black hole Sagittarius A*.',
      { 'Galaxy type' => 'Barred spiral', 'Diameter' => 'About 100,000 light-years', 'Sun location' => 'Orion Spur', 'Central black hole' => 'Sagittarius A*', 'Neighborhood' => 'Local Group' },
      [source('Galaxies overview', 'NASA', 'https://science.nasa.gov/universe/galaxies/'), source('Gaia mission', 'ESA', 'https://www.esa.int/Science_Exploration/Space_Science/Gaia')],
      %w[andromeda triangulum-galaxy sagittarius-a-star], ['#d4a5ff', '#202c69']),
    object('andromeda', 'Andromeda Galaxy', 'Galaxy', 'galaxy', '#c8a5ff', 0.95, [12, 5.1, -19], 'Local Group',
      'The nearest large spiral galaxy to the Milky Way',
      'The Andromeda Galaxy, also called M31, is a large spiral galaxy and a major member of the Local Group. Light from it takes about 2.5 million years to reach Earth.',
      { 'Catalog name' => 'Messier 31 (M31)', 'Distance' => 'About 2.5 million light-years', 'Galaxy type' => 'Spiral', 'Group' => 'Local Group', 'Notable feature' => 'Large stellar disk' },
      [source('Galaxies overview', 'NASA', 'https://science.nasa.gov/universe/galaxies/'), source('ESA/Hubble image archive', 'ESA / NASA', 'https://esahubble.org/images/')],
      %w[milky-way triangulum-galaxy sombrero-galaxy], ['#c9b1ff', '#232b73']),
    object('triangulum-galaxy', 'Triangulum Galaxy', 'Galaxy', 'galaxy', '#95cfff', 0.62, [4.2, -7, -20], 'Local Group',
      'A spiral galaxy in our galactic neighborhood',
      'The Triangulum Galaxy, or M33, is a spiral galaxy in the Local Group. It is smaller than both Andromeda and the Milky Way and is a target for research into star formation.',
      { 'Catalog name' => 'Messier 33 (M33)', 'Distance' => 'About 2.7 million light-years', 'Galaxy type' => 'Spiral', 'Group' => 'Local Group', 'Constellation' => 'Triangulum' },
      [source('Galaxies overview', 'NASA', 'https://science.nasa.gov/universe/galaxies/'), source('ESA/Hubble image archive', 'ESA / NASA', 'https://esahubble.org/images/')],
      %w[andromeda milky-way sombrero-galaxy], ['#95cfff', '#2b3472']),
    object('sombrero-galaxy', 'Sombrero Galaxy', 'Galaxy', 'galaxy', '#e6c3a1', 0.66, [-17, 5.2, -21], 'Virgo region',
      'A galaxy with a bright bulge and prominent dust lane',
      'The Sombrero Galaxy, M104, is known for a bright central bulge and a dark ring of dust. Its nearly edge-on orientation makes the dust lane prominent in telescope images.',
      { 'Catalog name' => 'Messier 104 (M104)', 'Distance' => 'About 30 million light-years', 'Constellation' => 'Virgo', 'Notable feature' => 'Prominent dust lane', 'Object type' => 'Galaxy' },
      [source('NASA Hubble science', 'NASA', 'https://science.nasa.gov/missions/hubble/'), source('ESA/Hubble image archive', 'ESA / NASA', 'https://esahubble.org/images/')],
      %w[andromeda triangulum-galaxy milky-way], ['#e3caad', '#665272']),
    object('orion-nebula', 'Orion Nebula', 'Nebula', 'nebula', '#a98aff', 0.72, [-13, -5.2, -13], 'Orion',
      'A nearby stellar nursery',
      'The Orion Nebula, M42, is a bright region of gas and dust where stars are forming. Its young stars illuminate and shape the surrounding cloud.',
      { 'Catalog name' => 'Messier 42 (M42)', 'Distance' => 'About 1,300 light-years', 'Object type' => 'Emission nebula', 'Constellation' => 'Orion', 'Main process' => 'Star formation' },
      [source('Hubble science', 'NASA', 'https://science.nasa.gov/missions/hubble/'), source('JWST image archive', 'NASA / ESA / CSA', 'https://webbtelescope.org/images')],
      %w[betelgeuse crab-nebula pillars-of-creation], ['#bd8fff', '#2a3f9a']),
    object('crab-nebula', 'Crab Nebula', 'Supernova remnant', 'nebula', '#83b8f6', 0.62, [14, -5.6, -14], 'Taurus',
      'The expanding remains of an observed supernova',
      'The Crab Nebula is the remnant of a supernova recorded by astronomers in 1054. A rapidly rotating neutron star at its center powers a broad range of emission.',
      { 'Catalog name' => 'Messier 1 (M1)', 'Distance' => 'About 6,500 light-years', 'Recorded event' => '1054 CE', 'Object type' => 'Supernova remnant', 'Central object' => 'Pulsar' },
      [source('Chandra X-ray Observatory', 'NASA', 'https://science.nasa.gov/mission/chandra/'), source('ESA/Hubble image archive', 'ESA / NASA', 'https://esahubble.org/images/')],
      %w[orion-nebula pillars-of-creation sagittarius-a-star], ['#89c9ff', '#3543a3']),
    object('pillars-of-creation', 'Pillars of Creation', 'Star-forming region', 'nebula', '#8da8ff', 0.7, [-2.7, 6, -17], 'Eagle Nebula',
      'Sculpted columns of gas and dust',
      'The Pillars of Creation are dense columns of gas and dust in the Eagle Nebula. Radiation and winds from young stars erode the clouds while new stars form within them.',
      { 'Location' => 'Eagle Nebula (M16)', 'Distance' => 'Roughly 6,500–7,000 light-years', 'Object type' => 'Star-forming region', 'Material' => 'Gas and dust', 'Observed by' => 'Hubble and JWST' },
      [source('Hubble missions', 'NASA', 'https://science.nasa.gov/missions/hubble/'), source('JWST image archive', 'NASA / ESA / CSA', 'https://webbtelescope.org/images')],
      %w[orion-nebula crab-nebula betelgeuse], ['#b2a6ff', '#3c4fa0']),
    object('sagittarius-a-star', 'Sagittarius A*', 'Supermassive black hole', 'black-hole', '#bd92ff', 0.61, [-4.5, 1.3, -10], 'Milky Way center',
      'The black hole at the center of our galaxy',
      'Sagittarius A* is the compact radio source associated with the supermassive black hole at the center of the Milky Way. The Event Horizon Telescope collaboration released the first image of its shadow in 2022.',
      { 'Mass' => 'About 4 million Suns', 'Distance' => 'About 26,000 light-years', 'Object type' => 'Supermassive black hole', 'Location' => 'Galactic center', 'First shadow image' => '2022' },
      [source('Event Horizon Telescope', 'EHT Collaboration', 'https://eventhorizontelescope.org/'), source('Milky Way center results', 'ESO', 'https://www.eso.org/public/news/eso2208-eht-mw/')],
      %w[milky-way andromeda m87-star]),
    object('m87-star', 'M87*', 'Supermassive black hole', 'black-hole', '#d6a6ff', 0.69, [20, 2.7, -19], 'Messier 87',
      'The first black hole captured in an image',
      'M87* is the supermassive black hole at the center of the galaxy Messier 87. In 2019, the Event Horizon Telescope released the first image of a black hole shadow, revealing a bright ring of emission around a dark central region.',
      { 'Host galaxy' => 'Messier 87', 'Object type' => 'Supermassive black hole', 'Mass' => 'Billions of solar masses', 'First image released' => '2019', 'Observation' => 'Event Horizon Telescope' },
      [source('First black hole image', 'EHT Collaboration', 'https://eventhorizontelescope.org/'), source('M87 results', 'ESO', 'https://www.eso.org/public/images/eso1907a/')],
      %w[sagittarius-a-star milky-way andromeda]),
    object('halleys-comet', 'Halley’s Comet', 'Periodic comet', 'asteroid', '#a3e0e2', 0.18, [8, -2.3, 4], 'Solar System',
      'A periodic comet visible from Earth about once every 76 years',
      'Halley’s Comet is a periodic comet that returns to the inner Solar System about every 75–76 years. Its last perihelion was in 1986 and its next is expected in 2061.',
      { 'Type' => 'Periodic comet', 'Orbital period' => 'About 75–76 years', 'Last perihelion' => '1986', 'Next perihelion' => 'Expected 2061', 'Origin' => 'Outer Solar System' },
      [source('Comet observation resources', 'NASA', NASA), source('Minor Planet Center', 'IAU / Smithsonian', 'https://www.minorplanetcenter.net/')],
      %w[sun jupiter pluto]),
    object('observable-universe', 'Observable Universe', 'Cosmological horizon', 'deep', '#93a6ff', 0.78, [0, 0, -32], 'Cosmology',
      'The observable region of the universe',
      'The observable universe is the region from which light has had time to reach us since the early universe. It is not necessarily the whole universe, whose full extent is unknown.',
      { 'Age of universe' => 'About 13.8 billion years', 'Observable radius' => 'About 46.5 billion light-years', 'Contents' => 'Galaxies, matter, radiation and dark components', 'Limit' => 'Cosmic particle horizon' },
      [source('Universe overview', 'NASA', 'https://science.nasa.gov/universe/'), source('Planck cosmology', 'ESA', 'https://www.esa.int/Science_Exploration/Space_Science/Planck')],
      %w[milky-way andromeda sagittarius-a-star])
  ].freeze

  BY_ID = CATALOG.each_with_object({}) { |item, memo| memo[item[:id]] = item }.freeze

  def classify(title, text = '')
    phrase = "#{title} #{text}".downcase
    return 'black-hole' if phrase.match?(/black hole|sagittarius a\*|m87\*/)
    return 'galaxy' if phrase.match?(/galaxy|galaxies|milky way|andromeda|sombrero/)
    return 'deep' if phrase.match?(/observable universe|cosmolog|deep space/)
    return 'nebula' if phrase.match?(/nebula|supernova remnant|pillars of creation|pulsar/)
    return 'exoplanet' if phrase.match?(/exoplanet|kepler-\d|trappist|proxima centauri [bc]|planet [a-z]$/)
    return 'moon' if phrase.match?(/moon|satellite|europa|titan|enceladus|ganymede|io\b/)
    return 'planet' if phrase.match?(/\bplanet\b|mercury|venus|earth|mars|jupiter|saturn|uranus|neptune|pluto/)
    return 'star' if phrase.match?(/\bstar\b|sun|sirius|vega|betelgeuse|centauri/)
    'deep'
  end

  def wiki_search(query, limit = 6)
    params = URI.encode_www_form(action: 'query', list: 'search', srsearch: query, format: 'json', utf8: 1, srlimit: limit)
    uri = URI("https://en.wikipedia.org/w/api.php?#{params}")
    response = request(uri)
    return [] unless response && response.code.to_i == 200

    payload = JSON.parse(response.body)
    entries = payload.dig('query', 'search') || []
    entries.map do |entry|
      title = entry['title'].to_s
      snippet = entry['snippet'].to_s.gsub(/<[^>]*>/, '').gsub(/&quot;/, '"').gsub(/&#039;/, "'").gsub(/&amp;/, '&')
      category = classify(title, snippet)
      slug = title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
      {
        id: "wiki-#{slug}", name: title, type: category_title(category), category: category,
        color: category_color(category), size: 0.3,
        subtitle: 'Knowledge index · Wikipedia reference',
        description: snippet, external: true,
        sources: [
          source('Read the reference', 'Wikipedia', "#{WIKI}#{URI.encode_www_form_component(title).gsub('+', '_')}"),
          source('Explore this topic at NASA', 'NASA', "https://science.nasa.gov/search/?q=#{URI.encode_www_form_component(title)}")
        ]
      }
    end
  rescue StandardError => e
    warn "Astra Wikipedia search failed: #{e.class}: #{e.message}"
    []
  end

  def wiki_lookup(title)
    safe_title = title.to_s.strip
    return nil if safe_title.empty? || safe_title.length > 180

    path = URI::DEFAULT_PARSER.escape(safe_title.tr(' ', '_'), /[^A-Za-z0-9\-_.!~*'()]/)
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{path}")
    response = request(uri, 'Accept' => 'application/json')
    return nil unless response && response.code.to_i == 200

    record = JSON.parse(response.body)
    page_title = record['title'] || safe_title
    summary = record['extract'].to_s
    category = classify(page_title, summary)
    slug = page_title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
    {
      id: "wiki-#{slug}", name: page_title, type: category_title(category), category: category,
      color: category_color(category), size: 0.3, position: nil, map_frame: 'universe', map_status: 'unplotted',
      subtitle: record['description'] || 'External knowledge reference',
      description: summary, descriptionLong: summary, external: true,
      facts: { 'Reference type' => category_title(category), 'Index' => 'Wikipedia / Wikimedia', 'Scientific context' => 'See linked source pages' },
      sources: [
        source('Read full reference', 'Wikipedia', "#{WIKI}#{URI.encode_www_form_component(page_title).gsub('+', '_')}"),
        source('Explore this topic at NASA', 'NASA', "https://science.nasa.gov/search/?q=#{URI.encode_www_form_component(page_title)}"),
        source('Search astronomy literature', 'SIMBAD / CDS', "https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=#{URI.encode_www_form_component(page_title)}")
      ],
      related: []
    }
  rescue StandardError => e
    warn "Astra Wikipedia lookup failed: #{e.class}: #{e.message}"
    nil
  end

  def request(uri, extra_headers = {}, open_timeout: 2.0, read_timeout: 10.0)
    allowed_hosts = %w[
      en.wikipedia.org exoplanetarchive.ipac.caltech.edu
      ssd-api.jpl.nasa.gov ssd.jpl.nasa.gov cds.unistra.fr gea.esac.esa.int
    ]
    return nil unless uri.is_a?(URI::HTTPS) && allowed_hosts.include?(uri.host)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout
    http.write_timeout = 2.0 if http.respond_to?(:write_timeout=)
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'AstraUniverseExplorer/1.1 (educational astronomy catalog; contact: repository owner)'
    extra_headers.each { |key, value| request[key] = value }
    http.request(request)
  rescue StandardError => e
    warn "Astra network request failed: #{e.class}: #{e.message}"
    nil
  end

  def category_title(category)
    { 'planet' => 'Planet', 'dwarf-planet' => 'Dwarf planet', 'moon' => 'Natural satellite',
      'exoplanet' => 'Exoplanet', 'star' => 'Star', 'galaxy' => 'Galaxy',
      'nebula' => 'Nebula / deep space', 'deep' => 'Deep space / cosmology', 'black-hole' => 'Black hole', 'asteroid' => 'Small Solar System body' }[category] || 'Astronomical reference'
  end

  def category_color(category)
    { 'planet' => '#7a9bf7', 'dwarf-planet' => '#c7b29a', 'moon' => '#c0cbdf',
      'exoplanet' => '#6bdce1', 'star' => '#ffbd83', 'galaxy' => '#b6a3ff',
      'nebula' => '#a48bff', 'deep' => '#93a6ff', 'black-hole' => '#bd92ff', 'asteroid' => '#97d8d9' }[category] || '#a7b3ff'
  end

  def safe_catalog_query(query)
    query.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
         .gsub(/[^A-Za-z0-9 ._+\-]/, ' ').squeeze(' ').strip[0, 90]
  end

  def exoplanet_search(query, limit = 8)
    safe = safe_catalog_query(query)
    return [] if safe.length < 2
    escaped = safe.gsub("'", "''")
    adql = "select top #{[[limit.to_i, 1].max, 20].min} pl_name,hostname,discoverymethod,disc_year,sy_dist,pl_orbper,pl_rade,pl_bmasse,ra,dec from pscomppars where pl_name like '%#{escaped}%' or hostname like '%#{escaped}%' order by pl_name asc"
    uri = URI("https://exoplanetarchive.ipac.caltech.edu/TAP/sync?#{URI.encode_www_form(query: adql, format: 'json')}")
    response = request(uri, 'Accept' => 'application/json')
    return [] unless response && response.code.to_i == 200

    payload = JSON.parse(response.body)
    if payload.is_a?(Hash) && payload['data'].is_a?(Array)
      fields = Array(payload['metadata']).map { |field| field.is_a?(Hash) ? field['name'].to_s : '' }
      rows = payload['data'].map do |row|
        row.is_a?(Hash) ? row.transform_keys(&:to_s) : (row.is_a?(Array) ? fields.zip(row).to_h : nil)
      end.compact
    elsif payload.is_a?(Array)
      rows = payload
    else
      rows = []
    end
    rows.filter_map do |row|
      next unless row.is_a?(Hash)
      row = row.transform_keys(&:to_s)
      name = row['pl_name'].to_s
      next if name.empty?
      host = row['hostname'].to_s
      ra = numeric(row['ra'])
      dec = numeric(row['dec'])
      distance_pc = numeric(row['sy_dist'])
      distance_ly = distance_pc ? distance_pc * 3.26156 : nil
      position = radec_position(ra, dec, distance_ly)
      id = "nasa-exoplanet-#{name.downcase.gsub(/[^a-z0-9]+/, '-')}"
      facts = {
        'Host star' => host.empty? ? 'Not listed' : host,
        'Discovery method' => row['discoverymethod'],
        'Discovery year' => row['disc_year'],
        'Distance from Earth' => distance_ly ? "#{distance_ly.round(2)} light-years" : nil,
        'Orbital period' => with_unit(row['pl_orbper'], 'days'),
        'Radius' => with_unit(row['pl_rade'], 'Earth radii'),
        'Mass' => with_unit(row['pl_bmasse'], 'Earth masses')
      }.compact
      sources = [
        source('NASA Exoplanet Archive record', 'NASA Exoplanet Science Institute',
               "https://exoplanetarchive.ipac.caltech.edu/"),
        source('NASA Exoplanet Archive TAP data', 'NASA / Caltech',
               "https://exoplanetarchive.ipac.caltech.edu/TAP/sync?#{URI.encode_www_form(query: "select * from pscomppars where pl_name='#{escaped}'", format: 'csv')}")
      ]
      item = {
        id: id, name: name, type: 'Exoplanet', category: 'exoplanet', color: '#6bdce1',
        size: 0.22, position: position, ra_deg: ra, dec_deg: dec, distance_ly: distance_ly,
        map_frame: 'universe', map_status: position ? 'plotted' : 'unplotted',
        position_accuracy: position ? 'Host-star coordinates and distance from NASA Exoplanet Archive' : 'Archive record does not provide a complete coordinate + distance pair',
        position_source: 'NASA Exoplanet Archive · Planetary Systems Composite Parameters',
        subtitle: host.empty? ? 'Confirmed planet · NASA Exoplanet Archive' : "Orbits #{host}",
        system: host, host: host, description: "#{name} is listed in NASA’s Planetary Systems Composite Parameters catalog. Its discovery metadata and published physical parameters are shown below; unknown quantities are omitted.",
        facts: facts, sources: sources, related: []
      }
      item[:orbital_period_days] = numeric(row['pl_orbper'])
      item[:radius_earth] = numeric(row['pl_rade'])
      item[:mass_earth] = numeric(row['pl_bmasse'])
      item
    end
  rescue StandardError => e
    warn "NASA Exoplanet Archive search failed: #{e.class}: #{e.message}"
    []
  end


  def exoplanet_archive_page(limit: 40, after: nil, query: nil)
    count = numeric(limit)&.to_i || 40
    count = [[count, 10].max, 100].min
    cursor = safe_catalog_query(after)
    term = safe_catalog_query(query)
    filters = []
    filters << "pl_name > '#{cursor.gsub("'", "''")}'" unless cursor.empty?
    unless term.empty?
      escaped_term = term.gsub("'", "''")
      filters << "(pl_name like '%#{escaped_term}%' or hostname like '%#{escaped_term}%')"
    end
    where = filters.empty? ? '' : " where #{filters.join(' and ')}"
    adql = "select top #{count + 1} pl_name,hostname,discoverymethod,disc_year,sy_dist,pl_orbper,pl_rade,pl_bmasse,ra,dec from pscomppars#{where} order by pl_name asc"
    uri = URI("https://exoplanetarchive.ipac.caltech.edu/TAP/sync?#{URI.encode_www_form(query: adql, format: 'json')}")
    response = request(uri, 'Accept' => 'application/json')
    return { objects: [], next_cursor: nil, has_more: false, source_status: 'unavailable' } unless response && response.code.to_i == 200

    payload = JSON.parse(response.body)
    if payload.is_a?(Hash) && payload['data'].is_a?(Array)
      fields = Array(payload['metadata']).map { |field| field.is_a?(Hash) ? field['name'].to_s : '' }
      rows = payload['data'].map do |row|
        row.is_a?(Hash) ? row.transform_keys(&:to_s) : (row.is_a?(Array) ? fields.zip(row).to_h : nil)
      end.compact
    elsif payload.is_a?(Array)
      rows = payload
    else
      rows = []
    end
    has_more = rows.length > count
    rows = rows.first(count)
    objects = rows.filter_map do |row|
      next unless row.is_a?(Hash)
      row = row.transform_keys(&:to_s)
      name = row['pl_name'].to_s
      next if name.empty?
      host = row['hostname'].to_s
      ra = numeric(row['ra'])
      dec = numeric(row['dec'])
      distance_pc = numeric(row['sy_dist'])
      distance_ly = distance_pc ? distance_pc * 3.26156 : nil
      position = radec_position(ra, dec, distance_ly)
      {
        id: "nasa-exoplanet-#{name.downcase.gsub(/[^a-z0-9]+/, '-')}",
        name: name, type: 'Exoplanet', category: 'exoplanet', color: '#6bdce1', size: 0.09,
        position: position, ra_deg: ra, dec_deg: dec, distance_ly: distance_ly,
        map_frame: 'universe', map_status: position ? 'plotted' : 'unplotted',
        position_accuracy: position ? 'Host-star sky coordinates and distance from NASA Exoplanet Archive' : 'Archive does not provide a complete coordinate + distance pair',
        position_source: 'NASA Exoplanet Archive · Planetary Systems Composite Parameters',
        subtitle: host.empty? ? 'Confirmed planet · NASA Exoplanet Archive' : "Orbits #{host}",
        system: host, host: host,
        description: "#{name} is listed in NASA’s Planetary Systems Composite Parameters table. Only published values available in the returned record are shown.",
        facts: {
          'Host star' => host.empty? ? nil : host,
          'Discovery method' => row['discoverymethod'],
          'Discovery year' => row['disc_year'],
          'Distance from Earth' => distance_ly ? "#{distance_ly.round(2)} light-years" : nil,
          'Orbital period' => with_unit(row['pl_orbper'], 'days'),
          'Radius' => with_unit(row['pl_rade'], 'Earth radii'),
          'Mass' => with_unit(row['pl_bmasse'], 'Earth masses')
        }.compact,
        sources: [
          source('NASA Exoplanet Archive record', 'NASA Exoplanet Science Institute', 'https://exoplanetarchive.ipac.caltech.edu/'),
          source('Planetary Systems Composite Parameters', 'NASA / Caltech', "https://exoplanetarchive.ipac.caltech.edu/TAP/sync?#{URI.encode_www_form(query: "select * from pscomppars where pl_name='#{name.gsub("'", "''")}'", format: 'csv')}")
        ],
        related: [], catalog_source: 'NASA Exoplanet Archive'
      }
    end
    { objects: objects, count: objects.length, next_cursor: has_more ? rows.last&.dig('pl_name') : nil,
      has_more: has_more, source_status: 'ok', source: 'NASA Exoplanet Archive TAP · pscomppars',
      page_is_last: !has_more,
      note: 'Cursor-paginated results from this archive table; the current page is not the complete archive or a catalogue of all known object types.' }
  rescue StandardError => e
    warn "NASA Exoplanet Archive page failed: #{e.class}: #{e.message}"
    { objects: [], next_cursor: nil, has_more: false, source_status: 'unavailable' }
  end


  def small_body_archive_page(limit: 40, offset: 0, kind: 'all', neo: false)
    count = numeric(limit)&.to_i || 40
    count = [[count, 10].max, 100].min
    start = numeric(offset)&.to_i || 0
    start = [[start, 0].max, 2_000_000].min
    selected_kind = %w[asteroid comet all].include?(kind.to_s) ? kind.to_s : 'all'
    fields = %w[spkid full_name kind pdes name class neo pha moid orbit_id epoch e a q i om w ma tp per ad H diameter condition_code n_obs_used source soln_date]
    parameters = { fields: fields.join(','), limit: count + 1, 'limit-from' => start, sort: 'spkid' }
    parameters['sb-kind'] = selected_kind == 'asteroid' ? 'a' : 'c' unless selected_kind == 'all'
    parameters['sb-group'] = 'neo' if neo
    uri = URI("https://ssd-api.jpl.nasa.gov/sbdb_query.api?#{URI.encode_www_form(parameters)}")
    response = request(uri, 'Accept' => 'application/json', read_timeout: 14.0)
    return { objects: [], offset: start, next_offset: nil, has_more: false, source_status: 'unavailable' } unless response && response.code.to_i == 200

    payload = JSON.parse(response.body)
    return { objects: [], offset: start, next_offset: nil, has_more: false, source_status: 'unavailable', error: payload['message'] } if payload['code'] && payload['code'].to_i >= 400

    field_names = Array(payload['fields']).map(&:to_s)
    rows = Array(payload['data']).filter_map do |row|
      next unless row.is_a?(Array)
      field_names.zip(row).to_h
    end
    has_more = rows.length > count
    page = rows.first(count)
    objects = page.filter_map do |row|
      name = (row['full_name'] || row['name'] || row['pdes']).to_s.strip
      designation = row['pdes'].to_s.strip
      spkid = row['spkid'].to_s.strip
      next if name.empty?
      is_comet = row['kind'].to_s.start_with?('c')
      category = is_comet ? 'asteroid' : 'asteroid'
      object_id = "jpl-sbdb-#{(spkid.empty? ? designation : spkid).gsub(/[^A-Za-z0-9]+/, '-')}"
      facts = {
        'Primary designation' => designation.empty? ? nil : designation,
        'SPK ID' => spkid.empty? ? nil : spkid,
        'Body class' => is_comet ? 'Comet' : 'Asteroid',
        'Orbit class' => row['class'],
        'Near-Earth object' => row['neo'],
        'Potentially hazardous flag' => row['pha'],
        'Minimum orbit intersection distance' => with_unit(row['moid'], 'AU'),
        'Semi-major axis' => with_unit(row['a'], 'AU'),
        'Perihelion distance' => with_unit(row['q'], 'AU'),
        'Aphelion distance' => with_unit(row['ad'], 'AU'),
        'Eccentricity' => numeric(row['e'])&.round(6),
        'Inclination' => with_unit(row['i'], 'degrees'),
        'Orbital period' => with_unit(row['per'], 'days'),
        'Absolute magnitude' => numeric(row['H'])&.round(3),
        'Estimated diameter' => with_unit(row['diameter'], 'km'),
        'Orbit solution' => row['orbit_id'],
        'Observations used' => row['n_obs_used'],
        'Solution date' => row['soln_date']
      }.compact
      {
        id: object_id, name: name, type: is_comet ? 'Comet / small body' : 'Asteroid / small body',
        category: category, color: '#9ed7da', size: 0.055, position: nil, local_position_au: nil,
        map_frame: 'solar-system', map_status: 'unplotted',
        position_accuracy: 'Bulk orbital record does not include a current position vector; request the object detail for a JPL Horizons vector.',
        position_source: 'NASA/JPL Small-Body Database Query API',
        catalog_source: 'JPL Small-Body Database', pdes: designation, spkid: spkid,
        subtitle: is_comet ? 'JPL Small-Body Database · comet' : 'JPL Small-Body Database · asteroid',
        system: 'Solar System', external: true,
        description: "#{name} is listed in NASA/JPL’s Small-Body Database. Orbital and physical parameters are included where the archive returns them. The bulk record is not treated as a current physical position.",
        facts: facts,
        sources: [
          source('JPL Small-Body Database record', 'NASA / JPL', "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=#{URI.encode_www_form_component(designation.empty? ? name : designation)}"),
          source('JPL SBDB Query API', 'NASA / JPL', 'https://ssd-api.jpl.nasa.gov/doc/sbdb_query.html'),
          source('JPL Horizons ephemerides', 'NASA / JPL', 'https://ssd-api.jpl.nasa.gov/doc/horizons.html')
        ], related: []
      }
    end
    { objects: objects, count: objects.length, offset: start, next_offset: has_more ? start + count : nil,
      has_more: has_more, source_status: 'ok', source: 'NASA/JPL Small-Body Database Query API',
      note: 'Offset-paginated catalogue data. Current 3D positions are fetched per object from Horizons on demand.' }
  rescue StandardError => e
    warn "JPL small-body archive page failed: #{e.class}: #{e.message}"
    { objects: [], offset: start || 0, next_offset: nil, has_more: false, source_status: 'unavailable' }
  end

  def small_body_detail(query)
    results = jpl_small_body_search(query)
    return nil if results.empty?
    object = results.first
    object[:catalog_source] = 'JPL Small-Body Database'
    object[:size] = 0.09
    vector_au = object[:local_position_au]
    object[:distance_from_sun_au] = Math.sqrt(vector_au.sum { |value| value.to_f**2 }) if vector_au
    object[:facts] ||= {}
    object[:facts]['Heliocentric distance (vector epoch)'] = "#{object[:distance_from_sun_au].round(6)} AU" if object[:distance_from_sun_au]
    object
  end

  def close_approach_page(days: 90, distance_au: 0.05, limit: 30)
    span = [[numeric(days)&.to_i || 90, 1].max, 3650].min
    distance = numeric(distance_au) || 0.05
    return { events: [], source_status: 'invalid' } unless distance.finite? && distance.between?(0.001, 5.0)
    count = [[numeric(limit)&.to_i || 30, 5].max, 80].min
    date_min = Date.today.iso8601
    date_max = (Date.today + span).iso8601
    params = {
      'date-min' => date_min, 'date-max' => date_max, 'dist-max' => distance.to_s,
      sort: 'date', limit: count, fullname: 1, diameter: 1, 'ca-time' => 'cd'
    }
    uri = URI("https://ssd-api.jpl.nasa.gov/cad.api?#{URI.encode_www_form(params)}")
    response = request(uri, 'Accept' => 'application/json', read_timeout: 12.0)
    return { events: [], source_status: 'unavailable', days: span, distance_au: distance } unless response && response.code.to_i == 200

    payload = JSON.parse(response.body)
    fields = Array(payload['fields']).map(&:to_s)
    events = Array(payload['data']).filter_map do |row|
      next unless row.is_a?(Array)
      data = fields.zip(row).to_h
      designation = (data['des'] || data['fullname']).to_s
      next if designation.empty?
      event_date = (data['cd'] || data['jd']).to_s
      dist = numeric(data['dist'])
      { id: "cad-#{designation.gsub(/[^A-Za-z0-9]+/, '-')}-#{event_date.gsub(/[^A-Za-z0-9]+/, '-')}",
        designation: designation, name: data['fullname'] || designation,
        date: data['cd'], julian_date: data['jd'], distance_au: dist,
        distance_lunar: numeric(data['dist_ld']), relative_velocity_km_s: numeric(data['v_rel']),
        absolute_magnitude: numeric(data['h']), diameter_km: numeric(data['diameter']),
        body: data['body'] || 'Earth', epoch: data['cd'],
        source: 'NASA/JPL Close-Approach Data API',
        object_query: designation,
        facts: {
          'Close-approach time (TDB)' => data['cd'] || data['jd'],
          'Closest approach' => with_unit(data['dist'], 'AU'),
          'Distance' => with_unit(data['dist_ld'], 'lunar distances'),
          'Relative velocity' => with_unit(data['v_rel'], 'km/s'),
          'Absolute magnitude' => data['h'],
          'Estimated diameter' => with_unit(data['diameter'], 'km'),
          'Target body' => data['body'] || 'Earth'
        }.compact,
        sources: [
          source('JPL close-approach record', 'NASA / JPL', "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=#{URI.encode_www_form_component(designation)}"),
          source('Close-Approach Data API', 'NASA / JPL', 'https://ssd-api.jpl.nasa.gov/doc/cad.html')
        ] }
    end
    { events: events, count: events.length, days: span, distance_au: distance,
      source_status: 'ok', source: 'NASA/JPL Close-Approach Data API',
      range: { from: date_min, to: date_max }, note: 'Approach events are forecasts in the returned model, not collision predictions. Distances and times have uncertainties in the source catalog.' }
  rescue StandardError => e
    warn "JPL close approach query failed: #{e.class}: #{e.message}"
    { events: [], source_status: 'unavailable', days: span || 90, distance_au: distance_au || 0.05 }
  end

  def archive_coverage
    cache_key = :coverage_summary
    if defined?(@coverage_cache) && @coverage_cache && Time.now - @coverage_cached_at < 900
      return @coverage_cache
    end
    work = [
      Thread.new do
        uri = URI("https://ssd-api.jpl.nasa.gov/sbdb_query.api?#{URI.encode_www_form(info: 'count')}")
        response = request(uri, 'Accept' => 'application/json', read_timeout: 12.0)
        payload = response && response.code.to_i == 200 ? JSON.parse(response.body) : nil
        counts = payload&.dig('info', 'count')
        if counts
          { id: 'jpl-sbdb', name: 'JPL Small-Body Database', status: 'online',
            families: { numbered_asteroids: numeric(counts['an'])&.to_i, unnumbered_asteroids: numeric(counts['au'])&.to_i,
                        numbered_comets: numeric(counts['cn'])&.to_i, unnumbered_comets: numeric(counts['cu'])&.to_i },
            count_scope: 'Archive count by numbered status and object type', url: 'https://ssd.jpl.nasa.gov/' }
        else
          { id: 'jpl-sbdb', name: 'JPL Small-Body Database', status: 'unavailable',
            count_scope: 'Live archive count unavailable', url: 'https://ssd.jpl.nasa.gov/' }
        end
      rescue StandardError
        { id: 'jpl-sbdb', name: 'JPL Small-Body Database', status: 'unavailable', url: 'https://ssd.jpl.nasa.gov/' }
      end,
      Thread.new do
        adql = 'select count(*) as total from pscomppars'
        uri = URI("https://exoplanetarchive.ipac.caltech.edu/TAP/sync?#{URI.encode_www_form(query: adql, format: 'json')}")
        response = request(uri, 'Accept' => 'application/json', read_timeout: 15.0)
        payload = response && response.code.to_i == 200 ? JSON.parse(response.body) : nil
        value = if payload.is_a?(Hash) && payload['data'].is_a?(Array)
                  fields = Array(payload['metadata']).map { |field| field['name'].to_s }
                  row = Array(payload['data']).first
                  index = fields.index('total') || 0
                  row.is_a?(Array) ? numeric(row[index])&.to_i : nil
                elsif payload.is_a?(Array) && payload.first.is_a?(Hash)
                  numeric(payload.first['total'])&.to_i
                end
        { id: 'nasa-exoplanet-archive', name: 'NASA Exoplanet Archive', status: value ? 'online' : 'unavailable',
          record_count: value, count_scope: 'Rows in the PSCompPars table; table coverage and default parameter availability can change',
          url: 'https://exoplanetarchive.ipac.caltech.edu/' }
      rescue StandardError
        { id: 'nasa-exoplanet-archive', name: 'NASA Exoplanet Archive', status: 'unavailable',
          count_scope: 'Live archive count unavailable', url: 'https://exoplanetarchive.ipac.caltech.edu/' }
      end
    ]
    source_statuses = work.map do |thread|
      thread.value
    rescue StandardError
      { status: 'unavailable' }
    end
    result = {
      generated_at_utc: Time.now.utc.iso8601,
      local_curated_records: CATALOG.length,
      note: 'Counts are source-specific and should not be summed: catalogs overlap and cover different object classes. Gaia and CDS are exposed as query services; no unbounded full-table download is performed.',
      sources: source_statuses + [
        { id: 'gaia-dr3', name: 'ESA Gaia DR3', status: 'queryable', scope: 'Bounded magnitude-limited sample and on-demand sky cones; full table is not copied into Astra', url: 'https://gea.esac.esa.int/archive/' },
        { id: 'cds-sesame', name: 'CDS Sesame / SIMBAD / NED / VizieR', status: 'queryable', scope: 'Name resolution and coordinate records; no unified master object count', url: 'https://cds.unistra.fr/doc/sesame.htx' },
        { id: 'wikipedia', name: 'Wikimedia', status: 'supplementary', scope: 'Contextual full-text discovery, not measurement authority', url: 'https://www.wikipedia.org/' }
      ]
    }
    @coverage_cache = result
    @coverage_cached_at = Time.now
    result
  rescue StandardError => e
    warn "Astra source coverage failed: #{e.class}: #{e.message}"
    { generated_at_utc: Time.now.utc.iso8601, local_curated_records: CATALOG.length, sources: [], error: 'Coverage services are temporarily unavailable.' }
  end

  def numeric(value)
    number = Float(value)
    number.finite? ? number : nil
  rescue ArgumentError, TypeError
    nil
  end

  def with_unit(value, unit)
    number = numeric(value)
    number ? "#{number.round(4)} #{unit}" : nil
  end

  def jpl_small_body_search(query)
    safe = safe_catalog_query(query)
    return [] if safe.length < 2
    uri = URI("https://ssd-api.jpl.nasa.gov/sbdb.api?#{URI.encode_www_form(sstr: safe, 'phys-par' => '1', 'alt-des' => '1')}")
    response = request(uri, 'Accept' => 'application/json')
    return [] unless response && response.code.to_i == 200

    payload = JSON.parse(response.body)
    record = payload['object']
    return [] unless record.is_a?(Hash)
    name = (record['name'] || record['fullname'] || record['des']).to_s.strip
    return [] if name.empty? || payload['error']

    orbit = payload['orbit'].is_a?(Hash) ? payload['orbit'] : {}
    elements = Array(orbit['elements'])
    facts = {}
    facts['Designation'] = record['des'] if record['des']
    facts['SPK ID'] = record['spkid'] if record['spkid']
    facts['Orbit epoch'] = orbit['epoch'] if orbit['epoch']
    { 'e' => 'Orbital eccentricity', 'a' => 'Semi-major axis', 'q' => 'Perihelion distance',
      'i' => 'Inclination', 'diameter' => 'Diameter', 'H' => 'Absolute magnitude' }.each do |key, label|
      entry = elements.find { |field| field['name'].to_s.casecmp(key).zero? }
      facts[label] = [entry['value'], entry['units']].compact.join(' ') if entry && entry['value']
    end
    Array(payload['phys_par']).each do |field|
      next unless field.is_a?(Hash)
      key = field['name'].to_s
      next unless %w[diameter H albedo rotation_period].include?(key)
      facts[key.tr('_', ' ').capitalize] = [field['value'], field['units']].compact.join(' ') if field['value']
    end
    category = 'asteroid'
    position = nil
    command = record['spkid'] || (record['des'] && "DES=#{record['des']};")
    if command
      vector = horizons_position(command)
      if vector
        position = vector.map { |component| component / AU_PER_LIGHT_YEAR }
      end
    end
    encoded_name = URI.encode_www_form_component(record['des'] || name)
    {
      id: "jpl-sbdb-#{(record['spkid'] || record['des'] || name).to_s.gsub(/[^A-Za-z0-9]+/, '-')}",
      name: name, type: 'Small Solar System body', category: category, color: '#9ed7da',
      size: 0.09, position: position, local_position_au: position && position.map { |component| component * AU_PER_LIGHT_YEAR },
      map_frame: 'solar-system', map_status: position ? 'plotted' : 'unplotted',
      catalog_source: 'JPL Small-Body Database', pdes: record['des'] || record['pdes'], spkid: record['spkid'],
      position_accuracy: position ? 'JPL Horizons ICRF vector at current UTC date' : 'Current heliocentric vector not available; object is searchable but not plotted',
      position_source: 'JPL Small-Body Database / Horizons',
      subtitle: "JPL Small-Body Database · #{record['spkid'] || record['des']}",
      description: "#{name} is indexed by NASA/JPL’s Small-Body Database. Orbital and physical values are included only when returned by the service.",
      facts: facts,
      sources: [
        source('JPL Small-Body Database record', 'NASA / JPL', "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=#{encoded_name}"),
        source('JPL Horizons', 'NASA / JPL', 'https://ssd.jpl.nasa.gov/horizons/')
      ], related: []
    }
  rescue StandardError => e
    warn "JPL small-body search failed: #{e.class}: #{e.message}"
    []
  end

  def horizons_position(command)
    start_date = Date.today
    parameters = {
      format: 'json', COMMAND: "'#{command}'", OBJ_DATA: 'NO', MAKE_EPHEM: 'YES',
      EPHEM_TYPE: 'VECTORS', CENTER: "'500@10'", REF_PLANE: 'FRAME',
      REF_SYSTEM: 'ICRF', VEC_TABLE: '1', VEC_LABELS: 'NO', CSV_FORMAT: 'YES',
      OUT_UNITS: 'AU-D', START_TIME: "'#{start_date.iso8601}'",
      STOP_TIME: "'#{(start_date + 1).iso8601}'", STEP_SIZE: "'1 d'"
    }
    uri = URI("https://ssd.jpl.nasa.gov/api/horizons.api?#{URI.encode_www_form(parameters)}")
    response = request(uri, 'Accept' => 'application/json')
    return nil unless response && response.code.to_i == 200
    payload = JSON.parse(response.body)
    return nil if payload['error']
    text = payload['result'].to_s
    section = text.split('$$SOE', 2)[1]
    section = section.split('$$EOE', 2)[0] if section
    line = section.to_s.lines.find { |candidate| candidate.include?(',') && candidate.match?(/[+-]?\d+(?:\.\d+)?[Ee][+-]?\d+/) }
    return nil unless line
    columns = line.split(',').map(&:strip)
    vector = columns[2, 3]&.map { |value| Float(value) }
    vector if vector && vector.length == 3 && vector.all?(&:finite?)
  rescue StandardError => e
    warn "JPL Horizons vector lookup failed: #{e.class}: #{e.message}"
    nil
  end

  def external_name_search(query)
    safe = safe_catalog_query(query)
    return [] if safe.length < 2
    uri = URI("https://cds.unistra.fr/cgi-bin/nph-sesame/-oxp/SNV?#{URI.encode_www_form_component(safe)}")
    response = request(uri, 'Accept' => 'application/xml,text/xml;q=0.9,*/*;q=0.1')
    return [] unless response && response.code.to_i == 200
    document = REXML::Document.new(response.body)
    target = REXML::XPath.first(document, '//Target')
    resolver = REXML::XPath.first(target, './Resolver') if target
    return [] unless resolver
    name = REXML::XPath.first(resolver, './name')&.text.to_s.strip
    return [] if name.empty?
    ra = numeric(REXML::XPath.first(resolver, './jradeg')&.text)
    dec = numeric(REXML::XPath.first(resolver, './jdedeg')&.text)
    object_type = REXML::XPath.first(resolver, './otype')&.text.to_s.strip
    parallax = numeric(REXML::XPath.first(resolver, './plx/v')&.text)
    parallax_error = numeric(REXML::XPath.first(resolver, './plx/e')&.text)
    # Sesame/SIMBAD reports stellar trigonometric parallax in milliarcseconds.
    # Only use it for a 3D placement when the measurement is positive and has a
    # usable signal-to-uncertainty ratio; no radial distance is inferred from a galaxy's
    # direction alone.
    distance_ly = if parallax && parallax > 0 && (!parallax_error || parallax_error < parallax)
                    (1000.0 / parallax) * 3.26156
                  end
    position = radec_position(ra, dec, distance_ly)
    category = sesame_category(object_type, name)
    id = "sesame-#{name.downcase.gsub(/[^a-z0-9]+/, '-')}"
    facts = {
      'Resolver type' => object_type.empty? ? 'Not supplied' : object_type,
      'Right ascension (J2000)' => ra ? "#{ra.round(6)}°" : nil,
      'Declination (J2000)' => dec ? "#{dec.round(6)}°" : nil,
      'Parallax' => parallax ? "#{parallax.round(4)} mas" : nil,
      'Parallax uncertainty' => parallax_error ? "#{parallax_error.round(4)} mas" : nil,
      'Estimated distance' => distance_ly ? "#{distance_ly.round(2)} light-years (from parallax)" : nil
    }.compact
    {
      id: id, name: name, type: category_title(category), category: category,
      color: category_color(category), size: 0.08, ra_deg: ra, dec_deg: dec, distance_ly: distance_ly,
      position: position, map_frame: 'universe', map_status: position ? 'plotted' : 'unplotted',
      position_accuracy: position ? '3D position computed from the resolver direction and positive stellar parallax' : 'Name resolver found a direction but no reliable positive parallax distance; no radial distance is invented',
      position_source: 'CDS Sesame name resolver (SIMBAD / NED / VizieR)',
      external: true, subtitle: 'SIMBAD / NED / VizieR name resolver',
      description: position ?
        'The CDS Sesame resolver returned a J2000 direction and SIMBAD parallax. Distance is an estimate derived from the measured parallax and should be checked against the source reference.' :
        'The CDS Sesame resolver matched this name and returned celestial coordinates. A reliable distance was not available, so Astra does not invent a 3D position.',
      facts: facts,
      sources: [
        source('CDS Sesame name resolver', 'Centre de Données astronomiques de Strasbourg', "https://cds.unistra.fr/cgi-bin/nph-sesame/-oxp/SNV?#{URI.encode_www_form_component(name)}"),
        source('SIMBAD astronomical database', 'CDS Strasbourg', "https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=#{URI.encode_www_form_component(name)}"),
        source('NASA/IPAC Extragalactic Database', 'NASA / Caltech', "https://ned.ipac.caltech.edu/search?search_type=Near+Position+Search&objname=#{URI.encode_www_form_component(name)}")
      ], related: []
    }
  rescue StandardError => e
    warn "CDS Sesame search failed: #{e.class}: #{e.message}"
    []
  end
  def sesame_category(object_type, name)
    type = object_type.to_s.upcase
    return 'galaxy' if type.match?(/[GQ]/) || name.match?(/galaxy|milky way|andromeda/i)
    return 'black-hole' if type.match?(/BH/) || name.match?(/black hole|sagittarius a\*/i)
    return 'nebula' if type.match?(/HII|PN|SNR|ISM|NEB/)
    return 'exoplanet' if name.match?(/(?:Kepler|TRAPPIST|Proxima Centauri) [a-z0-9-]+/i)
    return 'planet' if type.match?(/PLANET/)
    return 'star' if type.match?(/STAR|V\*/) || type == '*'
    'deep'
  end

  def gaia_bright_stars(limit = 450)
    count = [[numeric(limit)&.to_i || 450, 40].max, 700].min
    cache = defined?(@gaia_star_cache) ? @gaia_star_cache : nil
    cached_at = defined?(@gaia_star_cache_at) ? @gaia_star_cache_at : Time.at(0)
    return cache if cache && Time.now - cached_at < 3600

    adql = "SELECT TOP #{count} source_id,ra,dec,parallax,phot_g_mean_mag,bp_rp FROM gaiadr3.gaia_source WHERE parallax > 0.2 AND parallax_over_error > 5 AND phot_g_mean_mag < 9.0 ORDER BY phot_g_mean_mag ASC"
    uri = URI("https://gea.esac.esa.int/tap-server/tap/sync?#{URI.encode_www_form(REQUEST: 'doQuery', LANG: 'ADQL', FORMAT: 'json', QUERY: adql)}")
    response = request(uri, { 'Accept' => 'application/json' }, read_timeout: 18.0)
    return cache || [] unless response && response.code.to_i == 200
    payload = JSON.parse(response.body)
    fields = Array(payload['metadata']).map { |field| field['name'].to_s }
    rows = Array(payload['data'])
    stars = rows.filter_map do |row|
      next unless row.is_a?(Array)
      get = lambda do |key|
        index = fields.index(key)
        index ? row[index] : nil
      end
      parallax = numeric(get.call('parallax'))
      ra = numeric(get.call('ra'))
      dec = numeric(get.call('dec'))
      source_id = get.call('source_id')
      next unless parallax && parallax.positive? && ra && dec && source_id
      distance_ly = (1000.0 / parallax) * 3.26156
      position = radec_position(ra, dec, distance_ly)
      color_index = numeric(get.call('bp_rp'))
      tint = if color_index && color_index < 0.4
               '#9fbaff'
             elsif color_index && color_index > 1.6
               '#ffb18a'
             else
               '#e8dfcb'
             end
      {
        id: "gaia-dr3-#{source_id}", name: "Gaia DR3 #{source_id}", type: 'Gaia DR3 star',
        category: 'star', color: tint, size: 0.08, position: position,
        map_frame: 'universe', map_status: 'plotted', ra_deg: ra, dec_deg: dec,
        distance_ly: distance_ly, parallax_mas: parallax,
        apparent_magnitude: numeric(get.call('phot_g_mean_mag')), bp_rp: color_index,
        position_accuracy: 'Gaia DR3 ICRS coordinates with distance estimated from parallax',
        position_source: 'ESA Gaia Data Release 3', catalog_source: 'Gaia DR3',
        subtitle: "Gaia DR3 · #{distance_ly.round(1)} light-years",
        system: 'Milky Way', external: true,
        description: 'This stellar source comes from Gaia Data Release 3. The 3D position uses its published right ascension, declination and parallax; distance is estimated as 1/parallax and does not account for all systematic uncertainties.',
        facts: { 'Gaia source ID' => source_id.to_s, 'Right ascension (ICRS)' => "#{ra.round(6)}°",
          'Declination (ICRS)' => "#{dec.round(6)}°", 'Parallax' => "#{parallax.round(4)} mas",
          'Estimated distance' => "#{distance_ly.round(2)} light-years",
          'G-band magnitude' => numeric(get.call('phot_g_mean_mag'))&.round(3),
          'BP − RP colour' => color_index&.round(3) }.compact,
        sources: [
          source('Gaia DR3 source archive', 'European Space Agency', "https://gea.esac.esa.int/archive/?source=#{source_id}"),
          source('Gaia mission', 'ESA', 'https://www.esa.int/Science_Exploration/Space_Science/Gaia')
        ], related: []
      }
    end
    @gaia_star_cache = stars
    @gaia_star_cache_at = Time.now
    stars
  rescue StandardError => e
    warn "Gaia DR3 query failed: #{e.class}: #{e.message}"
    []
  end


  def gaia_cone_stars(ra_deg:, dec_deg:, radius_deg: 2.0, limit: 250)
    ra = numeric(ra_deg)
    dec = numeric(dec_deg)
    radius = numeric(radius_deg)
    return [] unless ra && dec && radius && ra.between?(0, 360) && dec.between?(-90, 90) && radius.between?(0.05, 15)
    count = [[numeric(limit)&.to_i || 250, 20].max, 500].min
    adql = "SELECT TOP #{count} source_id,ra,dec,parallax,phot_g_mean_mag,bp_rp FROM gaiadr3.gaia_source WHERE 1=CONTAINS(POINT('ICRS',ra,dec),CIRCLE('ICRS',#{ra},#{dec},#{radius})) AND parallax > 0.2 AND parallax_over_error > 5 AND phot_g_mean_mag < 18 ORDER BY phot_g_mean_mag ASC"
    uri = URI("https://gea.esac.esa.int/tap-server/tap/sync?#{URI.encode_www_form(REQUEST: 'doQuery', LANG: 'ADQL', FORMAT: 'json', QUERY: adql)}")
    response = request(uri, 'Accept' => 'application/json')
    return [] unless response && response.code.to_i == 200
    payload = JSON.parse(response.body)
    fields = Array(payload['metadata']).map { |field| field['name'].to_s }
    Array(payload['data']).filter_map do |row|
      next unless row.is_a?(Array)
      get = lambda { |key| index = fields.index(key); index ? row[index] : nil }
      parallax = numeric(get.call('parallax'))
      star_ra = numeric(get.call('ra'))
      star_dec = numeric(get.call('dec'))
      source_id = get.call('source_id')
      next unless parallax && parallax.positive? && star_ra && star_dec && source_id
      distance_ly = 1000.0 / parallax * 3.26156
      position = radec_position(star_ra, star_dec, distance_ly)
      next unless position
      magnitude = numeric(get.call('phot_g_mean_mag'))
      color_index = numeric(get.call('bp_rp'))
      tint = color_index && color_index < 0.4 ? '#9fbaff' : (color_index && color_index > 1.6 ? '#ffb18a' : '#e8dfcb')
      {
        id: "gaia-dr3-#{source_id}", name: "Gaia DR3 #{source_id}", type: 'Gaia DR3 star',
        category: 'star', color: tint, size: 0.06, position: position,
        map_frame: 'universe', map_status: 'plotted', ra_deg: star_ra, dec_deg: star_dec,
        distance_ly: distance_ly, parallax_mas: parallax, apparent_magnitude: magnitude,
        position_accuracy: 'Gaia DR3 ICRS coordinates and distance estimated from parallax',
        position_source: 'ESA Gaia Data Release 3', catalog_source: 'Gaia DR3',
        subtitle: "Gaia DR3 · #{distance_ly.round(1)} light-years", system: 'Milky Way', external: true,
        description: 'Gaia DR3 source returned for the requested sky cone. The 3D distance is estimated from its positive parallax; catalogue uncertainties and parallax systematics still apply.',
        facts: { 'Gaia source ID' => source_id.to_s, 'Right ascension (ICRS)' => "#{star_ra.round(6)}°",
          'Declination (ICRS)' => "#{star_dec.round(6)}°", 'Parallax' => "#{parallax.round(4)} mas",
          'Estimated distance' => "#{distance_ly.round(2)} light-years",
          'G-band magnitude' => magnitude&.round(3), 'BP − RP colour' => color_index&.round(3) }.compact,
        sources: [
          source('Gaia DR3 source archive', 'European Space Agency', "https://gea.esac.esa.int/archive/?source=#{source_id}"),
          source('Gaia mission', 'ESA', 'https://www.esa.int/Science_Exploration/Space_Science/Gaia')
        ], related: []
      }
    end
  rescue StandardError => e
    warn "Gaia cone search failed: #{e.class}: #{e.message}"
    []
  end

  def federated_search(query)
    safe = safe_catalog_query(query)
    return [] if safe.length < 2
    tasks = [
      Thread.new { exoplanet_search(safe, 8) },
      Thread.new { jpl_small_body_search(safe) },
      Thread.new { external_name_search(safe) },
      Thread.new { wiki_search(safe, 5) }
    ]
    results = tasks.flat_map do |thread|
      begin
        value = thread.value
        value.is_a?(Array) ? value : []
      rescue StandardError => e
        warn "Astra federated source failed: #{e.class}: #{e.message}"
        []
      end
    end
    results.uniq { |item| item[:name].to_s.downcase }.first(24)
  end

  def ephemeris_snapshot
    EPHEMERIS_MUTEX.synchronize do
      return EPHEMERIS_CACHE[:positions] if Time.now - EPHEMERIS_CACHE[:fetched_at] < 900 && !EPHEMERIS_CACHE[:positions].empty?
    end

    ids = EPHEMERIS_BODY_IDS.to_a
    positions = {}
    ids.each_slice(5) do |batch|
      threads = batch.map do |id, command|
        Thread.new do
          vector = horizons_position(command)
          [id, vector]
        end
      end
      threads.each do |thread|
        begin
          id, vector = thread.value
          positions[id] = { au: vector, ly: vector.map { |component| component / AU_PER_LIGHT_YEAR },
                            source: 'NASA/JPL Horizons ICRF heliocentric vector', epoch_utc: Time.now.utc.iso8601 } if vector
        rescue StandardError => e
          warn "Astra ephemeris worker failed: #{e.class}: #{e.message}"
        end
      end
    end
    EPHEMERIS_MUTEX.synchronize do
      EPHEMERIS_CACHE[:positions] = positions unless positions.empty?
      EPHEMERIS_CACHE[:fetched_at] = Time.now unless positions.empty?
      EPHEMERIS_CACHE[:positions]
    end
  end

end

class AstraServer < Sinatra::Base
  set :bind, ENV.fetch('HOST', '0.0.0.0')
  set :port, Integer(ENV.fetch('PORT', '4567'))
  set :static, false
  set :show_exceptions, false

  before do
    headers 'X-Content-Type-Options' => 'nosniff',
            'Referrer-Policy' => 'strict-origin-when-cross-origin'
  end

  get '/' do
    content_type 'text/html', charset: 'utf-8'
    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="theme-color" content="#050713">
        <meta name="description" content="Explore planets, stars, galaxies and deep space in an interactive 3D universe.">
        <title>Astra — Universe Explorer</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Orbitron:wght@400;500;600;700&family=Space+Grotesk:wght@400;500;600;700&display=swap" rel="stylesheet">
        <link rel="stylesheet" href="/styles.css">
      </head>
      <body>
        <div id="root"></div>
        <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/react@18.3.1/umd/react.production.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/react-dom@18.3.1/umd/react-dom.production.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/@babel/standalone@7.26.6/babel.min.js"></script>
        <script type="text/babel" data-presets="react" src="/app.jsx"></script>
      </body>
      </html>
    HTML
  end

  get '/app.jsx' do
    content_type 'application/javascript', charset: 'utf-8'
    send_file File.join(__dir__, 'app.jsx'), disposition: 'inline'
  end

  get '/styles.css' do
    content_type 'text/css', charset: 'utf-8'
    send_file File.join(__dir__, 'styles.css'), disposition: 'inline'
  end

  get '/api/health' do
    content_type :json
    { status: 'ok', app: 'Astra Universe Explorer', catalog_count: Astra::CATALOG.length,
      external_search: 'NASA TAP, JPL SBDB/CAD/Horizons, ESA Gaia, CDS Sesame, Wikipedia', timestamp: Time.now.utc.iso8601 }.to_json
  end

  get '/api/catalog' do
    content_type :json
    cache_control :no_store
    { objects: Astra::CATALOG, count: Astra::CATALOG.length,
      categories: Astra::CATALOG.map { |item| item[:category] }.uniq,
      coordinate_system: { universe: 'Linear 3D Cartesian coordinates; one scene unit equals one light-year',
        solar_system: 'JPL Horizons heliocentric ICRF vectors when available; one scene unit equals one AU',
        body_sizes: 'Celestial bodies are rendered as enlarged interactive markers and are not to physical size' },
      catalogs: [
        { id: 'nasa-exoplanet-archive', name: 'NASA Exoplanet Archive', scope: 'Confirmed exoplanets and host-system parameters', url: 'https://exoplanetarchive.ipac.caltech.edu/' },
        { id: 'jpl-sbdb', name: 'JPL Small-Body Database / Horizons', scope: 'Asteroids, comets, orbital data and current vectors', url: 'https://ssd.jpl.nasa.gov/' },
        { id: 'gaia-dr3', name: 'ESA Gaia DR3', scope: 'Astrometry and parallax distances for sampled stars', url: 'https://gea.esac.esa.int/archive/' },
        { id: 'cds-sesame', name: 'CDS Sesame / SIMBAD / NED / VizieR', scope: 'Astronomical name resolution and coordinates', url: 'https://cds.unistra.fr/cgi-bin/nph-sesame/' },
        { id: 'wikipedia', name: 'Wikipedia / Wikimedia', scope: 'Supplementary discoverability and contextual summaries', url: 'https://www.wikipedia.org/' }
      ] }.to_json
  end

  get '/api/archive/exoplanets' do
    content_type :json
    cache_control :no_store
    limit = params['limit'].to_s.empty? ? 40 : params['limit'].to_i
    halt 400, { error: 'Limit must be between 10 and 100.' }.to_json unless limit.between?(10, 100)
    query = params['q'].to_s.strip
    after = params['after'].to_s.strip
    halt 400, { error: 'Query or cursor is too long.' }.to_json if query.length > 90 || after.length > 120
    result = Astra.exoplanet_archive_page(limit: limit, after: after, query: query)
    status 503 if result[:source_status] == 'unavailable'
    result.to_json
  end

  get '/api/archive/small-bodies' do
    content_type :json
    cache_control :no_store
    limit = params['limit'].to_s.empty? ? 40 : params['limit'].to_i
    offset = params['offset'].to_s.empty? ? 0 : params['offset'].to_i
    kind = params['kind'].to_s.empty? ? 'all' : params['kind'].to_s.downcase
    neo = %w[1 true yes].include?(params['neo'].to_s.downcase)
    halt 400, { error: 'Limit must be between 10 and 100; offset between 0 and 2000000.' }.to_json unless limit.between?(10, 100) && offset.between?(0, 2_000_000)
    halt 400, { error: 'kind must be all, asteroid, or comet.' }.to_json unless %w[all asteroid comet].include?(kind)
    result = Astra.small_body_archive_page(limit: limit, offset: offset, kind: kind, neo: neo)
    status 503 if result[:source_status] == 'unavailable'
    result.to_json
  end

  get '/api/small-body' do
    content_type :json
    cache_control :no_store
    query = params['query'].to_s.strip
    halt 400, { error: 'Provide a JPL small-body name or designation.' }.to_json if query.empty? || query.length > 100
    object = Astra.small_body_detail(query)
    halt 404, { error: 'No unambiguous JPL small-body match was found.' }.to_json unless object
    { object: object, source: 'NASA/JPL SBDB + Horizons' }.to_json
  end

  get '/api/close-approaches' do
    content_type :json
    cache_control :no_store
    days = params['days'].to_s.empty? ? 90 : params['days'].to_i
    distance = params['distance'].to_s.empty? ? 0.05 : params['distance']
    limit = params['limit'].to_s.empty? ? 30 : params['limit'].to_i
    halt 400, { error: 'days must be between 1 and 3650; limit between 5 and 80.' }.to_json unless days.between?(1, 3650) && limit.between?(5, 80)
    result = Astra.close_approach_page(days: days, distance_au: distance, limit: limit)
    status 503 if result[:source_status] == 'unavailable'
    result.to_json
  end

  get '/api/coverage' do
    content_type :json
    result = Astra.archive_coverage
    cache_control :public, max_age: 600
    result.to_json
  end

  get '/api/sky' do
    content_type :json
    cache_control :no_store
    limit = params['limit'].to_s.empty? ? 450 : params['limit'].to_i
    halt 400, { error: 'Limit must be between 20 and 700.' }.to_json unless limit.between?(20, 700)
    if params.key?('ra') || params.key?('dec')
      stars = Astra.gaia_cone_stars(ra_deg: params['ra'], dec_deg: params['dec'],
                                    radius_deg: params['radius'].to_s.empty? ? 2 : params['radius'],
                                    limit: limit)
      { objects: stars, count: stars.length, catalog: 'Gaia DR3', complete_catalog: false,
        query_mode: 'ICRS cone search', note: 'Only sources with positive, quality-filtered parallaxes are plotted.',
        source: 'https://gea.esac.esa.int/archive/' }.to_json
    else
      stars = Astra.gaia_bright_stars(limit)
      { objects: stars, count: stars.length, catalog: 'Gaia DR3', complete_catalog: false,
        query_mode: 'bright all-sky sample', note: 'Magnitude-limited, parallax-quality-filtered sample; not the full Gaia source table.',
        source: 'https://gea.esac.esa.int/archive/' }.to_json
    end
  end
  get '/api/ephemeris' do
    content_type :json
    cache_control :no_store
    positions = Astra.ephemeris_snapshot
    halt 503, { error: 'JPL Horizons is temporarily unavailable.', positions: {} }.to_json if positions.empty?
    { positions: positions, source: 'NASA/JPL Horizons', frame: 'ICRF heliocentric', units: 'AU and light-years',
      epoch_utc: positions.values.map { |value| value[:epoch_utc] }.compact.first }.to_json
  end

  get '/api/search' do
    content_type :json
    cache_control :no_store
    query = params['q'].to_s.strip
    halt 400, { error: 'Search term is required.' }.to_json if query.length > 160

    if query.length < 2
      return { query: query, results: [] }.to_json
    end

    needle = query.downcase
    local = Astra::CATALOG.select do |item|
      searchable = [item[:name], item[:id], item[:type], item[:category], item[:system],
                    item[:subtitle], item[:description], item[:facts].values.join(' ')].compact.join(' ').downcase
      searchable.include?(needle)
    end.first(8)
    external = Astra.federated_search(query)
    results = (local + external).uniq { |item| item[:name].to_s.downcase }.first(32)
    { query: query, results: results, local_count: local.length, external_count: external.length,
      sources: %w[NASA_Exoplanet_Archive JPL_SBDB CDS_Sesame Wikipedia],
      message: 'Search results combine curated local entries with live external catalogs; not all catalogs provide full 3D coordinates.' }.to_json
  end

  get '/api/object/:id' do
    content_type :json
    object = Astra::BY_ID[params['id']]
    halt 404, { error: 'Object not found in the local catalog.' }.to_json unless object
    object.to_json
  end

  get '/api/lookup' do
    content_type :json
    title = params['title'].to_s.strip
    halt 400, { error: 'Provide a title to look up.' }.to_json if title.empty? || title.length > 180

    matched = Astra::CATALOG.find { |item| item[:name].casecmp(title).zero? }
    return { object: matched, source: 'local catalog' }.to_json if matched

    object = Astra.wiki_lookup(title)
    halt 404, { error: 'No reference found. Try a more specific object name.' }.to_json unless object
    { object: object, source: 'Wikimedia summary API' }.to_json
  end

  get '/api/source-search' do
    content_type :json
    query = params['q'].to_s.strip
    halt 400, { error: 'Search term is required.' }.to_json if query.empty? || query.length > 160
    safe_query = URI.encode_www_form_component(query)
    {
      nasa: "https://science.nasa.gov/search/?q=#{safe_query}",
      esa: "https://www.esa.int/Science_Exploration/Space_Science",
      exoplanets: "https://exoplanetarchive.ipac.caltech.edu/",
      simbad: "https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=#{safe_query}",
      wikipedia: "https://en.wikipedia.org/w/index.php?search=#{safe_query}"
    }.to_json
  end

  not_found do
    content_type :json
    { error: 'Not found.' }.to_json
  end

  error do
    content_type :json
    status 500
    { error: 'An unexpected server error occurred.' }.to_json
  end
end

AstraServer.run! if $PROGRAM_NAME == __FILE__
