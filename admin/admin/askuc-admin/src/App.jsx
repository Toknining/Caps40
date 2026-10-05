import { useEffect, useState } from 'react';
import {
  adminSignIn,
  adminSignOut,
  auth,
  checkForAdminAccount,
  createBlockedWord,
  createAdminAccount,
  createAnnouncement,
  createFaq,
  createStudentAccount,
  deleteAnnouncement,
  deleteBlockedWord,
  deleteFaq,
  deleteStudentAccount,
  getAnnouncements,
  getCurrentAdminProfile,
  getFaqs,
  getStudents,
  isAdminUser,
  resetStudentPassword,
  subscribeToAdminAuthState,
  subscribeToCurrentAdminProfile,
  subscribeToBlockedWords,
  subscribeToAnnouncementCount,
  subscribeToAnnouncements,
  subscribeToChatbotQueries,
  subscribeToFeedback,
  subscribeToFaqCount,
  subscribeToNavigationSearches,
  subscribeToStudentCount,
  updateAnnouncement,
  updateCurrentAdminName,
  updateFaq,
  updateStudentAccount,
} from './firebase';

const adminRememberKey = 'askuc_admin_remember_me';
const adminEmailKey = 'askuc_admin_email';
// Older versions saved the admin password here; it is now only removed.
const legacyAdminPasswordKey = 'askuc_admin_password';

