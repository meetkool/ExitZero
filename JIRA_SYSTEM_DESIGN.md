# Jira Mobile - Full System Design Document

## 1. System Architecture Overview

### High-Level Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Android Application                      │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │  │
│  │  │  UI Layer   │  │  Domain     │  │  Data Layer  │  │  │
│  │  │  (Jetpack   │  │  (Use Cases │  │  (Repository │  │  │
│  │  │   Compose)  │  │   & Models) │  │   Pattern)   │  │  │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │  │
│  │  │  Local DB   │  │  Sync       │  │  Offline     │  │  │
│  │  │  (Room)     │  │  Engine     │  │  Queue       │  │  │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/WSS
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      API GATEWAY LAYER                       │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐        │
│  │   Load      │  │    Auth     │  │   Rate       │        │
│  │  Balancer   │  │   (JWT)     │  │   Limiter    │        │
│  └─────────────┘  └─────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     SERVICE LAYER                            │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐        │
│  │  Project    │  │   Issue     │  │   User       │        │
│  │  Service    │  │   Service   │  │   Service    │        │
│  └─────────────┘  └─────────────┘  └──────────────┘        │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐        │
│  │  Sprint     │  │  Workflow   │  │ Notification │        │
│  │  Service    │  │   Service   │  │   Service    │        │
│  └─────────────┘  └─────────────┘  └──────────────┘        │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐        │
│  │   Search    │  │   Comment   │  │  Attachment  │        │
│  │   Service   │  │   Service   │  │   Service    │        │
│  └─────────────┘  └─────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     DATA LAYER                               │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐        │
│  │ PostgreSQL  │  │    Redis    │  │    S3/MinIO  │        │
│  │  (Primary)  │  │   (Cache)   │  │ (File Store) │        │
│  └─────────────┘  └─────────────┘  └──────────────┘        │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐        │
│  │ Elasticsearch│  │   Kafka/    │  │   MongoDB    │        │
│  │   (Search)  │  │   RabbitMQ  │  │  (Analytics) │        │
│  └─────────────┘  └─────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Backend:**
- Language: Kotlin/Java or Node.js/TypeScript
- Framework: Spring Boot or NestJS
- Database: PostgreSQL (primary), Redis (cache), MongoDB (analytics)
- Message Queue: Apache Kafka or RabbitMQ
- Search: Elasticsearch
- File Storage: AWS S3 or MinIO
- Real-time: WebSocket/Socket.io

**Android:**
- Language: Kotlin
- UI Framework: Jetpack Compose
- Architecture: MVVM + Clean Architecture
- Local DB: Room
- Network: Retrofit + OkHttp
- DI: Hilt
- State Management: StateFlow/Compose State
- Navigation: Jetpack Navigation

---

## 2. Backend Architecture

### Microservices Structure

```
jira-backend/
├── api-gateway/
│   ├── src/
│   │   ├── config/
│   │   ├── filters/
│   │   ├── middleware/
│   │   └── routes/
│   └── Dockerfile
├── services/
│   ├── auth-service/
│   ├── project-service/
│   ├── issue-service/
│   ├── user-service/
│   ├── sprint-service/
│   ├── workflow-service/
│   ├── notification-service/
│   ├── search-service/
│   ├── comment-service/
│   └── attachment-service/
├── shared/
│   ├── common/
│   ├── events/
│   └── models/
└── infrastructure/
    ├── docker-compose.yml
    ├── k8s/
    └── terraform/
```

### Service Descriptions

#### 2.1 Auth Service
**Responsibilities:**
- User authentication (JWT/OAuth2)
- Token refresh
- Password management
- Multi-factor authentication
- Session management

**Endpoints:**
```
POST /auth/login
POST /auth/register
POST /auth/refresh
POST /auth/logout
POST /auth/forgot-password
POST /auth/reset-password
POST /auth/verify-email
POST /auth/mfa/enable
POST /auth/mfa/verify
```

#### 2.2 Project Service
**Responsibilities:**
- Project CRUD operations
- Project members management
- Project settings
- Project templates
- Project permissions

**Endpoints:**
```
GET    /projects
POST   /projects
GET    /projects/:id
PUT    /projects/:id
DELETE /projects/:id
GET    /projects/:id/members
POST   /projects/:id/members
DELETE /projects/:id/members/:userId
GET    /projects/:id/settings
PUT    /projects/:id/settings
```

#### 2.3 Issue Service
**Responsibilities:**
- Issue CRUD operations
- Issue linking
- Issue history/audit
- Subtasks
- Time tracking
- Labels management

**Endpoints:**
```
GET    /projects/:projectId/issues
POST   /projects/:projectId/issues
GET    /issues/:id
PUT    /issues/:id
DELETE /issues/:id
GET    /issues/:id/history
POST   /issues/:id/link
POST   /issues/:id/watch
GET    /issues/:id/subtasks
POST   /issues/:id/subtasks
PUT    /issues/:id/assignee
PUT    /issues/:id/status
PUT    /issues/:id/priority
```

#### 2.4 User Service
**Responsibilities:**
- User profile management
- User preferences
- User search
- Teams management
- User activity

**Endpoints:**
```
GET    /users/me
PUT    /users/me
GET    /users/:id
GET    /users/search
GET    /users/:id/activity
PUT    /users/preferences
GET    /teams
POST   /teams
GET    /teams/:id
PUT    /teams/:id
DELETE /teams/:id
```

#### 2.5 Sprint Service
**Responsibilities:**
- Sprint CRUD
- Sprint planning
- Burndown charts
- Velocity tracking
- Sprint reports

