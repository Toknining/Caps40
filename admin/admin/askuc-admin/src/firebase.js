import { initializeApp } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
  updateEmail,
  updatePassword,
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

export async function createAdminAccount(email, password) {
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
        firstName: 'Admin',
        lastName: 'User',
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

export async function adminSignIn(email, password) {
  const normalizedEmail = email.trim().toLowerCase();

  try {
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

export async function getCurrentAdminProfile() {
  const currentUser = auth.currentUser;

  if (!currentUser) {
    return {
      firstName: 'Admin',
      lastName: 'User',
      photoUrl: '',
    };
  }

  const profileRef = doc(db, 'students', currentUser.uid);
  const profileSnapshot = await getDoc(profileRef);

  if (!profileSnapshot.exists()) {
    return {
      firstName: currentUser.displayName?.split(' ')[0] || 'Admin',
      lastName: currentUser.displayName?.split(' ').slice(1).join(' ') || 'User',
      photoUrl: currentUser.photoURL || '',
    };
  }

  const data = profileSnapshot.data();

  return {
    firstName: data.firstName || currentUser.displayName?.split(' ')[0] || 'Admin',
    lastName: data.lastName || currentUser.displayName?.split(' ').slice(1).join(' ') || 'User',
    photoUrl: data.photoUrl || currentUser.photoURL || '',
  };
}

export { signOut as adminSignOut };
