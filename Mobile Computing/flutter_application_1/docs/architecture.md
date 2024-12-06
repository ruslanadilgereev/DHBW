# System Architecture Documentation

## System Architecture Diagram

```mermaid
graph TB
    subgraph "Frontend (Flutter)"
        A[Flutter Mobile App] --> |HTTP Requests| B[Services Layer]
        B --> |State Management| C[UI Components]
        C --> |User Input| B
    end

    subgraph "Backend (Node.js)"
        D[Express Server] --> |Connection Pool| E[MySQL Database]
        D --> |Email Service| F[SMTP Server]
        
        subgraph "API Endpoints"
            G[Auth API]
            H[Training API]
            I[Booking API]
            J[Search API]
        end
        
        G --> D
        H --> D
        I --> D
        J --> D
    end

    B --> |REST API Calls| D

    subgraph "Database (MySQL)"
        E --> K[Users Table]
        E --> L[Trainings Table]
        E --> M[Bookings Table]
        E --> N[Tags Table]
    end

    classDef frontend fill:#a7c7e7,stroke:#000,stroke-width:2px;
    classDef backend fill:#98fb98,stroke:#000,stroke-width:2px;
    classDef database fill:#ffa07a,stroke:#000,stroke-width:2px;
    
    class A,B,C frontend;
    class D,F,G,H,I,J backend;
    class E,K,L,M,N database;
```

### Key Components

1. **Frontend Layer**
   - Flutter Mobile Application
   - Services for API communication
   - UI Components (Screens & Widgets)

2. **Backend Layer**
   - Express.js Server
   - RESTful API Endpoints
   - Email Service Integration
   - Connection Pool Management

3. **Database Layer**
   - MySQL Database
   - Core Tables:
     - Users: User management and authentication
     - Trainings: Training course information
     - Bookings: User-Training relationships
     - Tags: Training categorization

### Communication Flow
- Frontend communicates with backend through HTTP requests
- Backend uses connection pooling for efficient database operations
- Email notifications are sent through SMTP server
- All API endpoints are RESTful and handle JSON data

### Security Features
- Password hashing using bcrypt
- CORS protection
- Environment-based configuration
- Connection pool security

## API Flow Diagram

```mermaid
sequenceDiagram
    participant Client as Flutter App
    participant API as Node.js API
    participant DB as MySQL Database
    participant Mail as Email Service

    %% Authentication Flows
    rect rgb(240, 240, 240)
        Note over Client,DB: Authentication Flows
        Client->>+API: POST /api/login
        API->>DB: Query users table
        DB-->>API: User data
        API-->>-Client: JWT Token
    end

    %% Training Management Flows
    rect rgb(245, 245, 245)
        Note over Client,DB: Training Management
        Client->>+API: GET /api/trainings
        API->>DB: Query schulungen & related tables
        DB-->>API: Training data
        API-->>-Client: Training list with sessions

        Client->>+API: POST /api/trainings
        API->>DB: Insert into schulungen
        API->>DB: Insert into schulung_sessions
        DB-->>API: Confirmation
        API->>Mail: Send notification
        API-->>-Client: Success response

        Client->>+API: GET /api/trainings/search
        API->>DB: Query with tags & filters
        DB-->>API: Filtered results
        API-->>-Client: Matching trainings
    end

    %% Booking Flows
    rect rgb(240, 240, 240)
        Note over Client,DB: Booking Management
        Client->>+API: POST /api/bookings
        API->>DB: Check availability
        DB-->>API: Slot status
        API->>DB: Insert booking
        DB-->>API: Booking confirmed
        API->>Mail: Send booking confirmation
        API-->>-Client: Booking details

        Client->>+API: GET /api/users/:userId/bookings
        API->>DB: Query user bookings
        DB-->>API: Booking history
        API-->>-Client: User's bookings
    end

    %% Schedule Management
    rect rgb(245, 245, 245)
        Note over Client,DB: Schedule Management
        Client->>+API: GET /api/schulungstermin
        API->>DB: Query schedules & time slots
        DB-->>API: Schedule data
        API-->>-Client: Training schedule

        Client->>+API: POST /api/schulung_pause
        API->>DB: Insert break period
        DB-->>API: Confirmation
        API-->>-Client: Break scheduled
    end
```

### API Endpoints Overview