**Endpoints:**
```
GET    /projects/:projectId/sprints
POST   /projects/:projectId/sprints
GET    /sprints/:id
PUT    /sprints/:id
DELETE /sprints/:id
POST   /sprints/:id/start
POST   /sprints/:id/complete
POST   /sprints/:id/issues
GET    /sprints/:id/burndown
GET    /sprints/:id/velocity
GET    /sprints/:id/report
```

#### 2.6 Workflow Service
**Responsibilities:**
- Workflow definitions
- Status transitions
- Custom workflows
- Automation rules
- Triggers

**Endpoints:**
```
GET    /projects/:projectId/workflows
POST   /projects/:projectId/workflows
GET    /workflows/:id
PUT    /workflows/:id
DELETE /workflows/:id
GET    /workflows/:id/transitions
POST   /workflows/:id/transitions
PUT    /workflows/:id/transitions/:transitionId
GET    /workflows/:id/automations
POST   /workflows/:id/automations
```

#### 2.7 Notification Service
**Responsibilities:**
- Push notifications (FCM/APNS)
- Email notifications
- In-app notifications
- Notification preferences
- WebSocket events

**Endpoints:**
```
GET    /notifications
PUT    /notifications/:id/read
PUT    /notifications/read-all
GET    /notifications/preferences
PUT    /notifications/preferences
POST   /notifications/subscribe
POST   /notifications/unsubscribe
WebSocket: /ws/notifications
```

#### 2.8 Search Service
**Responsibilities:**
- Full-text search
- Faceted search
- Query parsing (JQL-like)
- Search suggestions
- Recent searches

**Endpoints:**
```
GET    /search?q={query}&filters={filters}
GET    /search/suggestions?q={query}
GET    /search/filters
POST   /search/save
GET    /search/saved
DELETE /search/saved/:id
GET    /search/recent
```

#### 2.9 Comment Service
**Responsibilities:**
- Comment CRUD
- Comment threading
- Mentions
- Comment reactions
- Comment notifications

**Endpoints:**
```
GET    /issues/:issueId/comments
POST   /issues/:issueId/comments
GET    /comments/:id
PUT    /comments/:id
DELETE /comments/:id
POST   /comments/:id/reply
POST   /comments/:id/react
```

#### 2.10 Attachment Service
**Responsibilities:**
- File upload/download
- Image thumbnails
- File versioning
- Virus scanning
- Storage management

**Endpoints:**
```
POST   /attachments/upload (multipart/form-data)
GET    /attachments/:id
GET    /attachments/:id/download
DELETE /attachments/:id
GET    /attachments/:id/thumbnail
POST   /attachments/bulk-upload
```

---

## 3. Database Schema Design

### 3.1 Core Tables

```sql
-- Users & Authentication
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'en',
    email_verified BOOLEAN DEFAULT FALSE,
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_secret VARCHAR(255),
    status VARCHAR(20) DEFAULT 'active',
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Projects
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    avatar_url TEXT,
    project_type VARCHAR(20) DEFAULT 'scrum',
    lead_id UUID REFERENCES users(id),
    default_assignee_id UUID REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'active',
    is_private BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Project Members
CREATE TABLE project_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member',
    permissions JSONB DEFAULT '{}',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(project_id, user_id)
);

-- Issue Types
CREATE TABLE issue_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    color VARCHAR(7),
    is_subtask BOOLEAN DEFAULT FALSE,
    hierarchy_level INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Issues
CREATE TABLE issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    issue_type_id UUID REFERENCES issue_types(id),
    issue_key VARCHAR(50) NOT NULL,
    summary VARCHAR(500) NOT NULL,
    description TEXT,
    status_id UUID REFERENCES issue_statuses(id),
    priority VARCHAR(20) DEFAULT 'medium',
    assignee_id UUID REFERENCES users(id),
    reporter_id UUID REFERENCES users(id),
    parent_id UUID REFERENCES issues(id),
    sprint_id UUID REFERENCES sprints(id),
    epic_id UUID REFERENCES issues(id),
    story_points INTEGER,
    time_estimate INTEGER,
    time_spent INTEGER,
    original_estimate INTEGER,
    due_date DATE,
    labels TEXT[],
    components TEXT[],
    environment TEXT,
    resolution VARCHAR(50),
    resolution_date TIMESTAMP,
    votes_count INTEGER DEFAULT 0,
    watches_count INTEGER DEFAULT 0,
    position INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(project_id, issue_key)
);

-- Issue Statuses
CREATE TABLE issue_statuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    category VARCHAR(20) NOT NULL, -- todo, in_progress, done
    color VARCHAR(7),
    position INTEGER DEFAULT 0,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Workflows & Transitions
CREATE TABLE workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE workflow_transitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES workflows(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    from_status_id UUID REFERENCES issue_statuses(id),
    to_status_id UUID REFERENCES issue_statuses(id),
    conditions JSONB DEFAULT '[]',
    validators JSONB DEFAULT '[]',
    post_functions JSONB DEFAULT '[]',
    screen_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sprints
CREATE TABLE sprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    goal TEXT,
    state VARCHAR(20) DEFAULT 'future', -- future, active, closed
    start_date DATE,
    end_date DATE,
    completed_date DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Comments
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID REFERENCES issues(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id),
    body TEXT NOT NULL,
    parent_id UUID REFERENCES comments(id),
    edited_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Attachments
CREATE TABLE attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID REFERENCES issues(id) ON DELETE CASCADE,
    uploader_id UUID REFERENCES users(id),
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100),
    storage_path TEXT NOT NULL,
    thumbnail_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Issue History
CREATE TABLE issue_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID REFERENCES issues(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id),
    field VARCHAR(50) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    change_type VARCHAR(20) DEFAULT 'updated',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Labels
CREATE TABLE labels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    color VARCHAR(7),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(project_id, name)
);

-- Teams
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    avatar_url TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE team_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(team_id, user_id)
);

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Preferences
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    notification_email_enabled BOOLEAN DEFAULT TRUE,
    notification_push_enabled BOOLEAN DEFAULT TRUE,
    notification_mentions_enabled BOOLEAN DEFAULT TRUE,
    notification_assignments_enabled BOOLEAN DEFAULT TRUE,
    theme VARCHAR(20) DEFAULT 'system',
    sidebar_collapsed BOOLEAN DEFAULT FALSE,
    default_project_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for Performance
CREATE INDEX idx_issues_project_id ON issues(project_id);
CREATE INDEX idx_issues_assignee_id ON issues(assignee_id);
CREATE INDEX idx_issues_sprint_id ON issues(sprint_id);
CREATE INDEX idx_issues_status_id ON issues(status_id);
CREATE INDEX idx_issues_created_at ON issues(created_at);
CREATE INDEX idx_comments_issue_id ON comments(issue_id);
CREATE INDEX idx_project_members_project_id ON project_members(project_id);
CREATE INDEX idx_project_members_user_id ON project_members(user_id);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
```

