# Astra — Universe Explorer

Astra is an interactive astronomy browser built around three application files: a React/Three.js frontend, a space-themed CSS system, and a Ruby/Sinatra API. It combines curated object profiles with **live, query-driven public science archives** and source links.

> **Scientific coverage note:** there is no single complete database of every known cosmic object. Current archives contain enormous datasets, measurement uncertainties, missing distances, and different coverage. Astra federates public services and loads bounded samples/search results on demand; it does not claim to copy or fully render every record in every archive.

## Features

- **Interactive 3D scene:** drag to orbit, scroll to zoom, click markers, focus an object, toggle labels and orbit paths.
- **Two spatial frames:** the universe map uses Cartesian coordinates in light-years where a reliable distance and sky position exist. The Solar System view uses astronomical units (AU), with current vectors requested from JPL Horizons when available.
- **Solar System ephemerides:** fetches Horizons vectors for supported planets, moons, dwarf planets and small bodies. An approximate mean-orbit layout is available if live ephemerides cannot be retrieved.
- **Exoplanet discovery:** searches NASA Exoplanet Archive's `pscomppars` table for planet/host matches and published parameters.
- **Small-body search:** queries NASA/JPL's Small-Body Database for matching asteroids and comets, and requests a Horizons vector where a usable identifier is available.
- **Stellar samples and on-demand sky queries:** queries ESA Gaia DR3 for a bright all-sky sample, then requests additional sources around a selected sky direction. Parallax-based distances are estimated only for positive, quality-filtered parallaxes.
- **Astronomical name resolution:** queries CDS Sesame (SIMBAD/NED/VizieR resolver) and plots results only when a usable distance is available. Coordinates without a reliable distance remain searchable but unplotted.
- **Supplementary discovery:** Wikipedia search/summary provides broader context rather than serving as the scientific measurement authority.
- **Object profiles:** summaries, measurements, coordinate provenance, related objects, and direct source links.
- **Responsive space UI:** deep-navy observatory design, procedural planet art, cosmic highlights, Orbitron/Space Grotesk typography, mobile layouts, reduced-motion support.

## Requirements

- Ruby 3.1 or newer (Ruby 3.2+ recommended).
- Browser internet access for CDN-loaded React, ReactDOM, Babel, Three.js and Google Fonts.
- Server internet access to use live astronomy services. Curated profiles still work if a remote service is unavailable.

## Run locally

Install the server gems:

```sh
gem install sinatra puma
```

Start Astra from the repository root:

```sh
ruby server.rb
```