function App() {
  // null until checked, so the registration link doesn't flash on load.
  const [hasAdminAccount, setHasAdminAccount] = useState(null);
  const [authMode, setAuthMode] = useState('login');
  const [loggedIn, setLoggedIn] = useState(false);
  const [adminProfile, setAdminProfile] = useState({
    firstName: 'Admin',
    lastName: 'User',
    photoUrl: '',
  });

  const [activePage, setActivePage] = useState('Dashboard');
  const [adminUid, setAdminUid] = useState(() => auth.currentUser?.uid ?? null);
  const [authReady, setAuthReady] = useState(false);

  const loadAdminProfile = async () => {
    try {
      const profile = await getCurrentAdminProfile();
      setAdminProfile(profile);
    } catch (error) {
      console.error('Failed to load admin profile:', error);
    }
  };

  useEffect(() => {
    async function loadAdminStatus() {
      try {
        const adminExists = await checkForAdminAccount();
        setHasAdminAccount(adminExists);
      } catch (error) {
        console.error('Could not check admin account status:', error);
        setHasAdminAccount(false);
      }
    }

    loadAdminStatus();
  }, []);

  useEffect(() => {
    localStorage.removeItem(legacyAdminPasswordKey);

    // "Remember me" is handled by Firebase: adminSignIn keeps the session in
    // browser storage only when it is checked, so a refresh restores it here.
    return subscribeToAdminAuthState(async (user) => {
      setAdminUid(user?.uid ?? null);

      if (!user) {
        setLoggedIn(false);
        setAuthReady(true);
        return;
      }

      const isAdmin = await isAdminUser(user.uid).catch((error) => {
        console.error('Could not verify admin access:', error);
        return false;
      });

      // Ignore a check that finished after a sign-out or account switch.
      if (auth.currentUser?.uid !== user.uid) {
        return;
      }

      setLoggedIn(isAdmin);
      setAuthReady(true);

      if (isAdmin) {
        loadAdminProfile();
      }
    });
  }, []);

  useEffect(() => {
    if (!loggedIn || !adminUid) {
      return undefined;
    }

    return subscribeToCurrentAdminProfile(
      (profile) => setAdminProfile(profile),
      (error) => console.error('Failed to keep admin profile in sync:', error),
    );
  }, [loggedIn, adminUid]);

  const handleLogin = async () => {
    setLoggedIn(true);
    await loadAdminProfile();
  };

  const handleLogout = async () => {
    try {
      await adminSignOut(auth);
    } catch (error) {
      console.warn('Firebase sign-out warning:', error);
    }

    setAuthMode('login');
    setLoggedIn(false);
    setActivePage('Dashboard');
  };

  if (!authReady) {
    return null;
  }

  if (!loggedIn) {
    return (
      <AuthScreen
        mode={authMode}
        setMode={setAuthMode}
        canRegister={hasAdminAccount === false}
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
      adminProfile={adminProfile}
      onProfileUpdated={setAdminProfile}
    />
  );
}

function AuthScreen({ mode, setMode, canRegister, onCreated, onLogin }) {
  if (mode === 'register' && canRegister) {
    return <CreateAdminAccount onCreated={onCreated} onSwitchToLogin={() => setMode('login')} />;
  }

  return (
    <AdminLogin
      onLogin={onLogin}
      onSwitchToRegister={canRegister ? () => setMode('register') : null}
    />
  );
}

function CreateAdminAccount({ onCreated, onSwitchToLogin }) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!firstName.trim() || !lastName.trim() || !email.trim() || !password) {
      alert('Please complete all registration fields.');
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
      await createAdminAccount({ firstName, lastName, email, password });
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
        <button
          type="button"
          className="registration-close-button"
          onClick={onSwitchToLogin}
          aria-label="Back to login"
          title="Back to login"
        >
          ×
        </button>
        <div className="admin-logo">
          <div className="admin-logo-icon">▦</div>
          <h1>Create Admin</h1>
          <p>Set up the first admin account</p>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>First Name</label>
            <input
              type="text"
              placeholder="Enter first name"
              value={firstName}
              onChange={(event) => setFirstName(event.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label>Last Name</label>
            <input
              type="text"
              placeholder="Enter last name"
              value={lastName}
              onChange={(event) => setLastName(event.target.value)}
              required
            />
          </div>

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
  const [email, setEmail] = useState(() => localStorage.getItem(adminEmailKey) ?? '');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(() => {
    return localStorage.getItem(adminRememberKey) === 'true';
  });

  const handleLogin = async (event) => {
    event.preventDefault();

    // Only the email is saved to pre-fill the form. The session itself is
    // kept by Firebase, never by storing the password.
    if (remember) {
      localStorage.setItem(adminRememberKey, 'true');
      localStorage.setItem(adminEmailKey, email);
    } else {
      localStorage.removeItem(adminRememberKey);
      localStorage.removeItem(adminEmailKey);
    }

    try {
      const user = await adminSignIn(email, password, remember);

      if (user) {
        onLogin();
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
              autoComplete="username"
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
              autoComplete="current-password"
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </div>

          <div className="login-options">

            <label className="remember">
              <input
                type="checkbox"
                checked={remember}
                onChange={(event) => setRemember(event.target.checked)}
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

        {onSwitchToRegister && (
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
        )}

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
  adminProfile,
  onProfileUpdated,
}) {
  return (
    <div className="admin-layout">

      <Sidebar
        activePage={activePage}
        setActivePage={setActivePage}
        onLogout={onLogout}
        adminProfile={adminProfile}
      />

      <main className="main-area">

        <Topbar activePage={activePage} adminProfile={adminProfile} />

        <div className="page-content">

          {activePage === 'Dashboard' && <Dashboard setActivePage={setActivePage} />}

          {activePage === 'Content' && <ContentPage />}

          {activePage === 'Users' && <UsersPage />}

          {activePage === 'Announcements' && (
            <AnnouncementsPage />
          )}

          {activePage === 'Map' && <MapPage />}

          {activePage === 'Feedback' && <FeedbackPage />}

          {activePage === 'Profile Settings' && (
            <ProfileSettingsPage
              adminProfile={adminProfile}
              onProfileUpdated={onProfileUpdated}
            />
          )}

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
  adminProfile,
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
    {
      name: 'Feedback',
      icon: '★',
    },
    {
      name: 'Profile Settings',
      icon: '⚙',
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
            {adminProfile.photoUrl ? (
              <img src={adminProfile.photoUrl} alt="Admin avatar" className="profile-image" />
            ) : (
              `${(adminProfile.firstName || 'A').charAt(0)}${(adminProfile.lastName || 'U').charAt(0)}`.toUpperCase()
            )}
          </div>

          <div className="profile-info">

            <strong>
              {`${adminProfile.firstName || 'Admin'} ${adminProfile.lastName || 'User'}`.trim()}
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

function Topbar({ activePage, adminProfile }) {
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
          {adminProfile.photoUrl ? (
            <img src={adminProfile.photoUrl} alt="Admin avatar" className="profile-image" />
          ) : (
            `${(adminProfile.firstName || 'A').charAt(0)}${(adminProfile.lastName || 'U').charAt(0)}`.toUpperCase()
          )}
        </div>

        <div>
          <strong>{`${adminProfile.firstName || 'Admin'} ${adminProfile.lastName || 'User'}`.trim()}</strong>
          <span>Administrator</span>
        </div>

      </div>

    </header>
  );
}

/* ============================================================
   DASHBOARD
============================================================ */

function ProfileSettingsPage({ adminProfile, onProfileUpdated }) {
  const [firstName, setFirstName] = useState(adminProfile.firstName || '');
  const [lastName, setLastName] = useState(adminProfile.lastName || '');
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    setFirstName(adminProfile.firstName || '');
    setLastName(adminProfile.lastName || '');
  }, [adminProfile.firstName, adminProfile.lastName]);

  const fullName = `${adminProfile.firstName || 'Admin'} ${adminProfile.lastName || 'User'}`.trim();
  const initials = `${(adminProfile.firstName || 'A').charAt(0)}${(adminProfile.lastName || 'U').charAt(0)}`.toUpperCase();
  const email = adminProfile.email || auth.currentUser?.email || 'Not available';
  const fields = [
    { label: 'First name', value: adminProfile.firstName || 'Not available' },
    { label: 'Last name', value: adminProfile.lastName || 'Not available' },
    { label: 'Admin ID', value: adminProfile.studentId || 'ADMIN' },
    { label: 'Email address', value: email },
    { label: 'Role', value: adminProfile.role || 'admin' },
  ];

  const handleSaveName = async (event) => {
    event.preventDefault();

    if (!firstName.trim() || !lastName.trim()) {
      alert('Please enter both a first name and last name.');
      return;
    }

    try {
      setIsSaving(true);
      await updateCurrentAdminName({ firstName, lastName });
      onProfileUpdated({
        ...adminProfile,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
      });
      setIsEditing(false);
      alert('Admin name updated successfully.');
    } catch (error) {
      alert(error.message || 'Failed to update the admin name.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancelEdit = () => {
    setFirstName(adminProfile.firstName || '');
    setLastName(adminProfile.lastName || '');
    setIsEditing(false);
  };

  return (
    <div className="module-page">
      <div className="module-heading">
        <div>
          <h1>Profile Settings</h1>
          <p>Your administrator details from the AskUC database.</p>
        </div>
      </div>

      <section className="profile-settings-card">
        <div className="profile-settings-summary">
          <div className="profile-settings-avatar">
            {adminProfile.photoUrl ? (
              <img src={adminProfile.photoUrl} alt="Admin avatar" className="profile-image" />
            ) : (
              initials
            )}
          </div>
          <div>
            <h3>{fullName}</h3>
            <p>{email}</p>
          </div>
          <span className="profile-live-status">Live from database</span>
        </div>

        <div className="profile-details-grid">
          {fields.map((field) => (
            <div className="profile-detail" key={field.label}>
              <span>{field.label}</span>
              <strong>{field.value}</strong>
            </div>
          ))}
        </div>

        {isEditing ? (
          <form className="profile-name-form" onSubmit={handleSaveName}>
            <div>
              <h3>Edit name</h3>
              <p>This updates the name in your administrator database record.</p>
            </div>

            <div className="profile-name-fields">
              <label>
                First name
                <input
                  type="text"
                  value={firstName}
                  onChange={(event) => setFirstName(event.target.value)}
                  disabled={isSaving}
                  required
                />
              </label>

              <label>
                Last name
                <input
                  type="text"
                  value={lastName}
                  onChange={(event) => setLastName(event.target.value)}
                  disabled={isSaving}
                  required
                />
              </label>
            </div>

            <div className="profile-name-actions">
              <button type="submit" className="primary-button" disabled={isSaving}>
                {isSaving ? 'Saving...' : 'Save name'}
              </button>
              <button type="button" className="secondary-button" onClick={handleCancelEdit} disabled={isSaving}>
                Cancel
              </button>
            </div>
          </form>
        ) : (
          <div className="profile-edit-row">
            <div>
              <h3>Admin name</h3>
              <p>Change the name shown on your administrator profile.</p>
            </div>
            <button type="button" className="primary-button" onClick={() => setIsEditing(true)}>
              Edit name
            </button>
          </div>
        )}
      </section>
    </div>
  );
}

function Dashboard({ setActivePage }) {
  const [studentCount, setStudentCount] = useState(0);
  const [announcementCount, setAnnouncementCount] = useState(0);
  const [faqCount, setFaqCount] = useState(0);
  const [chatbotQueries, setChatbotQueries] = useState([]);
  const [navigationSearches, setNavigationSearches] = useState([]);
  const [loadingStudents, setLoadingStudents] = useState(true);
  const [loadingAnnouncements, setLoadingAnnouncements] = useState(true);
  const [loadingFaqs, setLoadingFaqs] = useState(true);
  const [loadingChatbotQueries, setLoadingChatbotQueries] = useState(true);

  useEffect(() => {
    const unsubscribe = subscribeToStudentCount(
      (count) => {
        setStudentCount(count);
        setLoadingStudents(false);
      },
      (error) => {
        console.error('Failed to load student count:', error);
        setStudentCount(0);
        setLoadingStudents(false);
      },
    );

    return () => unsubscribe && unsubscribe();
  }, []);

  useEffect(() => {
    const unsubscribe = subscribeToAnnouncementCount((count) => {
      setAnnouncementCount(count);
      setLoadingAnnouncements(false);
    });

    return () => unsubscribe && unsubscribe();
  }, []);

  useEffect(() => {
    const unsubscribe = subscribeToFaqCount((count) => {
      setFaqCount(count);
      setLoadingFaqs(false);
    });

    return () => unsubscribe && unsubscribe();
  }, []);

  useEffect(() => {
    const unsubscribe = subscribeToChatbotQueries(
      (queries) => {
        setChatbotQueries(queries);
        setLoadingChatbotQueries(false);
      },
      (error) => {
        console.error('Failed to load chatbot queries:', error);
        setChatbotQueries([]);
        setLoadingChatbotQueries(false);
      },
    );

    return () => unsubscribe && unsubscribe();
  }, []);

  useEffect(() => {
    const unsubscribe = subscribeToNavigationSearches(
      (searches) => setNavigationSearches(searches),
      (error) => {
        console.error('Failed to load navigation searches:', error);
        setNavigationSearches([]);
      },
    );

    return () => unsubscribe && unsubscribe();
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
          value={loadingChatbotQueries ? 'Loading...' : String(chatbotQueries.length)}
          change="Live"
          description="Total student inquiries"
        />

        <StatCard
          icon="?"
          title="Campus FAQs"
          value={loadingFaqs ? 'Loading...' : String(faqCount)}
          change="Live"
          description="Knowledge base entries"
        />

        <StatCard
          icon="⚑"
          title="Announcements"
          value={loadingAnnouncements ? 'Loading...' : String(announcementCount)}
          change="Live"
          description="Published announcements"
        />

      </div>

      {/* CHARTS */}

      <div className="charts-grid">

        <ChartCard
          title="Chatbot Queries"
          subtitle="Live student questions over the past week"
        >
          <BarChart queries={chatbotQueries} />
        </ChartCard>

        <ChartCard
          title="Navigation Searches"
          subtitle="Live campus route searches over the past week"
        >
          <LineChart searches={navigationSearches} />
        </ChartCard>

      </div>

      {/* TABLES */}

      <div className="bottom-grid">

        <RecentAnnouncements setActivePage={setActivePage} />

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

function BarChart({ queries }) {
  const today = new Date();
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(today);
    date.setHours(0, 0, 0, 0);
    date.setDate(today.getDate() - (6 - index));
    return date;
  });
  const values = days.map((day) => {
    const nextDay = new Date(day);
    nextDay.setDate(day.getDate() + 1);

    return queries.filter((item) => {
      const createdAt = item.createdAt?.toDate?.();
      return createdAt && createdAt >= day && createdAt < nextDay;
    }).length;
  });
  const largestValue = Math.max(...values, 1);

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
              height: value === 0 ? '0%' : `${Math.max((value / largestValue) * 100, 5)}%`,
            }}
          />

          <span>
            {days[index].toLocaleDateString('en-US', { weekday: 'narrow' })}
          </span>

        </div>
      ))}

    </div>
  );
}

/* ============================================================
   LINE CHART
============================================================ */

function LineChart({ searches }) {
  const today = new Date();
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(today);
    date.setHours(0, 0, 0, 0);
    date.setDate(today.getDate() - (6 - index));
    return date;
  });
  const values = days.map((day) => {
    const nextDay = new Date(day);
    nextDay.setDate(day.getDate() + 1);

    return searches.filter((item) => {
      const createdAt = item.createdAt?.toDate?.();
      return createdAt && createdAt >= day && createdAt < nextDay;
    }).length;
  });
  const largestValue = Math.max(...values, 1);
  const points = values
    .map((value, index) => {
      const x = (index / (values.length - 1)) * 500;
      const y = 150 - (value / largestValue) * 110;
      return `${x},${y}`;
    })
    .join(' ');

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
          points={points}
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