### 3.2 Redis Cache Schema

```
# User sessions
session:{token} -> user data (TTL: 24h)

# Rate limiting
rate_limit:{user_id}:{endpoint} -> counter (TTL: 1m)

# Project cache
project:{project_id} -> project data (TTL: 1h)
project:{project_key} -> project_id mapping

# Issue cache
issue:{issue_id} -> issue data (TTL: 30m)
issue:{project_key}:{issue_number} -> issue_id

# Sprint cache
sprint:{sprint_id} -> sprint data (TTL: 30m)
project:{project_id}:sprints -> list of sprint IDs

# Search cache
search:{hash} -> search results (TTL: 5m)

# Real-time presence
presence:{user_id} -> { status, last_seen, project_id }

# Notification queues
notifications:{user_id} -> sorted set of notification IDs
```

---

## 4. Android App Architecture

### 4.1 Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    UI (Compose)                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │  Screens │ │  Dialogs │ │  Sheets  │ │ Snackbars│ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              ViewModels (MVVM)                        │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │   State  │ │  Events  │ │ Effects  │ │  Saved   │ │   │
│  │  │  (Flow)  │ │          │ │          │ │  State   │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Use Cases (Interactors)                  │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │  Create  │ │  Update  │ │  Delete  │ │   Get    │ │   │
│  │  │  Issue   │ │  Issue   │ │  Issue   │ │  Issues  │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   Models (Domain)                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │   Issue  │ │  Project │ │   User   │ │  Sprint  │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                       DATA LAYER                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Repository Pattern                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │  Issue   │ │  Project │ │   User   │ │  Sprint  │ │   │
│  │  │   Repo   │ │   Repo   │ │   Repo   │ │   Repo   │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Data Sources                             │   │
│  │  ┌──────────────────┐  ┌──────────────────────────┐  │   │
│  │  │   Remote (API)   │  │      Local (Room)        │  │   │
│  │  │  ┌────────────┐  │  │  ┌────────────────────┐  │  │   │
│  │  │  │  Retrofit  │  │  │  │      Room DB       │  │  │   │
│  │  │  │  Services  │  │  │  │  ┌──────────────┐  │  │  │   │
│  │  │  └────────────┘  │  │  │  │     DAOs     │  │  │  │   │
│  │  │  ┌────────────┐  │  │  │  └──────────────┘  │  │  │   │
│  │  │  │   WebSocket│  │  │  │  ┌──────────────┐  │  │  │   │
│  │  │  │   Client   │  │  │  │ │   Entities   │  │  │  │   │
│  │  │  └────────────┘  │  │  │  └──────────────┘  │  │  │   │
│  │  └──────────────────┘  │  └────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 Project Structure

