# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'
require 'time'
require 'openssl'
require 'sinatra/base'

module Astra
  module_function

  def source(label, publisher, url)
    { label: label, publisher: publisher, url: url }
  end

  def object(id, name, type, category, color, size, position, system, subtitle, description, facts, sources, related, texture_colors = nil)
    item = {
      id: id, name: name, type: type, category: category, color: color,
      size: size, position: position, system: system, subtitle: subtitle,
      description: description, facts: facts, sources: sources, related: related
    }
    item[:textureColors] = texture_colors if texture_colors
    item
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
      color: category_color(category), size: 0.3, position: [0, 0, 0],
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

  def request(uri, extra_headers = {})
    return nil unless uri.is_a?(URI::HTTPS) && uri.host == 'en.wikipedia.org'

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 2.5
    http.read_timeout = 3.5
    http.write_timeout = 2.5 if http.respond_to?(:write_timeout=)
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'AstraUniverseExplorer/1.0 (educational astronomy catalog)'
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
      external_search: 'Wikipedia API', timestamp: Time.now.utc.iso8601 }.to_json
  end

  get '/api/catalog' do
    content_type :json
    cache_control :no_store
    { objects: Astra::CATALOG, count: Astra::CATALOG.length,
      categories: Astra::CATALOG.map { |item| item[:category] }.uniq }.to_json
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
    external = Astra.wiki_search(query, 6)
    results = (local + external).uniq { |item| item[:name].to_s.downcase }.first(10)
    { query: query, results: results, local_count: local.length, external_count: external.length }.to_json
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