1. **Authentication**
   - `POST /api/login`: User authentication
   - Response: JWT token for subsequent requests

2. **Training Management**
   - `GET /api/trainings`: List all trainings
   - `POST /api/trainings`: Create new training
   - `PUT /api/trainings/:id`: Update training
   - `GET /api/trainings/search`: Search with filters
   - `GET /api/trainings/:id/tags`: Get training tags

3. **Booking System**
   - `POST /api/bookings`: Create booking
   - `DELETE /api/bookings`: Cancel booking
   - `GET /api/users/:userId/bookings`: User's bookings

4. **Schedule Management**
   - `GET /api/schulungstermin`: Get schedules
   - `POST /api/schulung_pause`: Add break periods
   - `GET /api/schulungstermin_zeitabschnitt`: Get time slots

### Data Flow Characteristics

1. **Security Measures**
   - JWT-based authentication
   - Request validation
   - SQL injection prevention

2. **Response Formats**
   - JSON responses
   - Standardized error formats
   - Status codes following HTTP conventions

3. **Integration Points**
   - Email notifications for bookings
   - Real-time schedule updates
   - Batch operations for efficiency

4. **Error Handling**
   - Validation errors
   - Business logic errors
   - Database constraints
   - Network issues

## Database Entity Relationship Diagram

```mermaid
erDiagram
    schulungen {
        int id PK
        varchar titel
        text beschreibung
        date gesamt_startdatum
        date gesamt_enddatum
        varchar ort
        int max_teilnehmer
        int dozent_id FK
        timestamp erstellt_am
        timestamp aktualisiert_am
        text tags
    }

    schulung_sessions {
        int id PK
        int schulung_id FK
        date datum
        time startzeit
        time endzeit
        enum typ
        varchar bemerkung
    }

    schulung_pause {
        int id PK
        int schulung_id FK
        date start_datum
        date end_datum
        varchar grund
    }

    schulungstermin {
        int Termin_ID PK
        int Schulung_ID FK
        int Trainer_ID FK
        int Ort_ID
        varchar Status
    }

    schulungstermin_zeitabschnitt {
        int Zeitabschnitt_ID PK
        int Termin_ID FK
        datetime Startzeit
        datetime Endzeit
    }

    schulungen_tags {
        int schulung_id FK
        int tag_id FK
    }

    tags {
        int id PK
        timestamp create_time
        varchar name
        varchar color
        text description
    }

    dozenten {
        int id PK
        varchar vorname
        varchar nachname
        varchar email
        varchar telefon
        timestamp erstellt_am
        timestamp aktualisiert_am
    }

    users {
        int id PK
        varchar email
        varchar password
        enum role
        varchar first_name
        varchar last_name
        varchar company
        varchar phone
        timestamp created_at
    }

    bookings {
        int id PK
        int user_id FK
        int training_id FK
    }

    schulungen ||--o{ schulung_sessions : "has"
    schulungen ||--o{ schulung_pause : "has"
    schulungen ||--o{ schulungen_tags : "categorized_by"
    schulungen ||--|| dozenten : "taught_by"
    tags ||--o{ schulungen_tags : "used_in"
    schulungstermin ||--o{ schulungstermin_zeitabschnitt : "has"
    schulungen ||--o{ schulungstermin : "scheduled_as"
    users ||--o{ bookings : "makes"
    schulungen ||--o{ bookings : "receives"

```

### Database Schema Details

1. **Schulungen (Trainings) Table**
   - Core training information including title, description, and location
   - Tracks overall start and end dates
   - Links to lecturer (dozent_id)
   - Includes participant limits and timestamps

2. **Schulung_Sessions Table**
   - Individual session details
   - Stores date and time information
   - Includes session type and remarks

3. **Schulung_Pause (Training Breaks) Table**
   - Manages break periods in trainings
   - Records start and end dates
   - Stores reason for break

4. **Schulungstermin (Training Schedule) Table**
   - Links trainings with trainers and locations
   - Tracks schedule status

5. **Schulungstermin_Zeitabschnitt (Time Slots) Table**
   - Detailed time management
   - Start and end times for specific periods

6. **Tags and Schulungen_Tags Tables**
   - Flexible categorization system
   - Includes color coding and descriptions
   - Many-to-many relationship with trainings

7. **Dozenten (Lecturers) Table**
   - Lecturer contact information
   - Tracks creation and update times

