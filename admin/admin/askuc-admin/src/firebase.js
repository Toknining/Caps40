import { deleteApp, initializeApp } from 'firebase/app';
import {
  getAuth,
  initializeAuth,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
  setPersistence,
  browserLocalPersistence,
  inMemoryPersistence,
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  where,
  addDoc,
  updateDoc,
  deleteDoc,
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyCnxJboguDMIMvYL9-DEOOUlQ48QqUtOsk',
  authDomain: 'askuc-e1aba.firebaseapp.com',
  projectId: 'askuc-e1aba',
  storageBucket: 'askuc-e1aba.firebasestorage.app',
  messagingSenderId: '206861061946',
  appId: '1:206861061946:web:519fd91bb8c9f9a26d8a03',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

// Exists once the first admin account is set up. The Firestore rules only
// allow self-registering as an admin while this document is missing.
const adminSetupRef = doc(db, 'config', 'adminSetup');

export async function checkForAdminAccount() {
  const setupSnapshot = await getDoc(adminSetupRef).catch(() => null);

  if (setupSnapshot?.exists()) {
    return true;
  }

  const usersRef = collection(db, 'students');
  const q = query(usersRef, where('role', '==', 'admin'), limit(1));
  const snapshot = await getDocs(q);
  return !snapshot.empty;
}

async function markAdminSetupComplete() {
  try {
    const setupSnapshot = await getDoc(adminSetupRef);

    if (!setupSnapshot.exists()) {
      await setDoc(adminSetupRef, { createdAt: serverTimestamp() });
    }
  } catch (error) {
    console.warn('Could not mark admin setup as complete:', error);
  }
}

export async function isAdminUser(uid) {
  const profileSnapshot = await getDoc(doc(db, 'students', uid));
  return profileSnapshot.exists() && profileSnapshot.data().role === 'admin';
}

export function subscribeToStudentCount(callback, onError) {
  const usersRef = collection(db, 'students');
  const q = query(usersRef, where('role', '==', 'student'));

  return onSnapshot(q, (snapshot) => callback(snapshot.size), onError);
}

export async function getStudents() {
  const usersRef = collection(db, 'students');
  const q = query(usersRef, orderBy('createdAt', 'desc'));
  const snapshot = await getDocs(q);

  return snapshot.docs.map((docSnap) => ({
    id: docSnap.id,
    ...docSnap.data(),
  }));
}

export async function createStudentAccount({
  firstName,
  lastName,
  studentId,
  email,
  password,
}) {
  const normalizedEmail = email.trim().toLowerCase();
  const normalizedStudentId = studentId.trim();

  // Creating a user signs that user in on whichever app instance created it.
  // A throwaway instance keeps the admin's own session signed in.
  const creatorApp = initializeApp(firebaseConfig, `student-creator-${Date.now()}`);
  const creatorAuth = initializeAuth(creatorApp, { persistence: inMemoryPersistence });

  try {
    let userCredential;

    try {
      userCredential = await createUserWithEmailAndPassword(
        creatorAuth,
        normalizedEmail,
        password,
      );
    } catch (error) {
      if (error?.code === 'auth/email-already-in-use') {
        throw new Error(
          'This email already has a login account, possibly from a deleted student. '
            + 'Remove it in Firebase Console > Authentication, then try again.',
        );
      }

      throw error;
    }

    const user = userCredential.user;

    try {
      // Written as the new student, the same way the mobile app registers.
      await setDoc(
        doc(getFirestore(creatorApp), 'students', user.uid),
        {
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          studentId: normalizedStudentId,
          email: normalizedEmail,
          role: 'student',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    } catch (error) {
      // Don't leave a login behind that has no student profile.
      await user.delete().catch(() => undefined);
      throw error;
    }

    return user;
  } finally {
    await signOut(creatorAuth).catch(() => undefined);
    await deleteApp(creatorApp).catch(() => undefined);
  }
}

// The email is not editable: it is the student's login, and only a server
// with admin access can change another user's login email.
export async function updateStudentAccount(id, { firstName, lastName, studentId }) {
  const studentRef = doc(db, 'students', id);

  await updateDoc(studentRef, {
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    studentId: studentId.trim(),
    updatedAt: serverTimestamp(),
  });
}

export async function deleteStudentAccount(id) {
  // The student's Firebase login can't be deleted from the browser, so record
  // the removal. The Firestore rules stop that login from recreating a
  // profile, and the mobile app refuses to sign in without one.
  await setDoc(doc(db, 'removedStudents', id), { removedAt: serverTimestamp() })
    .catch((error) => console.warn('Could not record the removed student:', error));

  const studentRef = doc(db, 'students', id);
  await deleteDoc(studentRef);
}

export async function resetStudentPassword(email) {
  const normalizedEmail = email.trim().toLowerCase();

  if (!normalizedEmail) {
    throw new Error('Student email is required to reset the password.');
  }

  await sendPasswordResetEmail(auth, normalizedEmail);
}

export async function createAdminAccount({ firstName, lastName, email, password }) {
  const normalizedEmail = email.trim().toLowerCase();

  try {
    const userCredential = await createUserWithEmailAndPassword(
      auth,
      normalizedEmail,
      password,
    );

    const uid = userCredential.user.uid;

    await setDoc(
      doc(db, 'students', uid),
      {
        email: normalizedEmail,
        role: 'admin',
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        studentId: 'ADMIN',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );

    await markAdminSetupComplete();
    // The registration screen asks the new admin to sign in afterwards.
    await signOut(auth);

    return userCredential.user;
  } catch (error) {
    await signOut(auth).catch(() => undefined);

    const message = error?.message || 'Failed to create admin account.';

    if (message.includes('permission') || message.includes('Permission')) {
      throw new Error('Firestore permission denied. Deploy the Firestore rules first, then create the admin account again.');
    }

    throw new Error(message);
  }
}

export async function createAnnouncement({ title, message }) {
  const announcementRef = await addDoc(collection(db, 'announcements'), {
    title: title.trim(),
    message: message.trim(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  return announcementRef.id;
}

export async function updateAnnouncement(id, { title, message }) {
  const announcementRef = doc(db, 'announcements', id);

  await updateDoc(announcementRef, {
    title: title.trim(),
    message: message.trim(),
    updatedAt: serverTimestamp(),
  });
}

export async function deleteAnnouncement(id) {
  await deleteDoc(doc(db, 'announcements', id));
}

export function subscribeToAnnouncements(callback) {
  const announcementsRef = collection(db, 'announcements');
  const q = query(announcementsRef, orderBy('createdAt', 'desc'));

  return onSnapshot(q, (snapshot) => {
    const items = snapshot.docs.map((docSnap) => ({
      id: docSnap.id,
      ...docSnap.data(),
    }));

    callback(items);
  });
}

export function subscribeToAnnouncementCount(callback) {
  const announcementsRef = collection(db, 'announcements');

  return onSnapshot(announcementsRef, (snapshot) => {
    callback(snapshot.size);
  });
}

export function subscribeToFaqCount(callback) {
  const faqsRef = collection(db, 'faqs');

  return onSnapshot(faqsRef, (snapshot) => {
    callback(snapshot.size);
  });
}

export function subscribeToChatbotQueries(callback, onError) {
  const queriesRef = collection(db, 'chatbotQueries');

  return onSnapshot(
    queriesRef,
    (snapshot) => {
      callback(
        snapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          ...docSnap.data(),
        })),
      );
    },
    onError,
  );
}

export function subscribeToNavigationSearches(callback, onError) {
  const searchesRef = collection(db, 'navigationSearches');

  return onSnapshot(
    searchesRef,
    (snapshot) => {
      callback(
        snapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          ...docSnap.data(),
        })),
      );
    },
    onError,
  );
}

export async function getAnnouncements() {
  const announcementsRef = collection(db, 'announcements');
  const q = query(announcementsRef, orderBy('createdAt', 'desc'));
  const snapshot = await getDocs(q);

  return snapshot.docs.map((docSnap) => ({
    id: docSnap.id,
    ...docSnap.data(),
  }));
}

export async function createFaq({ question, answer }) {
  const faqRef = await addDoc(collection(db, 'faqs'), {
    question: question.trim(),
    answer: answer.trim(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  return faqRef.id;
}

export async function getFaqs() {
  const faqsRef = collection(db, 'faqs');
  const q = query(faqsRef, orderBy('createdAt', 'desc'));
  const snapshot = await getDocs(q);

  return snapshot.docs.map((docSnap) => ({
    id: docSnap.id,
    ...docSnap.data(),
  }));
}

export async function updateFaq(id, { question, answer }) {
  const faqRef = doc(db, 'faqs', id);

  await updateDoc(faqRef, {
    question: question.trim(),
    answer: answer.trim(),
    updatedAt: serverTimestamp(),
  });
}

export async function deleteFaq(id) {
  await deleteDoc(doc(db, 'faqs', id));
}

export async function adminSignIn(email, password, rememberMe = true) {
  const normalizedEmail = email.trim().toLowerCase();

  try {
    await setPersistence(
      auth,
      rememberMe ? browserLocalPersistence : inMemoryPersistence,
    );

    const userCredential = await signInWithEmailAndPassword(
      auth,
      normalizedEmail,
      password,
    );

    const user = userCredential.user;
    const profileRef = doc(db, 'students', user.uid);
    const profileSnapshot = await getDoc(profileRef);

    if (!profileSnapshot.exists()) {
      await signOut(auth).catch(() => undefined);
      throw new Error('No admin profile was found in Firestore. Please create the admin account again.');
    }

    const profile = profileSnapshot.data();

    if (profile.role !== 'admin') {
      await signOut(auth).catch(() => undefined);
      throw new Error('This account does not have admin access.');
    }

    await markAdminSetupComplete();

    return user;
  } catch (error) {
    const message = error?.message || 'Admin sign in failed.';

    if (message.includes('permission') || message.includes('Permission')) {
      throw new Error('Firestore permission denied. Deploy the Firestore rules before trying to log in again.');
    }

    throw new Error(message);
  }
}

export function subscribeToAdminAuthState(callback) {
  return onAuthStateChanged(auth, callback);
}

export async function getCurrentAdminProfile() {
  const currentUser = auth.currentUser;

  if (!currentUser) {
    return buildAdminProfile();
  }

  const profileRef = doc(db, 'students', currentUser.uid);
  const profileSnapshot = await getDoc(profileRef);

  if (!profileSnapshot.exists()) {
    return buildAdminProfile({}, currentUser);
  }

  return buildAdminProfile(profileSnapshot.data(), currentUser);
}

export function subscribeToCurrentAdminProfile(callback, onError) {
  const currentUser = auth.currentUser;

  if (!currentUser) {
    callback(buildAdminProfile());
    return () => {};
  }

  return onSnapshot(
    doc(db, 'students', currentUser.uid),
    (profileSnapshot) => {
      callback(buildAdminProfile(profileSnapshot.data() || {}, currentUser));
    },
    onError,
  );
}

export async function updateCurrentAdminName({ firstName, lastName }) {
  const currentUser = auth.currentUser;

  if (!currentUser) {
    throw new Error('You must be signed in to update your profile.');
  }

  await updateDoc(doc(db, 'students', currentUser.uid), {
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    updatedAt: serverTimestamp(),
  });
}

function buildAdminProfile(data = {}, currentUser = null) {
  const displayName = currentUser?.displayName || '';
  const [displayFirstName = 'Admin', ...displayLastName] = displayName.split(' ').filter(Boolean);

  return {
    firstName: data.firstName || displayFirstName,
    lastName: data.lastName || displayLastName.join(' ') || 'User',
    studentId: data.studentId || 'ADMIN',
    email: data.email || currentUser?.email || 'Not available',
    role: data.role || 'admin',
    photoUrl: data.photoUrl || currentUser?.photoURL || '',
  };
}

export { signOut as adminSignOut };
