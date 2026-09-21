import { useEffect, useState } from 'react';
import {
  adminSignIn,
  adminSignOut,
  checkForAdminAccount,
  countStudents,
  createAdminAccount,
} from './firebase';

function App() {
  const [loading, setLoading] = useState(true);
  const [hasAdminAccount, setHasAdminAccount] = useState(false);
  const [authMode, setAuthMode] = useState('login');
  const [loggedIn, setLoggedIn] = useState(() => {
    const rememberEnabled = localStorage.getItem('askuc_remember') === 'true';
    const rememberedLogin =
      rememberEnabled && localStorage.getItem('askuc_logged_in') === 'true';
    const sessionLogin = sessionStorage.getItem('askuc_logged_in') === 'true';

    return rememberedLogin || sessionLogin;
  });

  const [activePage, setActivePage] = useState('Dashboard');

  useEffect(() => {
    async function loadAdminStatus() {
      try {
        const adminExists = await checkForAdminAccount();
        setHasAdminAccount(adminExists);
      } catch (error) {
        console.error('Could not check admin account status:', error);
        setHasAdminAccount(false);
      } finally {
        setLoading(false);
      }
    }

    loadAdminStatus();
  }, []);

  const handleLogin = (remember) => {
    const shouldRemember = Boolean(remember);

    if (shouldRemember) {
      localStorage.setItem('askuc_logged_in', 'true');
      localStorage.setItem('askuc_remember', 'true');
      sessionStorage.setItem('askuc_logged_in', 'true');
    } else {
      localStorage.setItem('askuc_remember', 'false');
      localStorage.removeItem('askuc_logged_in');
      localStorage.removeItem('askuc_admin_email');
      localStorage.removeItem('askuc_admin_password');
      sessionStorage.setItem('askuc_logged_in', 'true');
    }

    setLoggedIn(true);
  };

  const handleLogout = async () => {
    try {
      await adminSignOut();
    } catch (error) {
      console.warn('Firebase sign-out warning:', error);
    }

    localStorage.removeItem('askuc_logged_in');
    localStorage.removeItem('askuc_remember');
    localStorage.removeItem('askuc_admin_email');
    localStorage.removeItem('askuc_admin_password');
    sessionStorage.removeItem('askuc_logged_in');

    setAuthMode('login');
    setLoggedIn(false);
    setActivePage('Dashboard');
  };

  if (loading) {
    return <div className="login-page"><div className="login-card"><p>Loading admin access...</p></div></div>;
  }

  if (!loggedIn && !hasAdminAccount) {
    return (
      <AuthScreen
        mode={authMode}
        setMode={setAuthMode}
        onCreated={() => {
          setHasAdminAccount(true);
          setAuthMode('login');
        }}
        onLogin={handleLogin}
      />
    );
  }

  if (!loggedIn) {
    return (
      <AuthScreen
        mode={authMode}
        setMode={setAuthMode}
        onCreated={() => {
          setHasAdminAccount(true);
          setAuthMode('login');
        }}
        onLogin={handleLogin}
      />
    );
  }

  return (
    <AdminLayout
      activePage={activePage}
      setActivePage={setActivePage}
      onLogout={handleLogout}
    />
  );
}

function AuthScreen({ mode, setMode, onCreated, onLogin }) {
  if (mode === 'register') {
    return <CreateAdminAccount onCreated={onCreated} onSwitchToLogin={() => setMode('login')} />;
  }

  return <AdminLogin onLogin={onLogin} onSwitchToRegister={() => setMode('register')} />;
}