8. **Users Table**
   - User management with roles
   - Personal and contact information
   - Company affiliations

9. **Bookings Table**
   - Manages training registrations
   - Links users with trainings

### Key Relationships
- Each training (Schulung) has one lecturer (Dozent)
- Trainings can have multiple sessions and breaks
- Multiple tags can be assigned to trainings
- Users can book multiple trainings
- Training schedules can have multiple time slots

### Data Integrity Rules
- Timestamps track creation and modifications
- Foreign key relationships ensure data consistency
- Status tracking for training schedules
- Role-based user management

## State Management Flow Diagram

```mermaid
stateDiagram-v2
    [*] --> AppStart: Launch Application
    
    state AppStart {
        [*] --> CheckAuth: Initialize
        CheckAuth --> AuthState: Load Stored Token
        AuthState --> LoadingState: Valid Token
        AuthState --> UnauthorizedState: No Token
    }

    state "Provider States" as ProviderStates {
        state AuthenticationProvider {
            LoggedOut --> LoggedIn: Login Success
            LoggedIn --> LoggedOut: Logout
            LoggedIn --> TokenRefresh: Token Expiring
            TokenRefresh --> LoggedIn: New Token
            TokenRefresh --> LoggedOut: Refresh Failed
        }

        state TrainingProvider {
            LoadingTrainings --> TrainingsLoaded: Fetch Success
            TrainingsLoaded --> UpdatingTraining: Edit Training
            UpdatingTraining --> TrainingsLoaded: Update Success
            TrainingsLoaded --> FilteringTrainings: Apply Filters
            FilteringTrainings --> TrainingsLoaded: Filters Applied
        }

        state BookingProvider {
            IdleBooking --> ProcessingBooking: Book Training
            ProcessingBooking --> BookingSuccess: Booking Confirmed
            ProcessingBooking --> BookingError: Booking Failed
            BookingSuccess --> IdleBooking: Reset
            BookingError --> IdleBooking: Reset
        }

        state ThemeProvider {
            LightTheme --> DarkTheme: Toggle Theme
            DarkTheme --> LightTheme: Toggle Theme
        }
    }

    state "UI States" as UIStates {
        state CalendarView {
            MonthView --> WeekView: Switch View
            WeekView --> DayView: Switch View
            DayView --> MonthView: Switch View
        }

        state TrainingManagement {
            ViewMode --> EditMode: Edit Training
            EditMode --> ViewMode: Save/Cancel
            ViewMode --> CreateMode: New Training
            CreateMode --> ViewMode: Save/Cancel
        }

        state SearchState {
            Idle --> Searching: Input Change
            Searching --> ResultsFound: Has Results
            Searching --> NoResults: No Results
            ResultsFound --> Idle: Clear
            NoResults --> Idle: Clear
        }
    }

    state ErrorHandling {
        NetworkError --> RetryOperation: Retry
        ValidationError --> UserCorrection: Show Error
        ServerError --> ErrorNotification: Show Error
        ErrorNotification --> [*]: Dismiss
    }
```

### State Management Architecture

1. **Application States**
   - Initial loading state
   - Authentication state verification
   - Main application state

2. **Provider States**
   
   a. **AuthenticationProvider**
   - Manages user authentication status
   - Handles token refresh cycles
   - Controls login/logout transitions

   b. **TrainingProvider**
   - Manages training data lifecycle
   - Handles CRUD operations
   - Controls filtering and search states

   c. **BookingProvider**
   - Manages booking process states
   - Handles booking confirmations
   - Manages error states

   d. **ThemeProvider**
   - Controls application theme
   - Manages theme transitions

3. **UI States**

   a. **CalendarView**
   - Different calendar view modes
   - View transitions
   - Selection states

   b. **TrainingManagement**
   - Edit/View mode transitions
   - Creation flow states
   - Validation states

   c. **SearchState**
   - Search input handling
   - Results management
   - Empty state handling

4. **Error Handling States**
   - Network error states
   - Validation error states
   - Server error states
   - Recovery flows

### State Update Patterns

1. **Unidirectional Data Flow**
   - State changes flow down
   - Actions flow up
   - Predictable state updates

2. **State Isolation**
   - Providers maintain isolated states
   - Cross-provider communication through services
   - Controlled state access

3. **Error Recovery**
   - Automatic retry mechanisms
   - User-initiated recovery
   - Graceful degradation