```
app/
├── build.gradle.kts
├── src/
│   ├── main/
│   │   ├── java/com/jira/mobile/
│   │   │   ├── JiraApplication.kt
│   │   │   ├── di/
│   │   │   │   ├── AppModule.kt
│   │   │   │   ├── NetworkModule.kt
│   │   │   │   ├── DatabaseModule.kt
│   │   │   │   ├── RepositoryModule.kt
│   │   │   │   └── UseCaseModule.kt
│   │   │   ├── data/
│   │   │   │   ├── local/
│   │   │   │   │   ├── JiraDatabase.kt
│   │   │   │   │   ├── dao/
│   │   │   │   │   │   ├── IssueDao.kt
│   │   │   │   │   │   ├── ProjectDao.kt
│   │   │   │   │   │   ├── SprintDao.kt
│   │   │   │   │   │   ├── UserDao.kt
│   │   │   │   │   │   └── CommentDao.kt
│   │   │   │   │   ├── entity/
│   │   │   │   │   │   ├── IssueEntity.kt
│   │   │   │   │   │   ├── ProjectEntity.kt
│   │   │   │   │   │   └── ...
│   │   │   │   │   └── converter/
│   │   │   │   │       └── Converters.kt
│   │   │   │   ├── remote/
│   │   │   │   │   ├── api/
│   │   │   │   │   │   ├── JiraApiService.kt
│   │   │   │   │   │   ├── AuthApi.kt
│   │   │   │   │   │   ├── IssueApi.kt
│   │   │   │   │   │   ├── ProjectApi.kt
│   │   │   │   │   │   └── SprintApi.kt
│   │   │   │   │   ├── dto/
│   │   │   │   │   │   ├── IssueDto.kt
│   │   │   │   │   │   ├── ProjectDto.kt
│   │   │   │   │   │   └── ...
│   │   │   │   │   ├── interceptor/
│   │   │   │   │   │   ├── AuthInterceptor.kt
│   │   │   │   │   │   └── ErrorInterceptor.kt
│   │   │   │   │   └── websocket/
│   │   │   │   │       └── WebSocketManager.kt
│   │   │   │   ├── repository/
│   │   │   │   │   ├── IssueRepositoryImpl.kt
│   │   │   │   │   ├── ProjectRepositoryImpl.kt
│   │   │   │   │   ├── SprintRepositoryImpl.kt
│   │   │   │   │   └── UserRepositoryImpl.kt
│   │   │   │   └── sync/
│   │   │   │       ├── SyncManager.kt
│   │   │   │       ├── SyncWorker.kt
│   │   │   │       └── SyncStatus.kt
│   │   │   ├── domain/
│   │   │   │   ├── model/
│   │   │   │   │   ├── Issue.kt
│   │   │   │   │   ├── Project.kt
│   │   │   │   │   ├── User.kt
│   │   │   │   │   ├── Sprint.kt
│   │   │   │   │   ├── Comment.kt
│   │   │   │   │   └── Attachment.kt
│   │   │   │   ├── repository/
│   │   │   │   │   ├── IssueRepository.kt
│   │   │   │   │   ├── ProjectRepository.kt
│   │   │   │   │   └── SprintRepository.kt
│   │   │   │   └── usecase/
│   │   │   │       ├── issue/
│   │   │   │       │   ├── GetIssuesUseCase.kt
│   │   │   │       │   ├── CreateIssueUseCase.kt
│   │   │   │       │   ├── UpdateIssueUseCase.kt
│   │   │   │       │   └── DeleteIssueUseCase.kt
│   │   │   │       ├── project/
│   │   │   │       │   └── ...
│   │   │   │       └── auth/
│   │   │   │           ├── LoginUseCase.kt
│   │   │   │           └── LogoutUseCase.kt
│   │   │   ├── presentation/
│   │   │   │   ├── common/
│   │   │   │   │   ├── theme/
│   │   │   │   │   │   ├── Color.kt
│   │   │   │   │   │   ├── Theme.kt
│   │   │   │   │   │   └── Type.kt
│   │   │   │   │   ├── components/
│   │   │   │   │   │   ├── JiraTopAppBar.kt
│   │   │   │   │   │   ├── JiraBottomNav.kt
│   │   │   │   │   │   ├── JiraTextField.kt
│   │   │   │   │   │   ├── JiraButton.kt
│   │   │   │   │   │   ├── PriorityChip.kt
│   │   │   │   │   │   ├── StatusBadge.kt
│   │   │   │   │   │   ├── UserAvatar.kt
│   │   │   │   │   │   └── LoadingIndicator.kt
│   │   │   │   │   └── util/
│   │   │   │   │       ├── DateUtils.kt
│   │   │   │   │       └── Extensions.kt
│   │   │   │   ├── navigation/
│   │   │   │   │   ├── JiraNavHost.kt
│   │   │   │   │   ├── Screens.kt
│   │   │   │   │   └── NavigationItem.kt
│   │   │   │   ├── auth/
│   │   │   │   │   ├── LoginScreen.kt
│   │   │   │   │   ├── LoginViewModel.kt
│   │   │   │   │   └── LoginUiState.kt
│   │   │   │   ├── projects/
│   │   │   │   │   ├── ProjectListScreen.kt
│   │   │   │   │   ├── ProjectDetailScreen.kt
│   │   │   │   │   ├── ProjectListViewModel.kt
│   │   │   │   │   └── components/
│   │   │   │   │       ├── ProjectCard.kt
│   │   │   │   │       └── ProjectStats.kt
│   │   │   │   ├── issues/
│   │   │   │   │   ├── IssueListScreen.kt
│   │   │   │   │   ├── IssueDetailScreen.kt
│   │   │   │   │   ├── CreateIssueScreen.kt
│   │   │   │   │   ├── IssueListViewModel.kt
│   │   │   │   │   └── components/
│   │   │   │   │       ├── IssueCard.kt
│   │   │   │   │       ├── IssueListItem.kt
│   │   │   │   │       ├── KanbanBoard.kt
│   │   │   │   │       ├── KanbanColumn.kt
│   │   │   │   │       └── KanbanCard.kt
│   │   │   │   ├── sprints/
│   │   │   │   │   ├── SprintListScreen.kt
│   │   │   │   │   ├── SprintBoardScreen.kt
│   │   │   │   │   ├── SprintDetailScreen.kt
│   │   │   │   │   └── components/
│   │   │   │   │       ├── SprintCard.kt
│   │   │   │   │       └── BurndownChart.kt
│   │   │   │   ├── search/
│   │   │   │   │   ├── SearchScreen.kt
│   │   │   │   │   ├── SearchViewModel.kt
│   │   │   │   │   └── components/
│   │   │   │   │       ├── SearchBar.kt
│   │   │   │   │       └── FilterChips.kt
│   │   │   │   ├── notifications/
│   │   │   │   │   ├── NotificationScreen.kt
│   │   │   │   │   └── components/
│   │   │   │   │       └── NotificationItem.kt
│   │   │   │   └── profile/
│   │   │   │       ├── ProfileScreen.kt
│   │   │   │       └── SettingsScreen.kt
│   │   │   └── util/
│   │   │       ├── Constants.kt
│   │   │       ├── Resource.kt
│   │   │       └── Result.kt
│   │   └── res/
│   │       ├── values/
│   │       ├── drawable/
│   │       └── mipmap/
│   └── test/
└── build.gradle.kts
```