function CreateAdminAccount({ onCreated, onSwitchToLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!email.trim() || !password) {
      alert('Please enter an email and password.');
      return;
    }

    if (password.length < 6) {
      alert('Password must be at least 6 characters long.');
      return;
    }

    if (password !== confirmPassword) {
      alert('Passwords do not match.');
      return;
    }

    try {
      setIsSubmitting(true);
      await createAdminAccount(email, password);
      alert('Admin account created successfully. Please sign in.');
      onCreated();
    } catch (error) {
      alert(error.message || 'Failed to create admin account.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="admin-logo">
          <div className="admin-logo-icon">▦</div>
          <h1>Create Admin</h1>
          <p>Set up the first admin account</p>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Admin Email</label>
            <input
              type="email"
              placeholder="admin@university.edu"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              placeholder="Enter password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label>Confirm Password</label>
            <input
              type="password"
              placeholder="Confirm password"
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              required
            />
          </div>

          <button type="submit" className="login-button" disabled={isSubmitting}>
            {isSubmitting ? 'Creating...' : 'Create Admin Account'}
          </button>

          <div className="login-footer" style={{ marginTop: 18 }}>
            <button
              type="button"
              className="forgot-button"
              onClick={onSwitchToLogin}
              style={{ color: '#0866E8', background: 'transparent', border: 'none', cursor: 'pointer' }}
            >
              Already have an account? Login
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ============================================================
   ADMIN LOGIN
============================================================ */

function AdminLogin({ onLogin, onSwitchToRegister }) {
  const [email, setEmail] = useState(() => {
    const rememberEnabled = localStorage.getItem('askuc_remember') === 'true';
    return rememberEnabled ? (localStorage.getItem('askuc_admin_email') ?? '') : '';
  });
  const [password, setPassword] = useState(() => {
    const rememberEnabled = localStorage.getItem('askuc_remember') === 'true';
    return rememberEnabled ? (localStorage.getItem('askuc_admin_password') ?? '') : '';
  });
  const [remember, setRemember] = useState(() => {
    return localStorage.getItem('askuc_remember') === 'true';
  });

  const handleLogin = async (event) => {
    event.preventDefault();

    try {
      const user = await adminSignIn(email, password);

      if (user) {
        if (remember) {
          localStorage.setItem('askuc_admin_email', email);
          localStorage.setItem('askuc_admin_password', password);
          localStorage.setItem('askuc_remember', 'true');
        } else {
          localStorage.removeItem('askuc_admin_email');
          localStorage.removeItem('askuc_admin_password');
          localStorage.setItem('askuc_remember', 'false');
        }

        onLogin(remember);
      }
    } catch (error) {
      alert(error.message || 'Admin login failed.');
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">

        <div className="admin-logo">
          <div className="admin-logo-icon">▦</div>
          <h1>Campus Admin</h1>
          <p>University Portal</p>
        </div>

        <form onSubmit={handleLogin}>

          <div className="form-group">
            <label>Admin Email</label>

            <input
              type="email"
              placeholder="admin@university.edu"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label>Password</label>

            <input
              type="password"
              placeholder="Enter password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </div>

          <div className="login-options">

            <label className="remember">
              <input
                type="checkbox"
                checked={remember}
                onChange={(event) =>
                  setRemember(event.target.checked)
                }
              />

              <span>Remember me</span>
            </label>

            <button
              type="button"
              className="forgot-button"
            >
              Forgot Password?
            </button>

          </div>

          <button
            type="submit"
            className="login-button"
          >
            Sign In
          </button>

        </form>

        <div className="login-footer">
          University Campus Administration System
        </div>

        <div className="login-footer" style={{ marginTop: 12 }}>
          <button
            type="button"
            className="forgot-button"
            onClick={onSwitchToRegister}
            style={{ color: '#0866E8', background: 'transparent', border: 'none', cursor: 'pointer' }}
          >
            Create admin account
          </button>
        </div>

      </div>
    </div>
  );
}

/* ============================================================
   ADMIN LAYOUT
============================================================ */

function AdminLayout({
  activePage,
  setActivePage,
  onLogout,
}) {
  return (
    <div className="admin-layout">

      <Sidebar
        activePage={activePage}
        setActivePage={setActivePage}
        onLogout={onLogout}
      />

      <main className="main-area">

        <Topbar activePage={activePage} />

        <div className="page-content">

          {activePage === 'Dashboard' && <Dashboard />}

          {activePage === 'Content' && <ContentPage />}

          {activePage === 'Users' && <UsersPage />}

          {activePage === 'Announcements' && (
            <AnnouncementsPage />
          )}

          {activePage === 'Map' && <MapPage />}

        </div>

      </main>

    </div>
  );
}

/* ============================================================
   SIDEBAR
============================================================ */

function Sidebar({
  activePage,
  setActivePage,
  onLogout,
}) {
  const menuItems = [
    {
      name: 'Dashboard',
      icon: '▣',
    },
    {
      name: 'Content',
      icon: '▤',
    },
    {
      name: 'Users',
      icon: '♙',
    },
    {
      name: 'Announcements',
      icon: '⚑',
    },
    {
      name: 'Map',
      icon: '⌖',
    },
  ];

  return (
    <aside className="sidebar">

      <div className="sidebar-header">

        <div className="sidebar-logo">
          ▦
        </div>

        <div>
          <div className="sidebar-title">
            AskUC Admin
          </div>

          <div className="sidebar-subtitle">
            University Portal
          </div>
        </div>

      </div>

      <nav className="sidebar-menu">

        {menuItems.map((item) => (
          <button
            key={item.name}
            className={`menu-item ${
              activePage === item.name
                ? 'active'
                : ''
            }`}
            onClick={() => setActivePage(item.name)}
          >

            <span className="menu-icon">
              {item.icon}
            </span>

            <span>{item.name}</span>

          </button>
        ))}

      </nav>

      <div className="sidebar-bottom">

        <div className="admin-profile">

          <div className="profile-avatar">
            AD
          </div>

          <div className="profile-info">

            <strong>
              Admin User
            </strong>

            <span>
              Administrator
            </span>

          </div>

        </div>

        <button
          className="logout-button"
          onClick={onLogout}
        >
          <span>↪</span>
          Logout
        </button>

      </div>

    </aside>
  );
}

/* ============================================================
   TOPBAR
============================================================ */

function Topbar({ activePage }) {
  return (
    <header className="topbar">

      <div>
        <h2>{activePage}</h2>

        <p>
          AskUC Administration Portal
        </p>
      </div>

      <div className="topbar-admin">

        <div className="topbar-avatar">
          AD
        </div>

        <div>
          <strong>Admin User</strong>
          <span>Administrator</span>
        </div>

      </div>

    </header>
  );
}

/* ============================================================
   DASHBOARD
============================================================ */

function Dashboard() {
  const [studentCount, setStudentCount] = useState(0);
  const [loadingStudents, setLoadingStudents] = useState(true);

  useEffect(() => {
    let isMounted = true;

    async function loadStudentCount() {
      try {
        const count = await countStudents();
        if (isMounted) {
          setStudentCount(count);
        }
      } catch (error) {
        console.error('Failed to load student count:', error);
        if (isMounted) {
          setStudentCount(0);
        }
      } finally {
        if (isMounted) {
          setLoadingStudents(false);
        }
      }
    }

    loadStudentCount();

    return () => {
      isMounted = false;
    };
  }, []);

  return (
    <div className="dashboard">

      <div className="page-heading">

        <div>
          <h1>Dashboard</h1>

          <p>
            Overview of the AskUC campus assistance system.
          </p>
        </div>

      </div>

      {/* STATISTICS */}

      <div className="stats-grid">

        <StatCard
          icon="♙"
          title="Students"
          value={loadingStudents ? 'Loading...' : String(studentCount)}
          change="Live"
          description="Total student accounts"
        />

        <StatCard
          icon="▤"
          title="Chatbot Queries"
          value="1,000"
          change="+8%"
          description="Total student inquiries"
        />

        <StatCard
          icon="?"
          title="Campus FAQs"
          value="120"
          change="+5%"
          description="Knowledge base entries"
        />

        <StatCard
          icon="⚑"
          title="Announcements"
          value="24"
          change="+10%"
          description="Published announcements"
        />

      </div>

      {/* CHARTS */}

      <div className="charts-grid">

        <ChartCard
          title="Chatbot Queries"
          subtitle="Student questions over the past week"
        >
          <BarChart />
        </ChartCard>

        <ChartCard
          title="Navigation Searches"
          subtitle="Campus location searches"
        >
          <LineChart />
        </ChartCard>

      </div>

      {/* TABLES */}

      <div className="bottom-grid">

        <RecentQuestions />

        <MostSearchedLocations />

      </div>

    </div>
  );
}

/* ============================================================
   STAT CARD
============================================================ */

function StatCard({
  icon,
  title,
  value,
  change,
  description,
}) {
  return (
    <div className="stat-card">

      <div className="stat-top">

        <div className="stat-icon">
          {icon}
        </div>

        <span className="stat-change">
          {change}
        </span>

      </div>

      <div className="stat-value">
        {value}
      </div>

      <div className="stat-title">
        {title}
      </div>

      <div className="stat-description">
        {description}
      </div>

    </div>
  );
}

/* ============================================================
   CHART CARD
============================================================ */

function ChartCard({
  title,
  subtitle,
  children,
}) {
  return (
    <div className="chart-card">

      <div className="chart-header">

        <div>
          <h3>{title}</h3>

          <p>{subtitle}</p>
        </div>

      </div>

      {children}

    </div>
  );
}

/* ============================================================
   BAR CHART
============================================================ */

function BarChart() {
  const values = [42, 68, 51, 85, 72, 94, 78];

  return (
    <div className="bar-chart">

      {values.map((value, index) => (
        <div
          className="bar-wrapper"
          key={index}
        >

          <div
            className="bar"
            style={{
              height: `${value}%`,
            }}
          />

          <span>
            {['M', 'T', 'W', 'T', 'F', 'S', 'S'][index]}
          </span>

        </div>
      ))}

    </div>
  );
}

/* ============================================================
   LINE CHART
============================================================ */

function LineChart() {
  return (
    <div className="line-chart">

      <svg
        viewBox="0 0 500 180"
        preserveAspectRatio="none"
      >

        <line
          x1="0"
          y1="150"
          x2="500"
          y2="150"
          className="chart-line-grid"
        />

        <line
          x1="0"
          y1="100"
          x2="500"
          y2="100"
          className="chart-line-grid"
        />

        <line
          x1="0"
          y1="50"
          x2="500"
          y2="50"
          className="chart-line-grid"
        />

        <polyline
          points="
            0,135
            70,120
            140,130
            210,95
            280,110
            350,70
            420,85
            500,45
          "
          fill="none"
          className="chart-line"
        />

      </svg>

    </div>
  );
}

/* ============================================================
   RECENT QUESTIONS
============================================================ */

function RecentQuestions() {
  const questions = [
    'Where is the Registrar office?',
    'How do I enroll?',
    'Where is Room 204?',
    'What are the library hours?',
  ];

  return (
    <div className="table-card">

      <div className="table-header">
        <h3>Most Asked Questions</h3>

        <button>
          View All
        </button>
      </div>

      <div className="question-list">

        {questions.map((question, index) => (
          <div
            className="question-row"
            key={index}
          >

            <div className="question-number">
              {index + 1}
            </div>

            <span>{question}</span>

          </div>
        ))}

      </div>

    </div>
  );
}

/* ============================================================
   LOCATIONS
============================================================ */

function MostSearchedLocations() {
  const locations = [
    'Registrar Office',
    'Library',
    'Accounting Office',
    'Student Affairs',
  ];

  return (
    <div className="table-card">

      <div className="table-header">

        <h3>Most Searched Locations</h3>

        <button>
          View All
        </button>

      </div>

      <div className="question-list">

        {locations.map((location, index) => (
          <div
            className="question-row"
            key={index}
          >

            <div className="question-number">
              {index + 1}
            </div>

            <span>{location}</span>

          </div>
        ))}

      </div>

    </div>
  );
}

/* ============================================================
   CONTENT PAGE
============================================================ */

function ContentPage() {
  return (
    <PagePlaceholder
      icon="?"
      title="Content Management"
      description="Manage FAQs and the AskUC chatbot knowledge base."
      button="Add FAQ"
    />
  );
}

/* ============================================================
   USERS PAGE
============================================================ */

function UsersPage() {
  return (
    <PagePlaceholder
      icon="♙"
      title="Student Management"
      description="View and manage student accounts."
      button="Add Student"
    />
  );
}

/* ============================================================
   ANNOUNCEMENTS PAGE
============================================================ */

function AnnouncementsPage() {
  return (
    <PagePlaceholder
      icon="⚑"
      title="Announcements"
      description="Create and broadcast university announcements."
      button="Create Announcement"
    />
  );
}

/* ============================================================
   MAP PAGE
============================================================ */

function MapPage() {
  return (
    <div className="module-page">

      <div className="module-heading">

        <div>
          <h1>Campus Map</h1>

          <p>
            Manage campus locations, buildings and offices.
          </p>
        </div>

        <button className="primary-button">
          + Add Location
        </button>

      </div>

      <div className="map-management">

        <div className="map-preview">

          <div className="map-placeholder">

            <div className="map-icon">
              ⌖
            </div>

            <h3>
              2.5D Campus Map
            </h3>

            <p>
              Campus map management area
            </p>

          </div>

        </div>

        <div className="location-list">

          <h3>
            Campus Locations
          </h3>

          <LocationItem
            name="Main Building"
            type="Building"
          />

          <LocationItem
            name="Registrar Office"
            type="Office"
          />

          <LocationItem
            name="Library"
            type="Facility"
          />

          <LocationItem
            name="Student Affairs"
            type="Office"
          />

        </div>

      </div>

    </div>
  );
}

/* ============================================================
   LOCATION ITEM
============================================================ */

function LocationItem({
  name,
  type,
}) {
  return (
    <div className="location-item">

      <div className="location-icon">
        ⌖
      </div>

      <div className="location-info">

        <strong>{name}</strong>

        <span>{type}</span>

      </div>

      <button className="small-button">
        Edit
      </button>

    </div>
  );
}

/* ============================================================
   PLACEHOLDER MODULE
============================================================ */

function PagePlaceholder({
  icon,
  title,
  description,
  button,
}) {
  return (
    <div className="module-page">

      <div className="module-heading">

        <div>

          <h1>{title}</h1>

          <p>{description}</p>

        </div>

        <button className="primary-button">
          + {button}
        </button>

      </div>

      <div className="empty-module">

        <div className="empty-icon">
          {icon}
        </div>

        <h3>
          {title}
        </h3>

        <p>
          This module is ready for database integration.
        </p>

      </div>

    </div>
  );
}

export default App;