4. **State Persistence**
   - Critical state persistence
   - State restoration on app launch
   - Cache management

### Best Practices

1. **State Updates**
   - Atomic state changes
   - Optimistic updates where appropriate
   - Proper error handling

2. **Performance**
   - Minimal rebuilds
   - Efficient state propagation
   - State cleanup on disposal

3. **Testing**
   - Testable state transitions
   - Mocked provider states
   - Error state verification

## Bugs and Revisions

### Known Issues and Status

```mermaid
timeline
    title Major Bug Fixes & Revisions Timeline
    section v1.0.0
        Initial Release : Authentication System
                       : Basic Training Management
                       : Calendar View
    section v1.1.0
        Bug Fixes : Token Refresh Logic
                  : Calendar Sync Issues
                  : Database Connection Pool
        Features : Enhanced Search
                : Email Notifications
    section v1.2.0
        Performance : State Management Optimization
                   : Database Query Optimization
        Security : JWT Implementation
                : Input Validation
    section Current
        Active Issues : Booking Conflict Resolution
                     : Theme Persistence
                     : Search Filter Performance
```

### Critical Issues

1. **Booking System**
   - **Issue**: Concurrent booking conflicts
   - **Status**: In Progress
   - **Priority**: High
   - **Impact**: User booking experience
   - **Planned Fix**: Implement booking queue system

2. **State Management**
   - **Issue**: Memory leaks in training list
   - **Status**: Under Investigation
   - **Priority**: Medium
   - **Impact**: App performance
   - **Planned Fix**: Optimize provider disposal

3. **Database**
   - **Issue**: Connection timeout during peak loads
   - **Status**: Fixed in v1.1.0
   - **Priority**: High
   - **Impact**: System reliability
   - **Solution**: Implemented connection pooling

### Recent Improvements

1. **Authentication System (v1.2.0)**
   - Implemented JWT token refresh
   - Added secure token storage
   - Enhanced error handling
   - Improved login flow

2. **Training Management (v1.1.0)**
   - Fixed session overlap issues
   - Added break period validation
   - Improved trainer assignment
   - Enhanced calendar sync

3. **Performance Optimizations (v1.2.0)**
   - Reduced API calls
   - Implemented caching
   - Optimized database queries
   - Improved state management

### Planned Revisions

1. **Short-term (Next Release)**
   - Booking conflict resolution system
   - Enhanced error reporting
   - Theme persistence fix
   - Search performance optimization

2. **Mid-term (Next Quarter)**
   - Real-time updates implementation
   - Advanced filtering system
   - Batch booking operations
   - Enhanced notification system

3. **Long-term (Future Releases)**
   - Offline mode support
   - Advanced analytics
   - Multi-language support
   - Integration with external calendars

### Testing and Quality Assurance

1. **Automated Testing**
   - Unit tests for core functionality
   - Integration tests for API endpoints
   - UI tests for critical flows
   - Performance benchmarks

2. **Manual Testing Procedures**
   - User acceptance testing
   - Cross-device validation
   - Edge case scenarios
   - Load testing

3. **Quality Metrics**
   - Code coverage: 85%
   - API response time: <200ms
   - UI render time: <16ms
   - Crash-free sessions: 99.5%

### Bug Reporting and Tracking

1. **Issue Classification**
   - Critical: System functionality
   - High: User experience
   - Medium: Non-critical features
   - Low: Minor improvements

2. **Reporting Process**
   - Issue identification
   - Reproduction steps
   - Environment details
   - Impact assessment
   - Priority assignment

3. **Resolution Workflow**
   - Issue verification
   - Development assignment
   - Code review
   - Testing validation
   - Production deployment

### Version Control Guidelines