---

## 5. Android UI Screens Design

### 5.1 Screen Navigation Flow

```
Login Screen
     │
     ▼
Home (Bottom Navigation)
  │
  ├── Projects Tab
  │     ├── Project List
  │     │     └── Project Card
  │     └── Project Detail
  │           ├── Project Info
  │           ├── Team Members
  │           └── Statistics
  │
  ├── Issues Tab (Default)
  │     ├── Issue List
  │     │     ├── Filter Bar
  │     │     ├── Search Bar
  │     │     └── Issue List Item
  │     ├── Issue Detail
  │     │     ├── Header (Title, Status, Priority)
  │     │     ├── Description
  │     │     ├── Assignee & Reporter
  │     │     ├── Custom Fields
  │     │     ├── Comments
  │     │     ├── Attachments
  │     │     └── Activity History
  │     └── Create/Edit Issue
  │           ├── Form Fields
  │           └── Attachment Picker
  │
  ├── Sprint Tab
  │     ├── Sprint Board (Kanban)
  │     │     ├── Columns (To Do, In Progress, Done)
  │     │     └── Draggable Cards
  │     ├── Sprint List
  │     │     ├── Active Sprint
  │     │     └── Future/Closed Sprints
  │     └── Sprint Report
  │
  ├── Notifications Tab
  │     └── Notification List
  │
  └── Profile Tab
        ├── User Profile
        ├── Settings
        ├── Dark Mode Toggle
        └── Logout
```

### 5.2 Key Screen Specifications

#### Login Screen
- **Components:**
  - App logo/branding
  - Email input field
  - Password input field (with visibility toggle)
  - Login button
  - "Forgot password?" link
  - "Create account" link
  - Biometric login option
  - Social login buttons (optional)

#### Issue List Screen
- **Components:**
  - Search bar at top
  - Filter chips (Status, Assignee, Priority, Sprint)
  - FAB (Floating Action Button) to create issue
  - List/Grid toggle
  - Issue list items with:
    - Issue key (e.g., PROJ-123)
    - Summary
    - Status badge
    - Priority icon
    - Assignee avatar
    - Story points (if applicable)
  - Pull-to-refresh
  - Pagination

#### Issue Detail Screen
- **Components:**
  - Collapsible top app bar with issue key
  - Issue type icon + title
  - Status dropdown
  - Priority selector
  - Assignee picker
  - Reporter info
  - Labels chips
  - Description (rich text/markdown)
  - Attachments carousel
  - Subtasks section
  - Linked issues
  - Comments section with:
    - Threaded replies
    - @mentions support
    - Rich text input
  - Activity/history timeline
  - Edit button
  - More options menu

#### Kanban Board Screen
- **Components:**
  - Horizontal scrollable columns
  - Each column:
    - Header with status name + issue count
    - Vertical list of cards
  - Cards:
    - Draggable
    - Issue key
    - Summary (truncated)
    - Assignee avatar
    - Priority icon
    - Story points badge
    - Labels (if space)
  - Drag & drop between columns
  - Column overflow indicator
  - Sprint selector dropdown
  - Quick filters

#### Create Issue Screen
- **Components:**
  - Project selector
  - Issue type selector
  - Summary input
  - Description editor (rich text)
  - Priority dropdown
  - Assignee picker (with search)
  - Sprint assignment
  - Epic link
  - Labels selector
  - Components selector
  - Custom fields (dynamic)
  - Attachments section
  - Create button (disabled until valid)

---

## 6. API Endpoints (Complete Reference)

### 6.1 Authentication
```
POST   /api/v1/auth/login
POST   /api/v1/auth/register
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
POST   /api/v1/auth/forgot-password
POST   /api/v1/auth/reset-password
POST   /api/v1/auth/verify-email
POST   /api/v1/auth/biometric/enable
POST   /api/v1/auth/biometric/verify
GET    /api/v1/auth/me
```

### 6.2 Projects
```
GET    /api/v1/projects
POST   /api/v1/projects
GET    /api/v1/projects/:id
PUT    /api/v1/projects/:id
DELETE /api/v1/projects/:id
GET    /api/v1/projects/:id/members
POST   /api/v1/projects/:id/members
DELETE /api/v1/projects/:id/members/:userId
PUT    /api/v1/projects/:id/members/:userId/role
GET    /api/v1/projects/:id/settings
PUT    /api/v1/projects/:id/settings
GET    /api/v1/projects/:id/stats
GET    /api/v1/projects/:id/activity
```

### 6.3 Issues
```
GET    /api/v1/projects/:projectId/issues
POST   /api/v1/projects/:projectId/issues
GET    /api/v1/issues/:id
PUT    /api/v1/issues/:id
DELETE /api/v1/issues/:id
GET    /api/v1/issues/:id/history
POST   /api/v1/issues/:id/link
DELETE /api/v1/issues/:id/link/:linkId
POST   /api/v1/issues/:id/watch
DELETE /api/v1/issues/:id/watch
GET    /api/v1/issues/:id/watchers
GET    /api/v1/issues/:id/subtasks
POST   /api/v1/issues/:id/subtasks
PUT    /api/v1/issues/:id/assignee
PUT    /api/v1/issues/:id/status
PUT    /api/v1/issues/:id/priority
PUT    /api/v1/issues/:id/sprint
PUT    /api/v1/issues/:id/epic
PUT    /api/v1/issues/:id/labels
POST   /api/v1/issues/bulk-update
POST   /api/v1/issues/bulk-delete
```