function RecentAnnouncements({ setActivePage }) {
  const [announcements, setAnnouncements] = useState([]);

  useEffect(() => {
    const unsubscribe = subscribeToAnnouncements((items) => {
      setAnnouncements(items.slice(0, 5));
    });

    return () => unsubscribe && unsubscribe();
  }, []);

  return (
    <div className="table-card">

      <div className="table-header">
        <h3>Latest Announcements</h3>

        <button type="button" onClick={() => setActivePage && setActivePage('Announcements')}>
          See all
        </button>
      </div>

      <div className="announcement-stack">

        {announcements.length === 0 ? (
          <div className="announcement-stack-item">
            <span>No announcements yet.</span>
          </div>
        ) : (
          announcements.map((announcement, index) => (
            <div className="announcement-stack-item" key={announcement.id || index}>
              <div className="question-number">{index + 1}</div>
              <div className="announcement-mini-copy">
                <strong>{announcement.title}</strong>
                <span>{announcement.message}</span>
              </div>
            </div>
          ))
        )}

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
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');
  const [faqs, setFaqs] = useState([]);
  const [blockedWord, setBlockedWord] = useState('');
  const [blockedWordLanguage, setBlockedWordLanguage] = useState('English');
  const [blockedWords, setBlockedWords] = useState([]);
  const [loadingFaqs, setLoadingFaqs] = useState(true);
  const [loadingBlockedWords, setLoadingBlockedWords] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [submittingBlockedWord, setSubmittingBlockedWord] = useState(false);
  const [editingFaqId, setEditingFaqId] = useState(null);
  const [blockedWordsError, setBlockedWordsError] = useState('');

  async function loadFaqs() {
    try {
      const data = await getFaqs();
      setFaqs(data);
    } catch (error) {
      console.error('Failed to load FAQs:', error);
      setFaqs([]);
    } finally {
      setLoadingFaqs(false);
    }
  }

  useEffect(() => {
    loadFaqs();
  }, []);

  useEffect(() => {
    const unsubscribe = subscribeToBlockedWords(
      (items) => {
        setBlockedWords(items);
        setLoadingBlockedWords(false);
        setBlockedWordsError('');
      },
      (error) => {
        console.error('Failed to load blocked words:', error);
        setBlockedWordsError('Could not load the blocked-word list. Check your connection and Firestore permissions.');
        setLoadingBlockedWords(false);
      },
    );

    return () => unsubscribe();
  }, []);

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!question.trim() || !answer.trim()) {
      alert('Please enter both the FAQ question and answer.');
      return;
    }

    try {
      setSubmitting(true);

      if (editingFaqId) {
        await updateFaq(editingFaqId, { question, answer });
        alert('FAQ updated successfully.');
      } else {
        await createFaq({ question, answer });
        alert('FAQ added successfully.');
      }

      setQuestion('');
      setAnswer('');
      setEditingFaqId(null);
      await loadFaqs();
    } catch (error) {
      alert(error.message || 'Failed to save FAQ.');
    } finally {
      setSubmitting(false);
    }
  };

  const startEditFaq = (faq) => {
    setQuestion(faq.question || '');
    setAnswer(faq.answer || '');
    setEditingFaqId(faq.id);
  };

  const resetFaqForm = () => {
    setQuestion('');
    setAnswer('');
    setEditingFaqId(null);
  };

  const handleDeleteFaq = async (faqId) => {
    const confirmed = window.confirm('Delete this FAQ?');

    if (!confirmed) {
      return;
    }

    try {
      await deleteFaq(faqId);
      await loadFaqs();
    } catch (error) {
      alert(error.message || 'Failed to delete FAQ.');
    }
  };

  const handleAddBlockedWord = async (event) => {
    event.preventDefault();
    setBlockedWordsError('');

    if (!blockedWord.trim()) {
      setBlockedWordsError('Enter a word or phrase to block.');
      return;
    }

    try {
      setSubmittingBlockedWord(true);
      await createBlockedWord({
        word: blockedWord,
        language: blockedWordLanguage,
      });
      setBlockedWord('');
    } catch (error) {
      console.error('Failed to add blocked word:', error);
      setBlockedWordsError(error.message || 'Could not add the blocked word.');
    } finally {
      setSubmittingBlockedWord(false);
    }
  };

  const handleDeleteBlockedWord = async (item) => {
    if (!window.confirm(`Remove "${item.word}" from the blocked list?`)) {
      return;
    }

    try {
      await deleteBlockedWord(item.id);
    } catch (error) {
      console.error('Failed to remove blocked word:', error);
      setBlockedWordsError(error.message || 'Could not remove the blocked word.');
    }
  };

  return (
    <div className="module-page">
      <div className="module-heading">
        <div>
          <h1>Content Management</h1>
          <p>Manage campus FAQs and the answers available to the mobile chatbot.</p>
        </div>
      </div>

      <div className="announcement-layout">
        <div className="announcement-form-card">
          <div className="announcement-card-header">
            <div className="announcement-icon">?</div>
            <div>
              <h3>{editingFaqId ? 'Edit FAQ' : 'Add FAQ'}</h3>
              <p>
                {editingFaqId
                  ? 'Update this FAQ and its chatbot answer.'
                  : 'Add a question and answer for students and the mobile chatbot.'}
              </p>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="announcement-form">
            <div className="form-group">
              <label>Question</label>
              <input
                type="text"
                value={question}
                onChange={(event) => setQuestion(event.target.value)}
                placeholder="Where is the registrar office?"
                required
              />
            </div>

            <div className="form-group">
              <label>Answer</label>
              <textarea
                value={answer}
                onChange={(event) => setAnswer(event.target.value)}
                placeholder="The registrar office is located at the main administration building..."
                rows="5"
                required
              />
            </div>

            <div className="announcement-action-row">
              <button type="submit" className="login-button" disabled={submitting}>
                {submitting ? 'Saving...' : editingFaqId ? 'Save Changes' : 'Add FAQ'}
              </button>

              {editingFaqId && (
                <button type="button" className="secondary-button" onClick={resetFaqForm}>
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>

        <div className="announcement-list-card">
          <div className="announcement-card-header">
            <div className="announcement-icon">▤</div>
            <div>
              <h3>Chatbot Knowledge Base</h3>
              <p>FAQ entries available to the chatbot when a question matches.</p>
            </div>
          </div>

          {loadingFaqs ? (
            <p>Loading FAQs...</p>
          ) : faqs.length === 0 ? (
            <p>No FAQs added yet.</p>
          ) : (
            <div className="faq-list">
              {faqs.map((faq) => (
                <div className="faq-item" key={faq.id}>
                  <div className="faq-item-header">
                    <strong>{faq.question}</strong>

                    <div className="faq-item-actions">
                      <button
                        type="button"
                        className="faq-edit-button"
                        onClick={() => startEditFaq(faq)}
                      >
                        Edit
                      </button>

                      <button
                        type="button"
                        className="faq-delete-button"
                        onClick={() => handleDeleteFaq(faq.id)}
                      >
                        Delete
                      </button>
                    </div>
                  </div>

                  <p>{faq.answer}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <section className="blocked-words-section">
        <div className="blocked-words-heading">
          <div>
            <h2>Chatbot Word Filter</h2>
            <p>
              Manage words and phrases the mobile chatbot will block in English,
              Tagalog, and Cebuano. The filter checks every listed term regardless
              of the selected language.
            </p>
          </div>
        </div>

        <div className="announcement-layout">
          <div className="announcement-form-card">
            <div className="announcement-card-header">
              <div className="announcement-icon">!</div>
              <div>
                <h3>Add a blocked word or phrase</h3>
                <p>Only terms you add here are blocked; there is no built-in list.</p>
              </div>
            </div>

            <form onSubmit={handleAddBlockedWord} className="announcement-form">
              <div className="form-group">
                <label htmlFor="blocked-word">Word or phrase</label>
                <input
                  id="blocked-word"
                  type="text"
                  maxLength={80}
                  value={blockedWord}
                  onChange={(event) => setBlockedWord(event.target.value)}
                  placeholder="Enter a word or phrase"
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="blocked-word-language">Language</label>
                <select
                  id="blocked-word-language"
                  value={blockedWordLanguage}
                  onChange={(event) => setBlockedWordLanguage(event.target.value)}
                >
                  <option>English</option>
                  <option>Tagalog</option>
                  <option>Cebuano</option>
                  <option>Mixed / Other</option>
                </select>
              </div>

              {blockedWordsError && (
                <p className="blocked-words-error" role="alert">{blockedWordsError}</p>
              )}

              <div className="announcement-action-row">
                <button
                  type="submit"
                  className="login-button"
                  disabled={submittingBlockedWord}
                >
                  {submittingBlockedWord ? 'Saving...' : 'Add to blocked list'}
                </button>
              </div>
            </form>
          </div>

          <div className="announcement-list-card">
            <div className="announcement-card-header">
              <div className="announcement-icon">⊘</div>
              <div>
                <h3>Blocked Words</h3>
                <p>These terms are checked before a chat message is sent.</p>
              </div>
            </div>

            {loadingBlockedWords ? (
              <p>Loading blocked words...</p>
            ) : blockedWords.length === 0 ? (
              <p>No blocked words have been added.</p>
            ) : (
              <div className="blocked-word-list">
                {blockedWords.map((item) => (
                  <div className="blocked-word-item" key={item.id}>
                    <div>
                      <strong>{item.word}</strong>
                      <span>{item.language || 'Mixed / Other'}</span>
                    </div>
                    <button
                      type="button"
                      className="faq-delete-button"
                      onClick={() => handleDeleteBlockedWord(item)}
                    >
                      Remove
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </section>
    </div>
  );
}

/* ============================================================
   USERS PAGE
============================================================ */

function UsersPage() {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [studentId, setStudentId] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [editingId, setEditingId] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [students, setStudents] = useState([]);
  const [loadingStudents, setLoadingStudents] = useState(true);

  useEffect(() => {
    loadStudents();
  }, []);

  async function loadStudents() {
    try {
      const data = await getStudents();
      setStudents(data.filter((student) => student.role === 'student'));
    } catch (error) {
      console.error('Failed to load students:', error);
      setStudents([]);
    } finally {
      setLoadingStudents(false);
    }
  }

  const resetForm = () => {
    setFirstName('');
    setLastName('');
    setStudentId('');
    setEmail('');
    setPassword('');
    setEditingId(null);
  };

  const handleCancelEdit = () => {
    resetForm();
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!firstName.trim() || !lastName.trim() || !studentId.trim() || !email.trim()) {
      alert('Please fill in all student details.');
      return;
    }

    if (!editingId && password.length < 6) {
      alert('Password must be at least 6 characters long.');
      return;
    }

    if (editingId && password && password.length < 6) {
      alert('New password must be at least 6 characters long.');
      return;
    }

    try {
      setSubmitting(true);

      if (editingId) {
        await updateStudentAccount(editingId, {
          firstName,
          lastName,
          studentId,
        });

        if (password.trim()) {
          await resetStudentPassword(email);
          alert('Student updated successfully. A password reset email was sent to the student.');
        } else {
          alert('Student updated successfully.');
        }
      } else {
        await createStudentAccount({
          firstName,
          lastName,
          studentId,
          email,
          password,
        });
        alert('Student account created successfully.');
      }

      resetForm();
      await loadStudents();
    } catch (error) {
      alert(error.message || 'Failed to save student account.');
    } finally {
      setSubmitting(false);
    }
  };

  const startEdit = (student) => {
    setFirstName(student.firstName || '');
    setLastName(student.lastName || '');
    setStudentId(student.studentId || '');
    setEmail(student.email || '');
    setPassword('');
    setEditingId(student.id);
  };

  const handlePasswordReset = async (student) => {
    if (!student.email) {
      alert('This student does not have an email address on file.');
      return;
    }

    try {
      await resetStudentPassword(student.email);
      alert('A password reset email has been sent to the student.');
    } catch (error) {
      alert(error.message || 'Failed to send reset email.');
    }
  };

  const handleDelete = async (student) => {
    const confirmed = window.confirm(
      `Delete student ${student.firstName} ${student.lastName}? They will no longer be able to sign in to the app.`,
    );

    if (!confirmed) {
      return;
    }

    try {
      await deleteStudentAccount(student.id);
      alert(
        'Student deleted. They can no longer sign in to the app.\n\n'
          + 'To reuse their email for a new account, also delete it in Firebase Console > Authentication.',
      );
      await loadStudents();
      if (editingId === student.id) {
        resetForm();
      }
    } catch (error) {
      alert(error.message || 'Failed to delete student.');
    }
  };

  return (
    <div className="module-page">
      <div className="module-heading">
        <div>
          <h1>Student Management</h1>
          <p>Create and review student accounts in the system.</p>
        </div>
      </div>

      <div className="announcement-layout">
        <div className="announcement-form-card">
          <div className="announcement-card-header">
            <div className="announcement-icon">♙</div>
            <div>
              <h3>{editingId ? 'Edit Student' : 'Add Student'}</h3>
              <p>{editingId ? 'Update the selected student record.' : 'Create a student account and assign their login credentials.'}</p>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="announcement-form">
            <div className="form-group">
              <label>First Name</label>
              <input
                type="text"
                value={firstName}
                onChange={(event) => setFirstName(event.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Last Name</label>
              <input
                type="text"
                value={lastName}
                onChange={(event) => setLastName(event.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Student ID</label>
              <input
                type="text"
                value={studentId}
                onChange={(event) => setStudentId(event.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Email</label>
              <input
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                readOnly={Boolean(editingId)}
                title={editingId ? 'The email is the student\'s login and cannot be changed here.' : undefined}
                style={editingId ? { background: '#f1f5f9', color: '#64748b', cursor: 'not-allowed' } : undefined}
                required
              />
            </div>

            <div className="form-group">
              <label>{editingId ? 'New Password (optional)' : 'Password'}</label>
              <input
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder={editingId ? 'Leave blank to keep current password' : 'Create student password'}
                required={!editingId}
              />
            </div>

            <div className="announcement-action-row">
              <button type="submit" className="login-button" disabled={submitting}>
                {submitting ? 'Saving...' : editingId ? 'Update Student' : 'Add Student'}
              </button>

              {editingId && (
                <button type="button" className="secondary-button" onClick={handleCancelEdit}>
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>

        <div className="announcement-stream-card">
          <div className="announcement-card-header compact">
            <div>
              <h3>Registered Students</h3>
              <p>Latest student records</p>
            </div>
          </div>

          <div className="announcement-list">
            {loadingStudents ? (
              <div className="announcement-empty">
                <strong>Loading students...</strong>
              </div>
            ) : students.length === 0 ? (
              <div className="announcement-empty">
                <div className="announcement-empty-icon">♙</div>
                <strong>No students yet</strong>
                <span>New student accounts will appear here.</span>
              </div>
            ) : (
              students.map((student) => (
                <div className="announcement-item" key={student.id}>
                  <div className="announcement-badge">{student.studentId || 'ID'}</div>
                  <div className="announcement-copy">
                    <strong>{student.firstName} {student.lastName}</strong>
                    <span>{student.email}</span>
                  </div>
                  <div className="announcement-action-row" style={{ marginLeft: 'auto' }}>
                    <button
                      type="button"
                      className="announcement-edit-button"
                      onClick={() => startEdit(student)}
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      className="announcement-edit-button"
                      style={{ background: '#dbeafe', color: '#1d4ed8' }}
                      onClick={() => handlePasswordReset(student)}
                    >
                      Reset Password
                    </button>
                    <button
                      type="button"
                      className="announcement-edit-button"
                      style={{ background: '#ffe8e8', color: '#dc2626' }}
                      onClick={() => handleDelete(student)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

    </div>
  );
}

/* ============================================================
   ANNOUNCEMENTS PAGE
============================================================ */

function AnnouncementsPage() {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [announcements, setAnnouncements] = useState([]);

  useEffect(() => {
    const unsubscribe = subscribeToAnnouncements((items) => {
      setAnnouncements(items);
    });

    return () => unsubscribe && unsubscribe();
  }, []);

  async function loadAnnouncements() {
    try {
      const data = await getAnnouncements();
      setAnnouncements(data);
    } catch (error) {
      console.error('Failed to load announcements:', error);
      setAnnouncements([]);
    }
  }

  const resetForm = () => {
    setTitle('');
    setMessage('');
    setEditingId(null);
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!title.trim() || !message.trim()) {
      alert('Please enter both a title and message.');
      return;
    }

    try {
      setLoading(true);

      if (editingId) {
        await updateAnnouncement(editingId, { title, message });
        alert('Announcement updated successfully.');
      } else {
        await createAnnouncement({ title, message });
        alert('Announcement published successfully.');
      }

      resetForm();
      await loadAnnouncements();
    } catch (error) {
      alert(error.message || 'Failed to save announcement.');
    } finally {
      setLoading(false);
    }
  };

  const startEdit = (announcement) => {
    setTitle(announcement.title || '');
    setMessage(announcement.message || '');
    setEditingId(announcement.id);
  };

  const handleDelete = async (announcementId) => {
    const confirmed = window.confirm('Delete this announcement?');

    if (!confirmed) {
      return;
    }

    try {
      await deleteAnnouncement(announcementId);
      await loadAnnouncements();
    } catch (error) {
      alert(error.message || 'Failed to delete announcement.');
    }
  };

  return (
    <div className="module-page">
      <div className="module-heading">
        <div>
          <h1>Announcements</h1>
          <p>Create and broadcast university announcements.</p>
        </div>
      </div>

      <div className="announcement-layout">
        <div className="announcement-form-card">
          <div className="announcement-card-header">
            <div className="announcement-icon">⚑</div>
            <div>
              <h3>{editingId ? 'Edit Announcement' : 'Create Announcement'}</h3>
              <p>{editingId ? 'Update the selected message.' : 'Share a new update with students.'}</p>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="announcement-form">
            <div className="form-group">
              <label>Title</label>
              <input
                type="text"
                placeholder="Announcement title"
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Message</label>
              <textarea
                rows="6"
                placeholder="Write your announcement here..."
                value={message}
                onChange={(event) => setMessage(event.target.value)}
                required
              />
            </div>

            <div className="announcement-action-row">
              <button type="submit" className="login-button" disabled={loading}>
                {loading ? 'Saving...' : editingId ? 'Update Announcement' : 'Publish Announcement'}
              </button>

              {editingId && (
                <button type="button" className="secondary-button" onClick={resetForm}>
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>

        <div className="announcement-stream-card">
          <div className="announcement-card-header compact">
            <div>
              <h3>Published Announcements</h3>
              <p>Latest campus updates</p>
            </div>
          </div>

          <div className="announcement-list">
            {announcements.length === 0 ? (
              <div className="announcement-empty">
                <div className="announcement-empty-icon">⚑</div>
                <strong>No announcements yet</strong>
                <span>Your published updates will appear here.</span>
              </div>
            ) : (
              announcements.map((announcement, index) => (
                <div className="announcement-item" key={announcement.id || index}>
                  <div className="announcement-badge">{index + 1}</div>
                  <div className="announcement-copy">
                    <strong>{announcement.title}</strong>
                    <span>{announcement.message}</span>
                  </div>

                  <div className="announcement-item-actions">
                    <button
                      type="button"
                      className="announcement-edit-button"
                      onClick={() => startEdit(announcement)}
                    >
                      Edit
                    </button>

                    <button
                      type="button"
                      className="secondary-button small-button"
                      onClick={() => handleDelete(announcement.id)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
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
   FEEDBACK AND RATINGS
============================================================ */

function FeedbackPage() {
  const [feedback, setFeedback] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const unsubscribe = subscribeToFeedback(
      (items) => {
        setFeedback(items);
        setLoading(false);
        setError('');
      },
      (subscriptionError) => {
        console.error('Failed to load feedback:', subscriptionError);
        setError('Could not load feedback. Check your connection and Firestore permissions.');
        setLoading(false);
      },
    );

    return () => unsubscribe();
  }, []);

  const ratings = feedback
    .map((item) => Number(item.rating))
    .filter((rating) => Number.isInteger(rating) && rating >= 1 && rating <= 5);
  const averageRating = ratings.length
    ? (ratings.reduce((total, rating) => total + rating, 0) / ratings.length).toFixed(1)
    : '—';

  return (
    <div className="module-page">
      <div className="module-heading">
        <div>
          <h1>Feedback & Ratings</h1>
          <p>Review anonymous student ratings and feedback about AskUC.</p>
        </div>
      </div>

      <div className="feedback-summary">
        <div className="feedback-summary-card">
          <span>Total submissions</span>
          <strong>{loading ? '—' : feedback.length}</strong>
        </div>
        <div className="feedback-summary-card">
          <span>Average rating</span>
          <strong>{loading ? '—' : averageRating}<span className="feedback-summary-star"> ★</span></strong>
        </div>
      </div>

      <section className="feedback-list-card">
        <div className="announcement-card-header compact">
          <div>
            <h3>Student Feedback</h3>
            <p>Submissions are anonymous.</p>
          </div>
        </div>

        {error ? (
          <div className="feedback-state feedback-error" role="alert">{error}</div>
        ) : loading ? (
          <div className="feedback-state">Loading feedback...</div>
        ) : feedback.length === 0 ? (
          <div className="feedback-state">No feedback has been submitted yet.</div>
        ) : (
          <div className="feedback-list">
            {feedback.map((item) => {
              const rating = Number(item.rating);
              const validRating = Number.isInteger(rating) && rating >= 1 && rating <= 5;
              const createdAt = item.createdAt?.toDate?.();

              return (
                <article className="feedback-item" key={item.id}>
                  <div className="feedback-item-heading">
                    <div>
                      <strong>Anonymous</strong>
                      <div className="feedback-rating" aria-label={validRating ? `${rating} out of 5 stars` : 'Rating unavailable'}>
                        {validRating
                          ? `${'★'.repeat(rating)}${'☆'.repeat(5 - rating)}`
                          : 'Rating unavailable'}
                      </div>
                    </div>
                    <time>
                      {createdAt
                        ? createdAt.toLocaleString()
                        : 'Date unavailable'}
                    </time>
                  </div>
                  <p>{typeof item.message === 'string' ? item.message : 'No written feedback provided.'}</p>
                </article>
              );
            })}
          </div>
        )}
      </section>
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
