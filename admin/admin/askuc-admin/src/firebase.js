import { initializeApp } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
  updateEmail,
  updatePassword,
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

export async function checkForAdminAccount() {
  const usersRef = collection(db, 'students');
  const q = query(usersRef, where('role', '==', 'admin'));
  const snapshot = await getDocs(q);
  return !snapshot.empty;
}

export async function countStudents() {
  const usersRef = collection(db, 'students');
  const q = query(usersRef, where('role', '==', 'student'));
  const snapshot = await getDocs(q);
  return snapshot.size;
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

  const userCredential = await createUserWithEmailAndPassword(
    auth,
    normalizedEmail,
    password,
  );

  const uid = userCredential.user.uid;

  await setDoc(
    doc(db, 'students', uid),
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

  return userCredential.user;
}

export async function updateStudentAccount(id, { firstName, lastName, studentId, email }) {
  const studentRef = doc(db, 'students', id);

  await updateDoc(studentRef, {
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    studentId: studentId.trim(),
    email: email.trim().toLowerCase(),
    updatedAt: serverTimestamp(),
  });
}

export async function deleteStudentAccount(id) {
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