### 6.4 Sprints
```
GET    /api/v1/projects/:projectId/sprints
POST   /api/v1/projects/:projectId/sprints
GET    /api/v1/sprints/:id
PUT    /api/v1/sprints/:id
DELETE /api/v1/sprints/:id
POST   /api/v1/sprints/:id/start
POST   /api/v1/sprints/:id/complete
POST   /api/v1/sprints/:id/reorder
GET    /api/v1/sprints/:id/issues
POST   /api/v1/sprints/:id/issues
DELETE /api/v1/sprints/:id/issues/:issueId
GET    /api/v1/sprints/:id/burndown
GET    /api/v1/sprints/:id/velocity
GET    /api/v1/sprints/:id/report
```

### 6.5 Comments
```
GET    /api/v1/issues/:issueId/comments
POST   /api/v1/issues/:issueId/comments
GET    /api/v1/comments/:id
PUT    /api/v1/comments/:id
DELETE /api/v1/comments/:id
POST   /api/v1/comments/:id/reply
POST   /api/v1/comments/:id/react
DELETE /api/v1/comments/:id/react/:reactionId
```

### 6.6 Attachments
```
POST   /api/v1/attachments (multipart/form-data)
POST   /api/v1/attachments/bulk (multipart/form-data)
GET    /api/v1/attachments/:id
GET    /api/v1/attachments/:id/download
DELETE /api/v1/attachments/:id
GET    /api/v1/attachments/:id/thumbnail
```

### 6.7 Search
```
GET    /api/v1/search?q={query}&projectId={id}&filters={filters}&sort={sort}&page={page}&limit={limit}
GET    /api/v1/search/suggestions?q={query}&projectId={id}
GET    /api/v1/search/filters
GET    /api/v1/search/saved
POST   /api/v1/search/saved
DELETE /api/v1/search/saved/:id
GET    /api/v1/search/recent
```

### 6.8 Notifications
```
GET    /api/v1/notifications
PUT    /api/v1/notifications/:id/read
PUT    /api/v1/notifications/read-all
GET    /api/v1/notifications/unread-count
GET    /api/v1/notifications/preferences
PUT    /api/v1/notifications/preferences
POST   /api/v1/notifications/push-token
DELETE /api/v1/notifications/push-token
```

### 6.9 Users
```
GET    /api/v1/users/me
PUT    /api/v1/users/me
GET    /api/v1/users/:id
GET    /api/v1/users/search?q={query}
GET    /api/v1/users/:id/activity
PUT    /api/v1/users/preferences
GET    /api/v1/users/:id/teams
```

### 6.10 Teams
```
GET    /api/v1/teams
POST   /api/v1/teams
GET    /api/v1/teams/:id
PUT    /api/v1/teams/:id
DELETE /api/v1/teams/:id
GET    /api/v1/teams/:id/members
POST   /api/v1/teams/:id/members
DELETE /api/v1/teams/:id/members/:userId
```

---

## 7. Data Models

### 7.1 Domain Models (Kotlin)

```kotlin
// Issue Model
data class Issue(
    val id: String,
    val projectId: String,
    val issueKey: String,
    val issueType: IssueType,
    val summary: String,
    val description: String?,
    val status: IssueStatus,
    val priority: Priority,
    val assignee: User?,
    val reporter: User,
    val parent: Issue?,
    val sprint: Sprint?,
    val epic: Issue?,
    val storyPoints: Int?,
    val timeEstimate: Int?,
    val timeSpent: Int?,
    val dueDate: LocalDate?,
    val labels: List<String>,
    val components: List<String>,
    val environment: String?,
    val resolution: String?,
    val resolutionDate: Instant?,
    val votesCount: Int,
    val watchesCount: Int,
    val isWatching: Boolean,
    val subtasks: List<Issue>,
    val linkedIssues: List<IssueLink>,
    val attachments: List<Attachment>,
    val comments: List<Comment>,
    val customFields: Map<String, Any>,
    val createdAt: Instant,
    val updatedAt: Instant
)

// Project Model
data class Project(
    val id: String,
    val key: String,
    val name: String,
    val description: String?,
    val avatarUrl: String?,
    val projectType: ProjectType,
    val lead: User,
    val defaultAssignee: User?,
    val status: ProjectStatus,
    val isPrivate: Boolean,
    val members: List<ProjectMember>,
    val issueTypes: List<IssueType>,
    val statuses: List<IssueStatus>,
    val labels: List<Label>,
    val createdAt: Instant,
    val updatedAt: Instant
)

// Sprint Model
data class Sprint(
    val id: String,
    val projectId: String,
    val name: String,
    val goal: String?,
    val state: SprintState,
    val startDate: LocalDate?,
    val endDate: LocalDate?,
    val completedDate: LocalDate?,
    val createdBy: User,
    val issues: List<Issue>,
    val totalPoints: Int,
    val completedPoints: Int,
    val createdAt: Instant
)

// User Model
data class User(
    val id: String,
    val email: String,
    val username: String,
    val firstName: String?,
    val lastName: String?,
    val avatarUrl: String?,
    val timezone: String,
    val language: String,
    val status: UserStatus
)

// Comment Model
data class Comment(
    val id: String,
    val issueId: String,
    val author: User,
    val body: String,
    val parentId: String?,
    val replies: List<Comment>,
    val reactions: List<Reaction>,
    val editedAt: Instant?,
    val createdAt: Instant
)

// Enums
enum class Priority { HIGHEST, HIGH, MEDIUM, LOW, LOWEST }
enum class ProjectType { SCRUM, KANBAN }
enum class ProjectStatus { ACTIVE, ARCHIVED }
enum class SprintState { FUTURE, ACTIVE, CLOSED }
enum class UserStatus { ACTIVE, INACTIVE }
```

