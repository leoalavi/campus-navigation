# MQ Journey: Project Report
*Find your way around Macquarie without selling your data.*

### Application Overview
The Macquarie University campus contains over 150 buildings spread across a wide area. New students, open day visitors, and temporary staff struggle to locate lecture theaters, first aid rooms, and transit options. MQ Journey solves this navigation problem. The application displays an illustrated campus map for direct visual navigation. Users can search the building database, calculate walking routes, toggle an on-device compass, and view live train departures.

We designed the application with a focus on user privacy. Unlike commercial mapping services, MQ Journey does not collect telemetry, location history, or personal identifiers. The app launches directly to the home screen with a silent anonymous session — no account registration needed. Favourites and notifications work out of the box.

### Core Capabilities
MQ Journey structures its features into seven modules:

1. **Building Favorites (CRUD)**: Authenticated users perform full CRUD on the `favorite_buildings` Supabase table. **Create** by tapping the heart icon on any building card, **Read** on the dedicated Favourites page with pull-to-refresh, **Update** by adding or editing a personal note via the kebab menu, and **Delete** by swiping a row or selecting Remove. The controller uses optimistic UI updates with rollback on failure.
2. **Illustrated Campus Map**: A calibrated flutter_map + CrsSimple raster renderer pinpoints building entrances directly. Over 150 buildings are searchable by code, name, or alias.
3. **Turn-by-Turn Routing**: We query a custom Supabase Edge proxy to fetch walking, driving, and transit routes. The proxy routes requests to OpenRouteService and TfNSW, then transforms the raw coordinates into step-by-step instructions. The application displays navigation updates, computes the walking duration, and detects arrival at the destination entrance.
4. **Compass Mode**: Devices with magnetometer hardware run an on-device radar view. The application calculates the geometric bearing between the user and their destination, rotating a directional guide arrow via native sensor streams. The compass interface shows heading accuracy limits and cardinal points without transmitting coordinates to external servers.
5. **Campus Safety Toolkit**: A standalone safety panel lists direct phone links for triple-zero, campus security, and health services. The toolkit integrates a flashlight toggle and maps the coordinates of five campus defibrillators and three first aid rooms. The safety features work without background location tracking.
6. **Transit Departure Board**: The application displays real-time metro countdowns for Macquarie University Station. Commuters select their travel direction and preferred transit line to save countdown details to local preferences.
7. **Notifications**: FCM push for announcements and locally-scheduled study prompts, managed via notification preferences stored on-device.

### Target Audience and Personas
We defined three user groups to guide the application design:

1. **First-Year Students**: These users need to locate classrooms within tight gaps between classes. They rely on search aliases (such as "18WW" matching 18 Wally's Walk) to locate entrances.
2. **Open Day Visitors**: These users arrive on campus with no prior knowledge of the layout. They need immediate access to public events and main campus landmarks without authentication gates.
3. **Evening Commuters**: Students and staff leaving campus after dark require quick access to safety shuttles, flashlight toggles, and live train timetables.

#### User Persona: Sarah (First-Year Student)
Sarah has a ten-minute window to walk from a lab in the Business School (4 Eastern Road) to a tutorial in 18 Wally's Walk. General maps bundle building names together without showing entrance locations. Sarah opens MQ Journey, types "18WW" into the search bar, and starts a walking route. The application guides her through campus walkways, shows her next turn, and alerts her when she reaches the entry doors.

#### User Persona: Marcus (Open Day Visitor)
Marcus wants to explore the engineering labs. He does not want to register an account or share his location. He opens the app and views the campus layout on the illustrated map. He marks the Engineering building as a favorite, adding a personal note to visit the robotics display.

#### The Competitive Advantage
Generic mapping tools lack accurate pedestrian data for campus-specific paths. They direct users to perimeter roads instead of pedestrian plazas. The university's official web map loads with high latency, demands single sign-on credentials, and fails to offer routing. MQ Journey loads without delay, offers turn-by-turn campus routing, provides safety contacts, and operates without trackers.

### Technical Specifications
#### Project Structure
The repository implements clean, feature-first architecture:
- `lib/app/`: Handles app initialization, design tokens, locale assets, and GoRouter routing.
- `lib/core/`: Wraps environment configuration, logging, network status, secure storage, and session guard.
- `lib/shared/`: Hosts reusable UI widgets (buttons, input fields, custom sheets).
- `lib/features/`: Groups application code by feature domain (map, safety, transit, favorites). Each feature divides code into presentation (controllers and UI), domain (pure data models), and data (datasources and repositories) packages.

#### State and Routing Setup
Riverpod 3 manages application state. Controllers extend `Notifier` classes to handle user interactions and update immutable state records. GoRouter controls screen transitions using a bottom navigation shell route. A listener monitors selected buildings to sync GoRouter paths with active selections, redirecting coordinate link lookups to `/map?lat=X&lng=Y` inside the primary tab navigation.

### Evaluation Guidelines
Markers can execute quality gates using the provided test scripts. Run `./scripts/check.sh --quick` in the repository root to verify:
- Code formatting and style rules
- Static analysis checks
- **295 widget and unit tests** covering map, favourites CRUD, routing, transit, settings, notifications, and shared widgets
- Localization key alignment across 35 languages
- Privacy configurations (confirming no analytics tracking packages exist)

The test suite runs mock geolocation providers. This avoids test failures on machines that lack GPS hardware.