1. **Branch Strategy**
   - main: Production code
   - develop: Integration branch
   - feature/*: New features
   - bugfix/*: Bug fixes
   - hotfix/*: Critical fixes

2. **Commit Conventions**
   - feat: New features
   - fix: Bug fixes
   - docs: Documentation
   - style: Formatting
   - refactor: Code restructuring
   - test: Testing updates

3. **Release Process**
   - Version bump
   - Changelog update
   - Testing validation
   - Documentation update
   - Deployment checklist

## Flutter Component Diagram

```mermaid
graph TB
    subgraph "Application Core"
        Main[main.dart]
        MainWrapper[MainWrapper]
    end

    subgraph "Screens Layer"
        direction TB
        HomeScreen[Home Screen]
        LoginScreen[Login Screen]
        RegScreen[Registration Screen]
        WelcomeScreen[Welcome Screen]
        ProfilePage[Profile Page]
        TrainingCalendar[Training Calendar]
        ManageTrainings[Manage Trainings]
    end

    subgraph "Services Layer"
        AuthService[Authentication Service]
        TrainingService[Training Service]
        LecturerService[Lecturer Service]
        TagService[Tag Service]
        ThemeService[Theme Service]
        HttpService[HTTP Service]
    end

    subgraph "State Management"
        AuthState[Auth State]
        TrainingState[Training State]
        ThemeState[Theme State]
    end

    subgraph "Data Models"
        TrainingModel[Training Model]
        UserModel[User Model]
        BookingModel[Booking Model]
        TagModel[Tag Model]
    end

    %% Core Connections
    Main --> MainWrapper
    MainWrapper --> HomeScreen
    MainWrapper --> AuthState

    %% Screen Navigation
    HomeScreen --> TrainingCalendar
    HomeScreen --> ProfilePage
    HomeScreen --> ManageTrainings
    
    %% Service Dependencies
    TrainingCalendar --> TrainingService
    ManageTrainings --> TrainingService
    ManageTrainings --> LecturerService
    ManageTrainings --> TagService
    LoginScreen --> AuthService
    RegScreen --> AuthService
    ProfilePage --> AuthService

    %% Service Layer Dependencies
    AuthService --> HttpService
    TrainingService --> HttpService
    LecturerService --> HttpService
    TagService --> HttpService

    %% State Management
    AuthService --> AuthState
    TrainingService --> TrainingState
    ThemeService --> ThemeState

    %% Data Model Usage
    TrainingService --> TrainingModel
    AuthService --> UserModel
    TrainingService --> BookingModel
    TagService --> TagModel

    classDef core fill:#f9f,stroke:#333,stroke-width:2px
    classDef screen fill:#bbf,stroke:#333,stroke-width:1px
    classDef service fill:#bfb,stroke:#333,stroke-width:1px
    classDef state fill:#fbf,stroke:#333,stroke-width:1px
    classDef model fill:#fbb,stroke:#333,stroke-width:1px

    class Main,MainWrapper core
    class HomeScreen,LoginScreen,RegScreen,WelcomeScreen,ProfilePage,TrainingCalendar,ManageTrainings screen
    class AuthService,TrainingService,LecturerService,TagService,ThemeService,HttpService service
    class AuthState,TrainingState,ThemeState state
    class TrainingModel,UserModel,BookingModel,TagModel model
```

### Component Architecture Overview

1. **Application Core**
   - `main.dart`: Application entry point
   - `MainWrapper`: Root widget managing navigation and auth state

2. **Screens Layer**
   - Authentication screens (Login, Registration, Welcome)
   - Main functionality screens (Calendar, Management)
   - User-related screens (Profile)
   - Each screen is a standalone module with its own state management

3. **Services Layer**
   - `AuthService`: User authentication and session management
   - `TrainingService`: Training CRUD operations
   - `LecturerService`: Lecturer management
   - `TagService`: Training categorization
   - `ThemeService`: App theming
   - `HttpService`: Base HTTP communication

4. **State Management**
   - Authentication state
   - Training data state
   - Theme state
   - Persistent state management for app-wide data

5. **Data Models**
   - Clean data representations
   - JSON serialization/deserialization
   - Type safety and validation

### Key Design Patterns

1. **Service Pattern**
   - Separation of concerns
   - Reusable business logic
   - Centralized API communication

2. **Repository Pattern**
   - Data access abstraction
   - Caching capabilities
   - Error handling

3. **Provider Pattern**
   - State management
   - Dependency injection
   - Widget rebuilding optimization

4. **Factory Pattern**
   - Model instantiation
   - Configuration management
   - Plugin initialization

### Component Communication

1. **Vertical Communication**
   - Screens → Services → HTTP Client
   - State updates flow up through providers
   - Error handling propagation

2. **Horizontal Communication**
   - Service-to-service communication through state
   - Screen-to-screen navigation with parameters
   - Shared utility functions

3. **State Propagation**
   - Real-time updates
   - Cache invalidation
   - Optimistic update