### 7.2 DTO Models (API)

```kotlin
// Issue DTO
data class IssueDto(
    @SerializedName("id") val id: String,
    @SerializedName("project_id") val projectId: String,
    @SerializedName("issue_key") val issueKey: String,
    @SerializedName("issue_type") val issueType: IssueTypeDto,
    @SerializedName("summary") val summary: String,
    @SerializedName("description") val description: String?,
    @SerializedName("status") val status: IssueStatusDto,
    @SerializedName("priority") val priority: String,
    @SerializedName("assignee") val assignee: UserDto?,
    @SerializedName("reporter") val reporter: UserDto,
    @SerializedName("parent_id") val parentId: String?,
    @SerializedName("sprint_id") val sprintId: String?,
    @SerializedName("epic_id") val epicId: String?,
    @SerializedName("story_points") val storyPoints: Int?,
    @SerializedName("labels") val labels: List<String>,
    @SerializedName("created_at") val createdAt: String,
    @SerializedName("updated_at") val updatedAt: String
)

// Create Issue Request
data class CreateIssueRequest(
    @SerializedName("project_id") val projectId: String,
    @SerializedName("issue_type_id") val issueTypeId: String,
    @SerializedName("summary") val summary: String,
    @SerializedName("description") val description: String? = null,
    @SerializedName("priority") val priority: String = "medium",
    @SerializedName("assignee_id") val assigneeId: String? = null,
    @SerializedName("sprint_id") val sprintId: String? = null,
    @SerializedName("story_points") val storyPoints: Int? = null,
    @SerializedName("labels") val labels: List<String> = emptyList()
)
```

### 7.3 Entity Models (Room Database)

```kotlin
@Entity(tableName = "issues")
data class IssueEntity(
    @PrimaryKey val id: String,
    val projectId: String,
    val issueKey: String,
    val issueTypeId: String,
    val summary: String,
    val description: String?,
    val statusId: String,
    val priority: String,
    val assigneeId: String?,
    val reporterId: String,
    val parentId: String?,
    val sprintId: String?,
    val epicId: String?,
    val storyPoints: Int?,
    val dueDate: Long?,
    val labels: String, // JSON
    val createdAt: Long,
    val updatedAt: Long,
    val isSynced: Boolean = true,
    val pendingOperation: String? = null // create, update, delete
)

@Entity(tableName = "projects")
data class ProjectEntity(
    @PrimaryKey val id: String,
    val key: String,
    val name: String,
    val description: String?,
    val avatarUrl: String?,
    val projectType: String,
    val leadId: String,
    val status: String,
    val isPrivate: Boolean,
    val createdAt: Long,
    val updatedAt: Long
)

@Entity(tableName = "sprints")
data class SprintEntity(
    @PrimaryKey val id: String,
    val projectId: String,
    val name: String,
    val goal: String?,
    val state: String,
    val startDate: Long?,
    val endDate: Long?,
    val createdBy: String,
    val createdAt: Long
)
```

---

## 8. Offline Synchronization Strategy

### 8.1 Sync Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    SYNC MANAGER                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌──────────────┐     │
│  │   Local     │    │   Sync      │    │    Remote    │     │
│  │   Changes   │───▶│   Queue     │───▶│     API      │     │
│  │   (Room)    │    │  (Room)     │    │  (Retrofit)  │     │
│  └─────────────┘    └─────────────┘    └──────────────┘     │
│         │                  │                  │               │
│         ▼                  ▼                  ▼               │
│  ┌─────────────┐    ┌─────────────┐    ┌──────────────┐     │
│  │  Conflict   │    │   Retry     │    │   WebSocket  │     │
│  │  Resolution │    │   Logic     │    │   Updates    │     │
│  └─────────────┘    └─────────────┘    └──────────────┘     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 8.2 Sync Flow

1. **Local Changes:**
   - User makes changes offline
   - Changes stored in Room with `pendingOperation` flag
   - Added to SyncQueue table

2. **Sync Trigger:**
   - Network connectivity restored
   - App foregrounded
   - Pull-to-refresh
   - Periodic sync (WorkManager)

3. **Conflict Resolution:**
   - Last-write-wins (default)
   - Manual merge (for complex fields)
   - Server-wins for critical data

4. **Sync Queue Table:**
```kotlin
@Entity(tableName = "sync_queue")
data class SyncQueueItem(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val entityType: String, // issue, project, comment, etc.
    val entityId: String,
    val operation: SyncOperation, // CREATE, UPDATE, DELETE
    val payload: String, // JSON payload
    val retryCount: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
    val lastAttemptAt: Long? = null,
    val errorMessage: String? = null
)

enum class SyncOperation { CREATE, UPDATE, DELETE }
```

### 8.3 Sync Worker

```kotlin
class SyncWorker(
    context: Context,
    params: WorkerParameters,
    private val syncManager: SyncManager
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        return try {
            syncManager.syncPendingChanges()
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < MAX_RETRY_COUNT) {
                Result.retry()
            } else {
                Result.failure(workDataOf("error" to e.message))
            }
        }
    }
}

// Schedule periodic sync
val syncWorkRequest = PeriodicWorkRequestBuilder<SyncWorker>(
    repeatInterval = 15,
    repeatIntervalTimeUnit = TimeUnit.MINUTES
).setConstraints(
    Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()
).build()

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "sync_work",
    ExistingPeriodicWorkPolicy.KEEP,
    syncWorkRequest
)
```

---