Open [http://localhost:4567](http://localhost:4567).

Choose another port with `PORT`:

```sh
PORT=3000 ruby server.rb
```

No HTML app file or JavaScript package manifest is required. Sinatra generates the HTML shell in `server.rb`; React renders the interface from `app.jsx`.

## The three application files

| File | Responsibility |
|---|---|
| `app.jsx` | React components and state, Three.js scene, spatial-frame navigation, search, filters, details, and on-demand catalog loading |
| `styles.css` | Responsive space theme, coordinate/scale widgets, object detail panels, source cards and UI transitions |
| `server.rb` | Sinatra page shell, curated records, scientific-service adapters, JSON endpoints and coordinate conversion |

`README.md` is documentation, not a fourth application file.

## API

| Endpoint | Function |
|---|---|
| `GET /` | Serves the React app shell |
| `GET /api/health` | Basic server status |
| `GET /api/catalog` | Curated starter records, source list and coordinate-system metadata |
| `GET /api/search?q=TRAPPIST-1` | Searches local entries and live NASA Exoplanet Archive, JPL SBDB, CDS Sesame and Wikipedia results |
| `GET /api/object/:id` | Retrieves a curated record by ID |
| `GET /api/lookup?title=Andromeda%20Galaxy` | Returns a curated record or a supplementary Wikipedia summary |
| `GET /api/sky?limit=450` | Returns a bounded bright-star sample from Gaia DR3 (not the entire archive) |
| `GET /api/sky?ra=83.8&dec=-5.4&radius=1.2&limit=150` | Returns a bounded Gaia DR3 sky-cone query in ICRS coordinates |
| `GET /api/ephemeris` | Returns cached/current JPL Horizons vectors for supported Solar System bodies |
| `GET /api/source-search?q=supernova` | Returns source links for NASA, ESA, Exoplanet Archive, SIMBAD and Wikipedia |

Quick checks:

```sh
curl http://localhost:4567/api/health
curl http://localhost:4567/api/catalog
curl 'http://localhost:4567/api/search?q=TRAPPIST-1'
curl 'http://localhost:4567/api/sky?ra=83.8&dec=-5.4&radius=1.2&limit=150'
curl http://localhost:4567/api/ephemeris
```

Live remote services may rate-limit or time out. Search returns what reachable sources provide; a source outage is not evidence that an object does not exist.

## Spatial accuracy: what is and is not to scale

A map can be spatially accurate in distances without making object icons and artwork physically sized.

### Universe frame

For curated stars and galaxies with a distance and right ascension/declination, the server converts sky direction and distance into Cartesian coordinates, using **1 scene unit = 1 light-year**. Gaia records use DR3 sky coordinates and distance estimated from parallax. Right ascension/declination without a trusted radial distance is not sufficient for 3D placement; those records stay searchable and are marked **not placed on the 3D map** rather than being assigned a fabricated distance.

The Gaia data loaded by default is a **limited sample**, and cone searches have a result cap. Astra is not an offline copy of all Gaia records.

### Solar System frame

The Solar System is much smaller than interstellar space. Astra switches to a separate **1 scene unit = 1 AU** frame for nearby bodies. JPL Horizons vectors are used when that service responds; otherwise the mean semi-major-axis layout provides an initial approximate view. The drawn orbit guides are circles at mean orbit radii, not exact evolving ellipses for every body's osculating orbit.

### Marker sizes and imagery

Planets, stars, galaxies and other objects are rendered as enlarged interactive markers. Visual radii and procedural galaxy/nebula illustrations are **not physical size scale**. Distances and positions are kept separate from symbol size. The scene is a multi-scale scientific navigation visualization, not an ephemeris-grade planetarium.

### What “every known object” means

A genuinely exhaustive universe catalogue is not currently achievable as a single static dataset. Gaia alone contains astrometric and photometric records for nearly two billion stars and other sources; dedicated archives catalogue other object families. Astra federates several public catalogs and queries them as needed, but it does **not** ingest every record or guarantee every object can be plotted. It can be extended with catalog pagination, persistent cache, proper motions, uncertainty intervals and additional mission/archive adapters.

## Scientific source services

- [NASA Exoplanet Archive TAP](https://exoplanetarchive.ipac.caltech.edu/docs/TAP/usingTAP.html) — exoplanet/host discovery data.
- [NASA/JPL Small-Body Database](https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html) — asteroid/comet records.
- [NASA/JPL Horizons API](https://ssd-api.jpl.nasa.gov/doc/horizons.html) — date-dependent Solar System ephemerides and vectors.
- [ESA Gaia Archive](https://gea.esac.esa.int/archive/) — stellar astrometry, parallax, photometry and associated records.
- [CDS Sesame](https://cds.unistra.fr/cgi-bin/nph-sesame/) and [SIMBAD](https://simbad.cds.unistra.fr/) — astronomical name resolution and cross-identifications.
- [NASA Science](https://science.nasa.gov/) and [Wikipedia](https://www.wikipedia.org/) — contextual references (Wikipedia is supplementary rather than authoritative for measured parameters).

For research, check the linked record directly. Archive values, classifications and counts can change as observations and catalog releases are revised.

## Troubleshooting

- **Catalog unavailable:** start `ruby server.rb` and check `/api/health`.
- **External search is empty:** confirm server network access. Test another archive; a failed request is not evidence that no match exists.
- **Object is searchable but not plotted:** its source may not include a reliable distance; an angular direction alone does not establish 3D location.
- **Only some stars appear:** Astra intentionally requests a bounded sample instead of downloading billions of records. Selecting a celestial object triggers an on-demand sky-cone query.
- **Blank 3D scene:** check browser WebGL support and network requests for CDN failures.
- **Port conflict:** run with `PORT=3000 ruby server.rb`.

## License

No project-specific license was present in the initial repository. Add a license before redistributing the project.