## 9. Security Considerations

### 9.1 Authentication & Authorization
- JWT tokens with short expiry (15 minutes)
- Refresh tokens (7 days)
- Biometric authentication support
- OAuth2 integration (Google, Microsoft)
- Role-based access control (RBAC)
- API key rotation

### 9.2 Data Protection
- TLS 1.3 for all communications
- Data encryption at rest (AES-256)
- Certificate pinning in mobile app
- Secure token storage (Android Keystore)
- SQL injection prevention
- XSS protection

### 9.3 Mobile App Security
- Root/jailbreak detection
- Obfuscation (ProGuard/R8)
- Anti-tampering measures
- Secure logging (no sensitive data)
- Screenshot prevention (optional)

---

## 10. Performance Optimization

### 10.1 Backend
- Database indexing on frequently queried fields
- Connection pooling (HikariCP)
- Query result caching (Redis)
- Pagination (cursor-based for large datasets)
- Async processing for heavy operations
- CDN for static assets

### 10.2 Android App
- Lazy loading and pagination
- Image caching (Coil/Glide)
- Room database with Paging 3
- Debounced search queries
- Background sync with WorkManager
- Memory leak prevention
- Battery optimization

### 10.3 Network Optimization
- Request/Response compression (Gzip/Brotli)
- Delta sync for updates
- Partial JSON responses (field selection)
- HTTP/2 or HTTP/3
- GraphQL (optional for flexible queries)

---

## 11. Push Notifications

### 11.1 Notification Types
- Issue assignments
- Status changes
- Comments and mentions
- Sprint events (start, end)
- Project invitations
- Due date reminders

### 11.2 FCM Integration
```kotlin
class JiraMessagingService : FirebaseMessagingService() {
    
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val notification = remoteMessage.toNotification()
        notificationHelper.showNotification(notification)
    }
    
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Send token to backend
        notificationRepository.updatePushToken(token)
    }
}
```

---

## 12. Deployment Architecture

### 12.1 Infrastructure
```
┌──────────────────────────────────────────────────────────────┐
│                         KUBERNETES                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Ingress Controller                   │   │
│  │                   (NGINX/Traefik)                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                              │                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              API Gateway Pods (3 replicas)              │   │
│  └──────────────────────────────────────────────────────┘   │
│                              │                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Service Pods (microservices)               │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐     │   │
│  │  │  Auth   │ │ Project │ │  Issue  │ │ Sprint  │ ... │   │
│  │  │ (2 rep) │ │ (3 rep) │ │ (5 rep) │ │ (2 rep) │     │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                              │                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              StatefulSets (Database)                    │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │   │
│  │  │ PostgreSQL  │  │    Redis    │  │Elasticsearch │  │   │
│  │  │  (3 nodes)  │  │  (3 nodes)  │  │   (3 nodes)  │  │   │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### 12.2 CI/CD Pipeline
```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Docker images
        run: docker-compose -f docker-compose.prod.yml build
      - name: Push to registry
        run: |
          docker push registry/jira-api-gateway
          docker push registry/jira-auth-service
          # ... other services
      - name: Deploy to Kubernetes
        run: kubectl apply -f k8s/
  
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build APK
        run: ./gradlew assembleRelease
      - name: Sign APK
        uses: r0adkll/sign-android-release@v1
      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
```

---

## 13. Testing Strategy

### 13.1 Backend Testing
- **Unit Tests:** JUnit, Mockito
- **Integration Tests:** TestContainers
- **API Tests:** Postman/Newman, REST Assured
- **Load Tests:** k6, JMeter
- **Contract Tests:** Pact

### 13.2 Android Testing
- **Unit Tests:** JUnit, MockK
- **Integration Tests:** Hilt testing
- **UI Tests:** Espresso, Compose UI Test
- **E2E Tests:** Appium, Maestro
- **Screenshot Tests:** Paparazzi

---

## 14. Monitoring & Analytics

### 14.1 Backend Monitoring
- **APM:** Datadog, New Relic, or Grafana
- **Logs:** ELK Stack (Elasticsearch, Logstash, Kibana)
- **Metrics:** Prometheus + Grafana
- **Error Tracking:** Sentry
- **Uptime:** Pingdom, UptimeRobot

### 14.2 Mobile Analytics
- **Crash Reporting:** Firebase Crashlytics
- **Analytics:** Firebase Analytics, Mixpanel
- **Performance:** Firebase Performance Monitoring
- **User Feedback:** In-app feedback, surveys

---

## 15. Scalability Considerations

### 15.1 Horizontal Scaling
- Kubernetes HPA (Horizontal Pod Autoscaler)
- Database read replicas
- Redis clustering
- CDN for static content

### 15.2 Database Sharding
- Shard by tenant/organization
- Consistent hashing for distribution
- Cross-shard queries optimization

### 15.3 Caching Strategy
- L1: In-memory (Caffeine)
- L2: Redis distributed cache
- L3: CDN edge caching
- Cache invalidation patterns

---

## Summary

This system design provides a comprehensive architecture for a Jira-like project management application with:

✅ **Backend:** Microservices architecture with 10+ services
✅ **Database:** PostgreSQL with proper indexing and relationships
✅ **Android:** Modern architecture (MVVM + Clean Architecture + Compose)
✅ **Real-time:** WebSocket support for live updates
✅ **Offline:** Complete offline support with sync
✅ **Security:** JWT, encryption, and mobile security best practices
✅ **Scalability:** Kubernetes, caching, and horizontal scaling
✅ **Performance:** Pagination, lazy loading, and optimization

The system is designed to handle thousands of concurrent users with support for offline-first mobile experience.
